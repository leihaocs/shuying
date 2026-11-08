import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/fmt.dart';
import '../domain/period_review.dart';
import '../services/pro_store.dart';
import '../store/app_store.dart';
import '../widgets/bits.dart';
import '../widgets/review_export_actions.dart';
import 'pro_page.dart';

class RevisitComparisonPage extends StatelessWidget {
  const RevisitComparisonPage(
      {super.key, this.bookId, this.movieId, this.preview = false})
      : assert((bookId == null) != (movieId == null));
  final String? bookId, movieId;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProStore>();
    final store = context.watch<AppStore>();
    if (!preview && !pro.isPro) return const ProPage();
    final limited = !pro.isPro;
    final book = bookId == null ? null : store.bookById(bookId!);
    final movie = movieId == null ? null : store.movieById(movieId!);
    if (book == null && movie == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('历次对照')),
          body: const Center(child: Text('这条书影记录已不存在。')));
    }
    final isBook = book != null;
    final title = book?.title ?? movie!.title;
    final records = book != null ? bookRevisits(book) : movieRevisits(movie!);
    final visible = limited ? records.take(2).toList() : records;
    final reportTitle = '《$title》历次${isBook ? '阅读' : '观影'}对照';
    final report = [
      if (book != null)
        '当前全书评分：${book.rating == null ? '未评分' : '${book.rating}/10'}'
            '（未记录每轮独立评分）',
      for (final record in records) _entryText(record, isBook),
    ].join('\n\n');
    return Scaffold(
      appBar: AppBar(title: Text(limited ? '历次对照 · 预览' : '历次对照')),
      body: SafeArea(
        top: false,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (limited) ...[
            const Text('预览展示最近两次真实记录。原始记录和感想仍可在详情页免费查看、修改和备份。'),
            const SizedBox(height: 12),
          ],
          if (book != null) ...[
            Text('当前全书评分：${book.rating == null ? '未评分' : '${book.rating}/10'}'),
            const Text('书籍评分属于全书，未保存每轮独立评分；历史轮次仅对照时间、累计阅读量与感想，当前轮次另外显示进度。'),
            const SizedBox(height: 16),
          ],
          if (records.length < 2)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('目前只有 ${records.length} 次记录，再次记录后即可比较变化。')),
          for (var i = 0; i < visible.length; i++) ...[
            CardBox(
              key: ValueKey('revisit-${visible[i].number}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('第 ${visible[i].number} 次${isBook ? '阅读' : '观看'}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(isBook
                      ? '开始 ${formatDateTime(visible[i].startedAt)}\n'
                          '${visible[i].finishedAt == null ? '尚未读完' : '读完 ${formatDateTime(visible[i].finishedAt)}'}'
                      : formatDateTime(visible[i].startedAt)),
                  const SizedBox(height: 8),
                  if (isBook) ...[
                    Text(
                        '本轮累计 ${visible[i].pages} 页 · ${visible[i].minutes} 分钟'),
                    if (visible[i].progress != null)
                      Text('当前轮次进度 ${visible[i].progress}%'),
                  ] else ...[
                    Text(visible[i].rating == null
                        ? '未评分'
                        : '评分 ${visible[i].rating}/10'),
                    if (i + 1 < visible.length &&
                        visible[i].rating != null &&
                        visible[i + 1].rating != null)
                      Text(_ratingChange(
                          visible[i].rating! - visible[i + 1].rating!)),
                  ],
                  const SizedBox(height: 12),
                  Text(visible[i].note.trim().isEmpty
                      ? '这次尚未记录感想。'
                      : visible[i].note),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (limited && records.length > visible.length)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                    '还有 ${records.length - visible.length} 次，可在 Pro 完整对照中查看。')),
          const Text('按实际时间倒序排列；修改或补记记录后，顺序与对照内容会随记录更新。'),
          const SizedBox(height: 20),
          ReviewExportActions(
              title: reportTitle, body: report, preview: limited),
          if (limited)
            TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) => const ProPage())),
                child: Text(pro.purchasesEnabled ? '了解 Pro 与恢复购买' : '了解高级功能')),
        ]),
      ),
    );
  }

  String _ratingChange(int change) => change == 0
      ? '与上次评分相同'
      : '比上次${change > 0 ? '提高' : '降低'} ${change.abs()} 分';

  String _entryText(RevisitEntry record, bool isBook) =>
      '第 ${record.number} 次${isBook ? '阅读' : '观看'}\n'
      '${formatDateTime(record.startedAt)}'
      '${isBook ? ' 至 ${record.finishedAt == null ? '尚未读完' : formatDateTime(record.finishedAt)}' : ''}\n'
      '${isBook ? '本轮累计 ${record.pages} 页 · ${record.minutes} 分钟' : '评分 ${record.rating == null ? '未评分' : '${record.rating}/10'}'}'
      '${record.progress == null ? '' : '\n当前轮次进度 ${record.progress}%'}\n'
      '感想：${record.note.trim().isEmpty ? '未填写' : record.note}';
}
