import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/bits.dart';
import 'backup_files.dart';
import 'pro_store.dart';
import 'report_document.dart';

/// 三端通过原生文件选择器保存。仅用户主动导出时生成，不上传记录。
class ReportExports {
  static bool _busy = false;

  static Future<void> savePdf(BuildContext context,
          {required String title, required String body}) =>
      _runPro(context, (canContinue) async {
        final renderer = _ReportPainter(title, body, dark: false);
        final pages = <ReportPdfPage>[];
        try {
          final slices = renderer.slices();
          for (var i = 0; i < slices.length; i++) {
            if (!canContinue()) return;
            final image = await renderer.draw(slices[i], i + 1, slices.length);
            try {
              if (!canContinue()) return;
              final data =
                  await image.toByteData(format: ui.ImageByteFormat.rawRgba);
              if (!canContinue()) return;
              if (data == null) throw StateError('无法生成报告页面');
              final rgba = data.buffer
                  .asUint8List(data.offsetInBytes, data.lengthInBytes);
              final rgb = Uint8List(image.width * image.height * 3);
              for (var from = 0, to = 0; from < rgba.length; from += 4) {
                rgb[to++] = rgba[from];
                rgb[to++] = rgba[from + 1];
                rgb[to++] = rgba[from + 2];
              }
              pages.add(ReportPdfPage(image.width, image.height,
                  Uint8List.fromList(ZLibCodec(level: 6).encode(rgb))));
            } finally {
              image.dispose();
            }
            await Future<void>.delayed(Duration.zero);
          }
          if (!context.mounted || !canContinue()) return;
          await _save(
              context, reportPdf(pages), _name('pdf'), 'application/pdf');
        } finally {
          renderer.dispose();
        }
      });

  static Future<void> saveCard(BuildContext context,
          {required String title, required String body}) =>
      _runPro(context, (canContinue) async {
        final navigator = Navigator.of(context);
        final styleRoute = ModalBottomSheetRoute<bool>(
            isScrollControlled: false,
            barrierLabel:
                MaterialLocalizations.of(context).modalBarrierDismissLabel,
            capturedThemes:
                InheritedTheme.capture(from: context, to: navigator.context),
            builder: (context) => SafeArea(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ListTile(title: Text('选择回顾图片样式')),
                    ListTile(
                        leading: const Icon(Icons.light_mode_outlined),
                        title: const Text('暖纸'),
                        onTap: () => Navigator.pop(context, false)),
                    ListTile(
                        leading: const Icon(Icons.dark_mode_outlined),
                        title: const Text('夜色'),
                        onTap: () => Navigator.pop(context, true)),
                  ],
                )));
        navigator.push(styleRoute);
        // completed also settles when the Navigator is disposed; popped alone
        // can stay pending if the whole page tree is removed during selection.
        final dark = await styleRoute.completed;
        if (dark == null || !context.mounted || !canContinue()) return;
        final renderer = _ReportPainter(title, body, dark: dark);
        try {
          final height = renderer.fullHeight;
          if (height > 4096) {
            showToast(context, '内容较长，请用 PDF 保存完整报告，或选择更短时间范围。');
            return;
          }
          final image = await renderer.draw(
              _ReportSlice(0, renderer.body.height), 1, 1,
              height: height);
          try {
            if (!context.mounted || !canContinue()) return;
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            if (!context.mounted || !canContinue()) return;
            if (bytes == null) throw StateError('无法生成图片');
            await _save(
                context,
                bytes.buffer
                    .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
                _name('png'),
                'image/png');
          } finally {
            image.dispose();
          }
        } finally {
          renderer.dispose();
        }
      });

  /// 免费基础卡片复用此保存入口；不改变原始 JSON 备份的免费能力。
  static Future<void> saveImage(BuildContext context, Uint8List bytes) =>
      _run(context, () => _save(context, bytes, _name('png'), 'image/png'));

  static Future<void> _runPro(BuildContext context,
          Future<void> Function(bool Function() canContinue) action) =>
      _run(context, () async {
        final pro = context.read<ProStore?>();
        if (pro == null || !pro.isPro) {
          showToast(context, '完整报告导出需要已解锁 Pro，基础月度卡片和备份仍免费。');
          return;
        }
        var revoked = false;
        void checkEntitlement() {
          if (!pro.isPro) revoked = true;
        }

        pro.addListener(checkEntitlement);
        bool canContinue() => _isCurrent(context) && !revoked && pro.isPro;
        try {
          if (canContinue()) await action(canContinue);
        } finally {
          pro.removeListener(checkEntitlement);
        }
      });

  static bool _isCurrent(BuildContext context) =>
      context.mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  static Future<void> _run(
      BuildContext context, Future<void> Function() action) async {
    if (!_isCurrent(context)) return;
    if (_busy) {
      showToast(context, '正在处理上一次导出，请先完成或取消。');
      return;
    }
    _busy = true;
    try {
      await action();
    } on StateError catch (error) {
      if (context.mounted && _isCurrent(context)) {
        showToast(context, error.message.toString());
      }
    } catch (_) {
      if (context.mounted && _isCurrent(context)) {
        showToast(context, '导出未完成，请重试；记录仍保存在本机。');
      }
    } finally {
      _busy = false;
    }
  }

  static String _name(String extension) =>
      'shuying-review-${DateTime.now().millisecondsSinceEpoch}.$extension';

  static Future<void> _save(
      BuildContext context, Uint8List bytes, String name, String mime) async {
    if (!_isCurrent(context)) return;
    // Once sent to the native picker, retain the lock until native completion.
    // Leaving this page cannot cancel a picker or bytes already handed to it.
    final saved = await BackupFiles.channel.invokeMethod<bool>(
        'saveBytes', {'bytes': bytes, 'name': name, 'mime': mime});
    if (saved == true && context.mounted && _isCurrent(context)) {
      showToast(context, '报告已保存');
    }
  }
}

