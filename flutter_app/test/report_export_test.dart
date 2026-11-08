import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shuying/services/backup_files.dart';
import 'package:shuying/services/pro_store.dart';
import 'package:shuying/services/report_document.dart';
import 'package:shuying/services/report_exports.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==');

void main() {
  test('PDF 多页数、交叉引用偏移和无损 RGB 流可独立读取', () {
    final rgb = Uint8List.fromList([255, 0, 0, 0, 128, 255]);
    final page =
        ReportPdfPage(2, 1, Uint8List.fromList(ZLibCodec().encode(rgb)));
    final bytes = reportPdf([page, page]);
    final text = latin1.decode(bytes);
    expect(text.startsWith('%PDF-1.4\n'), isTrue);
    expect(text, contains('/Count 2'));
    final xrefAt = int.parse(RegExp(r'startxref\n(\d+)').firstMatch(text)![1]!);
    expect(text.substring(xrefAt), startsWith('xref\n0 9\n'));
    final rows = text.substring(xrefAt).split('\n');
    for (var id = 1; id <= 8; id++) {
      final offset = int.parse(rows[id + 2].substring(0, 10));
      expect(text.substring(offset), startsWith('$id 0 obj\n'));
    }
    final imageAt = text.indexOf('5 0 obj\n');
    final headerEnd = text.indexOf('\nstream\n', imageAt);
    final length = int.parse(RegExp(r'/Length (\d+)')
        .firstMatch(text.substring(imageAt, headerEnd))![1]!);
    final streamStart = headerEnd + '\nstream\n'.length;
    expect(ZLibCodec().decode(bytes.sublist(streamStart, streamStart + length)),
        rgb);
    expect(() => reportPdf([]), throwsArgumentError);
  });

  testWidgets('免费卡片保存不需 Pro，重复点击只发起一次文件选择', (tester) async {
    BuildContext? context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      context = ctx;
      return const Scaffold();
    })));
    final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==');
    final pending = Completer<bool>();
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, (call) async {
      expect(call.method, 'saveBytes');
      final args = call.arguments as Map;
      expect(args['mime'], 'image/png');
      expect(args['bytes'], png);
      calls++;
      return pending.future;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, null));
    final first = ReportExports.saveImage(context!, png);
    await tester.pump();
    await ReportExports.saveImage(context!, png);
    expect(calls, 1);
    pending.complete(true);
    await first;
    await tester.pump();
  });

  testWidgets('未验证 Pro 不能从导出服务直接生成完整付费报告', (tester) async {
    final pro = ProStore();
    addTearDown(pro.dispose);
    BuildContext? context;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: pro,
        child: MaterialApp(home: Builder(builder: (ctx) {
          context = ctx;
          return const Scaffold();
        }))));
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, (_) async {
      calls++;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, null));
    await ReportExports.savePdf(context!, title: '回顾', body: '私人感想');
    await ReportExports.saveCard(context!, title: '回顾', body: '私人感想');
    expect(calls, 0);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final cancelled in <bool?>[null, false]) {
    testWidgets('原生取消 $cancelled 不提示保存成功，并允许再次导出', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
        context = ctx;
        return const Scaffold();
      })));
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BackupFiles.channel, (_) async {
        calls++;
        return calls == 1 ? cancelled : true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BackupFiles.channel, null));

      await ReportExports.saveImage(context, _png);
      await tester.pump();
      expect(find.text('报告已保存'), findsNothing);
      await ReportExports.saveImage(context, _png);
      await tester.pump();
      expect(calls, 2);
      expect(find.text('报告已保存'), findsOneWidget);
    });
  }

  testWidgets('原生保存失败释放导出锁，下一次可以重试', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      context = ctx;
      return const Scaffold();
    })));
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, (_) async {
      if (++calls == 1) throw PlatformException(code: 'save-failed');
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, null));

    await ReportExports.saveImage(context, _png);
    await tester.pump();
    expect(find.text('导出未完成，请重试；记录仍保存在本机。'), findsOneWidget);
    await ReportExports.saveImage(context, _png);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('原页面退出仍等待原生完成，期间不打开第二个保存器', (tester) async {
    late BuildContext oldContext;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      oldContext = ctx;
      return const Scaffold();
    })));
    final pending = Completer<bool?>();
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, (call) async {
      expect(call.method, 'saveBytes');
      calls++;
      if (calls == 1) return await pending.future;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, null));
    final first = ReportExports.saveImage(oldContext, _png);
    try {
      await tester.pump();
      expect(calls, 1);

      late BuildContext newContext;
      await tester.pumpWidget(MaterialApp(
          key: const ValueKey('replacement'),
          home: Builder(builder: (ctx) {
            newContext = ctx;
            return const Scaffold();
          })));
      expect(oldContext.mounted, isFalse);
      await ReportExports.saveImage(newContext, _png);
      expect(calls, 1);
      pending.complete(true);
      await first;
      await tester.pump();
      expect(find.text('报告已保存'), findsNothing);

      await ReportExports.saveImage(newContext, _png);
      await tester.pump();
      expect(calls, 2);
      expect(find.text('报告已保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      if (!pending.isCompleted) pending.complete(null);
      await tester.pump();
      await first;
    }
  });

  testWidgets('已退出的调用上下文不生成报告或访问原生保存器', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      context = ctx;
      return const Scaffold();
    })));
    await tester.pumpWidget(const SizedBox());
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, (_) async {
      calls++;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, null));

    await ReportExports.saveImage(context, _png);
    await ReportExports.savePdf(context, title: '回顾', body: '记录');
    await ReportExports.saveCard(context, title: '回顾', body: '记录');
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('取消样式选择不保存，重新导出可用', (tester) async {
    final pro = ProStore()..isPro = true;
    addTearDown(pro.dispose);
    late BuildContext context;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: pro,
        child: MaterialApp(home: Builder(builder: (ctx) {
          context = ctx;
          return const Scaffold();
        }))));
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, (_) async {
      calls++;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, null));

    final exporting = ReportExports.saveCard(context, title: '回顾', body: '记录');
    await tester.pumpAndSettle();
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await exporting;
    expect(calls, 0);
    await ReportExports.saveImage(context, _png);
    expect(calls, 1);
  });

  testWidgets('样式选择期间移除整个 Navigator 也能释放导出状态', (tester) async {
    final pro = ProStore()..isPro = true;
    addTearDown(pro.dispose);
    late BuildContext context;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: pro,
        child: MaterialApp(home: Builder(builder: (ctx) {
          context = ctx;
          return const Scaffold();
        }))));
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, (_) async {
      calls++;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, null));
    var finished = false;
    final exporting = ReportExports.saveCard(context, title: '回顾', body: '记录')
        .then((_) => finished = true);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(finished, isTrue);
    await exporting;
    expect(calls, 0);

    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      context = ctx;
      return const Scaffold();
    })));
    await ReportExports.saveImage(context, _png);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('样式选择期间权益失效后重新恢复，也终止旧的完整导出', (tester) async {
    final pro = ProStore()..isPro = true;
    addTearDown(pro.dispose);
    late BuildContext context;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: pro,
        child: MaterialApp(home: Builder(builder: (ctx) {
          context = ctx;
          return const Scaffold();
        }))));
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, (_) async {
      calls++;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, null));
    final exporting = ReportExports.saveCard(context, title: '回顾', body: '记录');
    await tester.pumpAndSettle();

    pro.isPro = false;
    pro.notifyListeners();
    pro.isPro = true;
    pro.notifyListeners();
    await tester.tap(find.text('暖纸'));
    await tester.pumpAndSettle();
    await exporting;
    expect(calls, 0);
    await ReportExports.saveImage(context, _png);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PDF 异步生成期间权益变更，不把旧任务继续发送到原生', (tester) async {
    final pro = ProStore()..isPro = true;
    addTearDown(pro.dispose);
    late BuildContext context;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: pro,
        child: MaterialApp(home: Builder(builder: (ctx) {
          context = ctx;
          return const Scaffold();
        }))));
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, (_) async {
      calls++;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, null));

    await tester.runAsync(() async {
      final exporting = ReportExports.savePdf(context,
          title: '回顾', body: List.filled(100, '书影记录与私人感想').join('\n'));
      pro.isPro = false;
      pro.notifyListeners();
      pro.isPro = true;
      pro.notifyListeners();
      await exporting;
    });
    expect(calls, 0);
    await ReportExports.saveImage(context, _png);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
