import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/fmt.dart';
import '../domain/period_review.dart';
import '../domain/year_review.dart';
import '../services/pro_store.dart';
import '../store/app_store.dart';
import '../widgets/bits.dart';
import '../widgets/review_export_actions.dart';
import 'pro_page.dart';
import 'revisit_comparison_page.dart';

class AdvancedReviewPage extends StatefulWidget {
  const AdvancedReviewPage({super.key, this.preview = false});
  final bool preview;

  @override
  State<AdvancedReviewPage> createState() => _AdvancedReviewPageState();
}

class _AdvancedReviewPageState extends State<AdvancedReviewPage> {
  DateTimeRange? _range;
  int? _year, _otherYear;
  bool _compare = false;

  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProStore>();
    final store = context.watch<AppStore>();
    if (!widget.preview && !pro.isPro) return const ProPage();
    final preview = !pro.isPro;
    final last = latestReviewDate(store.books, store.movies) ?? DateTime.now();
    final end = DateTime(last.year, last.month, last.day);
    final range = (preview ? null : _range) ??
        DateTimeRange(
            start: DateTime(end.year, end.month, end.day - 29), end: end);
    final year = (preview ? null : _year) ?? last.year;
    final otherYear = (preview ? null : _otherYear) ?? year - 1;
    final years = {...reviewYears(store.books, store.movies), year, otherYear}
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final review = PeriodReview(store.books, store.movies,
        start: range.start, end: range.end);
    final first = YearReview(store.books, store.movies, year);
    final second = YearReview(store.books, store.movies, otherYear);
    final title = _compare
        ? '$year 与 $otherYear 年书影对比'
        : '${formatDate(range.start)} 至 ${formatDate(range.end)} 书影回顾';
    final body = _compare
        ? '$year 年\n${_summary(first)}\n\n$otherYear 年\n${_summary(second)}'
            '\n\n$year 相比 $otherYear\n'
            '阅读页数 ${_change(first.pages - second.pages)} 页\n'
            '阅读时长 ${_change(first.minutes - second.minutes)} 分钟\n'
            '读完次数 ${_change(first.readTimes - second.readTimes)} 次\n'
            '观影次数 ${_change(first.watchTimes - second.watchTimes)} 次'
        : _summary(review);
    return Scaffold(
      appBar: AppBar(title: Text(preview ? '深度回顾 · 预览' : '深度书影回顾')),
      body: SafeArea(
        top: false,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (preview) ...[
            const Text('以下汇总来自你的真实记录。预览固定最近记录所在的 30 天与相邻年份；Pro 可自由选择日期和年份。'),
            const SizedBox(height: 16),
          ],
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
                label: const Text('任选时间范围'),
                selected: !_compare,
                onSelected: (_) => setState(() => _compare = false)),
            ChoiceChip(
                label: const Text('跨年对比'),
                selected: _compare,
                onSelected: (_) => setState(() => _compare = true)),
          ]),
          const SizedBox(height: 16),
          if (!_compare) ...[
            OutlinedButton.icon(
                key: const Key('review-range'),
                onPressed: preview ? null : () => _selectRange(range),
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                    '${formatDate(range.start)} 至 ${formatDate(range.end)}')),
            const SizedBox(height: 12),
            _metrics(review),
          ] else ...[
            Wrap(spacing: 16, runSpacing: 8, children: [
              DropdownButton<int>(
                  key: const Key('review-year'),
                  value: year,
                  items: [
                    for (final value in years)
                      DropdownMenuItem(value: value, child: Text('$value 年'))
                  ],
                  onChanged: preview
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _year = value;
                            if (value == otherYear) _otherYear = year;
                          });
                        }),
              DropdownButton<int>(
                  key: const Key('review-other-year'),
                  value: otherYear,
                  items: [
                    for (final value in years)
                      DropdownMenuItem(value: value, child: Text('$value 年'))
                  ],
                  onChanged: preview
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _otherYear = value;
                            if (value == year) _year = otherYear;
                          });
                        }),
            ]),
            const SizedBox(height: 12),
            CardBox(
                child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.3),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
              },
              children: [
                _row('指标', '$year 年', '$otherYear 年'),
                _row('涉及书籍', '${first.bookCount} 本', '${second.bookCount} 本'),
                _row('读完次数', '${first.readTimes} 次', '${second.readTimes} 次'),
                _row('阅读页数', '${first.pages} 页', '${second.pages} 页'),
                _row('阅读时长', '${first.minutes} 分', '${second.minutes} 分'),
                _row('阅读天数', '${first.readingDays} 天',
                    '${second.readingDays} 天'),
                _row('涉及电影', '${first.movieCount} 部', '${second.movieCount} 部'),
                _row('观影次数', '${first.watchTimes} 次', '${second.watchTimes} 次'),
                _row('观影均分 /10', _rating(first), _rating(second)),
              ],
            )),
          ],
          const SizedBox(height: 16),
          const Text('起止日期均包含。累计校正量归入本轮结束或最近记录日期，不与单次记录重复计算；观影均分只计算已评分记录。'),
          const SizedBox(height: 20),
          ReviewExportActions(title: title, body: body, preview: preview),
          const SizedBox(height: 24),
          const SectionTitle('重读与重看对照'),
          if (!store.books.any((book) => book.rounds.length > 1) &&
              !store.movies.any((movie) => movie.watches.length > 1))
            const Text('同一本书有两轮阅读，或同一部电影看过两次后，就能在这里对照不同时期的感受。'),
          for (final book
              in store.books.where((book) => book.rounds.length > 1))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(book.title),
              subtitle: Text('${book.rounds.length} 轮阅读 · 日期、累计页数与时长、感想'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => RevisitComparisonPage(
                          bookId: book.id, preview: preview))),
            ),
          for (final movie
              in store.movies.where((movie) => movie.watches.length > 1))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(movie.title),
              subtitle: Text('${movie.watches.length} 次观看 · 日期、评分与感想'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => RevisitComparisonPage(
                          movieId: movie.id, preview: preview))),
            ),
          if (preview)
            TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) => const ProPage())),
                child: Text(pro.purchasesEnabled ? '了解 Pro 与恢复购买' : '了解高级功能')),
        ]),
      ),
    );
  }

  Future<void> _selectRange(DateTimeRange range) async {
    final selected = await showDateRangePicker(
        context: context,
        initialDateRange: range,
        firstDate: DateTime(1),
        lastDate: DateTime(9999, 12, 31),
        helpText: '选择回顾起止日期');
    if (selected != null && mounted) setState(() => _range = selected);
  }

  Widget _metrics(PeriodReview review) => Column(children: [
        StatGrid(cells: [
          StatCell(value: '${review.bookCount}', label: '涉及书籍'),
          StatCell(value: '${review.readTimes}', label: '读完次数'),
          StatCell(value: '${review.pages}', label: '阅读页数'),
        ]),
        const SizedBox(height: 12),
        StatGrid(cells: [
          StatCell(value: '${review.minutes}', label: '阅读分钟'),
          StatCell(value: '${review.readingDays}', label: '阅读天数'),
          StatCell(value: '${review.watchTimes}', label: '观影次数'),
        ]),
        const SizedBox(height: 12),
        Text('涉及电影 ${review.movieCount} 部 · 观影均分 ${_rating(review)}/10'),
      ]);

  TableRow _row(String label, String first, String second) =>
      TableRow(children: [
        for (final value in [label, first, second])
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(value)),
      ]);

  String _rating(PeriodReview review) =>
      review.averageRating?.toStringAsFixed(1) ?? '—';
  String _change(int value) => value > 0 ? '+$value' : '$value';
  String _summary(PeriodReview review) =>
      '涉及书籍 ${review.bookCount} 本 · 读完 ${review.readTimes} 次\n'
      '阅读 ${review.pages} 页 · ${review.minutes} 分钟 · ${review.readingDays} 天\n'
      '涉及电影 ${review.movieCount} 部 · 观看 ${review.watchTimes} 次\n'
      '观影均分 ${_rating(review)}/10（${review.ratingCount} 次已评分）\n'
      '累计校正按本轮结束或最近记录日期计入，不重复累计单次量。';
}