class _ReportSlice {
  const _ReportSlice(this.start, this.height);
  final double start, height;
}

class _ReportPainter {
  _ReportPainter(String title, String text, {required this.dark}) {
    heading = _text(title, 23, bold: true)
      ..layout(maxWidth: width - margin * 2);
    body = _text(text, 12)..layout(maxWidth: width - margin * 2);
  }
  static const width = 595.0, pageHeight = 842.0, margin = 40.0;
  final bool dark;
  late final TextPainter heading, body;
  double get bodyTop => 92 + heading.height;
  double get fullHeight => bodyTop + body.height + 76;
  Color get ink => dark ? const Color(0xFFF5EBDD) : const Color(0xFF302A23);
  Color get accent => dark ? const Color(0xFFF2B88B) : const Color(0xFF965035);
  Color get paper => dark ? const Color(0xFF211F1B) : const Color(0xFFF7F0E5);

  TextPainter _text(String text, double size, {bool bold = false}) =>
      TextPainter(
          text: TextSpan(
              text: text,
              style: TextStyle(
                  color: ink,
                  fontSize: size,
                  height: 1.55,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          textDirection: TextDirection.ltr);

  List<_ReportSlice> slices() {
    final available = pageHeight - bodyTop - 60;
    if (available < 80) throw StateError('标题过长');
    final lines = body.computeLineMetrics();
    if (lines.isEmpty) return const [_ReportSlice(0, 1)];
    final result = <_ReportSlice>[];
    var index = 0;
    while (index < lines.length) {
      final start = lines[index].baseline - lines[index].ascent;
      var bottom = start;
      do {
        bottom = lines[index].baseline + lines[index].descent;
        index++;
      } while (index < lines.length &&
          lines[index].baseline + lines[index].descent - start <= available);
      result.add(_ReportSlice(start, bottom - start));
      if (result.length > 100) throw StateError('报告过长，请缩短范围或使用 JSON 备份');
    }
    return result;
  }

  Future<ui.Image> draw(_ReportSlice slice, int page, int count,
      {double height = pageHeight}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(2);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = paper);
    final brand = _text('书影温故  ·  REEL & READ', 11)
      ..layout(maxWidth: width - margin * 2);
    brand.paint(canvas, const Offset(margin, 30));
    heading.paint(canvas, const Offset(margin, 55));
    canvas.drawLine(
        Offset(margin, bodyTop - 12),
        Offset(width - margin, bodyTop - 12),
        Paint()
          ..color = accent
          ..strokeWidth = 1);
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(margin, bodyTop, width - margin * 2, slice.height + 1));
    body.paint(canvas, Offset(margin, bodyTop - slice.start));
    canvas.restore();
    final footer = _text('私人书影档案  ·  $page / $count', 10)
      ..layout(maxWidth: width - margin * 2);
    footer.paint(canvas, Offset(margin, height - 38));
    final picture = recorder.endRecording();
    try {
      return await picture.toImage((width * 2).ceil(), (height * 2).ceil());
    } finally {
      picture.dispose();
      brand.dispose();
      footer.dispose();
    }
  }

  void dispose() {
    heading.dispose();
    body.dispose();
  }
}
