import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/report_exports.dart';
import '../services/pro_store.dart';

/// 预览可查看真实汇总，但不能调用完整报告导出；不影响免费的原始 JSON 备份。
class ReviewExportActions extends StatefulWidget {
  const ReviewExportActions(
      {super.key,
      required this.title,
      required this.body,
      required this.preview});
  final String title, body;
  final bool preview;

  @override
  State<ReviewExportActions> createState() => _ReviewExportActionsState();
}

class _ReviewExportActionsState extends State<ReviewExportActions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final unlocked = !widget.preview && context.watch<ProStore>().isPro;
    final enabled = unlocked && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!unlocked)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('当前为预览。Pro 解锁完整选择、对照与报告导出；基础月度回顾和 JSON 备份继续免费。'),
          ),
        OutlinedButton.icon(
          key: const Key('review-copy'),
          onPressed: !enabled ? null : () => _export(_copy),
          icon: const Icon(Icons.copy_outlined),
          label: const Text('复制完整回顾'),
        ),
        OutlinedButton.icon(
          key: const Key('review-pdf'),
          onPressed: !enabled
              ? null
              : () => _export(() => ReportExports.savePdf(context,
                  title: widget.title, body: widget.body)),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('保存 PDF 报告'),
        ),
        OutlinedButton.icon(
          key: const Key('review-card'),
          onPressed: !enabled
              ? null
              : () => _export(() => ReportExports.saveCard(context,
                  title: widget.title, body: widget.body)),
          icon: const Icon(Icons.image_outlined),
          label: const Text('保存回顾图片'),
        ),
        if (_busy) const Text('正在处理，请完成或取消当前操作。'),
      ],
    );
  }

  bool get _isCurrent => mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  bool get _canExport =>
      _isCurrent && !widget.preview && context.read<ProStore>().isPro;

  Future<void> _export(Future<void> Function() action) async {
    if (_busy || !_canExport) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(
          ClipboardData(text: '${widget.title}\n${widget.body}'));
      if (!mounted || !_canExport) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('回顾已复制')));
    } catch (_) {
      if (!mounted || !_isCurrent) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('复制未完成，请重试或保存 PDF 报告。')));
    }
  }
}
