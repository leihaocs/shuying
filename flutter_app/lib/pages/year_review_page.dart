import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/period_review.dart';
import '../domain/year_review.dart';
import '../services/pro_store.dart';
import '../store/app_store.dart';
import '../widgets/bits.dart';
import '../widgets/review_export_actions.dart';
import 'advanced_review_page.dart';
import 'pro_page.dart';

class YearReviewPage extends StatefulWidget {
  const YearReviewPage({super.key, this.preview = false});
  final bool preview;
  @override
  State<YearReviewPage> createState() => _YearReviewPageState();
}

class _YearReviewPageState extends State<YearReviewPage> {
  int? _year;
  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProStore>();
    final store = context.watch<AppStore>();
    if (!widget.preview && !pro.isPro) return const ProPage();
    final preview = !pro.isPro;
    final latest = latestReviewDate(store.books, store.movies);
    final sample = preview && latest == null;
    final year = (preview ? null : _year) ??
        (preview ? latest?.year ?? DateTime.now().year : DateTime.now().year);
    final books = sample ? sampleReviewBooks(year) : store.books;
    final movies = sample ? sampleReviewMovies(year) : store.movies;
    final review = YearReview(books, movies, year);
    final years = reviewYears(books, movies);
    if (!years.contains(year)) years.add(year);
    final minutes = review.minutes;
    final pages = review.pages;
    final readTimes = review.readTimes;
    final readingDays = review.readingDays;
    final watches = review.watchTimes;
    final rating = review.averageRating?.toStringAsFixed(1) ?? '—';
    final text = '读完 $readTimes 次 · 阅读 $pages 页 · $minutes 分钟\n'
        '阅读 $readingDays 天 · 观影 $watches 次 · 观影均分 $rating/10\n'
        '涉及书籍 ${review.bookCount} 本 · 电影 ${review.movieCount} 部\n'
        '每月阅读分钟 / 观影次数\n'
        '${List.generate(12, (month) => '${month + 1} 月：${review.monthlyMinutes[month]} 分钟 / ${review.monthlyWatches[month]} 次').join('\n')}\n'
        '累计校正按本轮结束或最近记录日期归属，不与单次量重复计算。';
    return Scaffold(
      appBar: AppBar(
          title: Text(sample
              ? '示例年度回顾'
              : preview
                  ? '我的年度回顾 · 预览'
                  : '年度书影回顾')),
      body: SafeArea(
          top: false,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            if (sample)
              const Text('你还没有阅读或观影记录。以下为示例数据，不是你的记录，也不会写入本机。')
            else if (preview)
              const Text('以下预览来自你的真实记录，默认展示最近有记录的年份。Pro 可切换年份并保存完整报告。'),
            DropdownButton<int>(
                value: year,
                items: [
                  for (final y in years)
                    DropdownMenuItem(value: y, child: Text('$y 年'))
                ],
                onChanged: preview
                    ? null
                    : (v) {
                        if (v != null) setState(() => _year = v);
                      }),
            const SizedBox(height: 12),
            StatGrid(cells: [
              StatCell(value: '$readTimes', label: '读完次数'),
              StatCell(value: '$pages', label: '阅读页数'),
              StatCell(
                  value: '${(minutes / 60).toStringAsFixed(1)}h', label: '阅读时长')
            ]),
            const SizedBox(height: 12),
            StatGrid(cells: [
              StatCell(value: '$readingDays', label: '阅读天数'),
              StatCell(value: '$watches', label: '观影次数'),
              StatCell(value: rating, label: '观影均分 /10')
            ]),
            const SizedBox(height: 24),
            const Text('12 个月阅读与观影'),
            const SizedBox(height: 12),
            CardBox(
                child: Column(children: [
              for (var month = 0; month < 12; month++)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(children: [
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text('${month + 1} 月'),
                            Text('${review.monthlyMinutes[month]} 分钟 · '
                                '${review.monthlyWatches[month]} 次观影')
                          ]),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                          value: _ratio(review.monthlyMinutes, month)),
                    ])),
            ])),
            const SizedBox(height: 20),
            ReviewExportActions(
                title: '$year 年书影温故', body: text, preview: preview),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => AdvancedReviewPage(preview: preview))),
                child: const Text('任选时间范围与跨年对比')),
          ])),
    );
  }

  double _ratio(List<int> values, int month) {
    final max = values.fold<int>(1, (a, b) => a > b ? a : b);
    return values[month] / max;
  }
}
