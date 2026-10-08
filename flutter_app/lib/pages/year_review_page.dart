import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../domain/year_review.dart';
import '../services/pro_store.dart';
import '../store/app_store.dart';
import '../widgets/bits.dart';
import 'pro_page.dart';

class YearReviewPage extends StatefulWidget {
  const YearReviewPage({super.key, this.preview = false});
  final bool preview;
  @override
  State<YearReviewPage> createState() => _YearReviewPageState();
}

class _YearReviewPageState extends State<YearReviewPage> {
  int year = DateTime.now().year;
  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProStore>();
    final store = context.watch<AppStore>();
    if (!widget.preview && !pro.isPro) return const ProPage();
    final review = YearReview(store.books, store.movies, year);
    final years = <int>{
      DateTime.now().year,
      for (final b in store.books)
        for (final r in b.rounds) ...[
          if (r.finishedAt != null) r.finishedAt!.year,
          for (final l in r.logs) l.at.year,
        ],
      for (final m in store.movies)
        for (final w in m.watches) w.at.year,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    if (!years.contains(year)) years.add(year);
    final minutes = widget.preview ? 3600 : review.minutes;
    final pages = widget.preview ? 2400 : review.pages;
    final readTimes = widget.preview ? 12 : review.readTimes;
    final readingDays = widget.preview ? 90 : review.readingDays;
    final watches = widget.preview ? 24 : review.watchTimes;
    final rating = widget.preview
        ? '4.5'
        : review.averageRating?.toStringAsFixed(1) ?? '—';
    final text = '$year 年书影温故\n阅读 $readTimes 次 · $pages 页 · $minutes 分钟\n'
        '阅读 $readingDays 天 · 观影 $watches 次 · 平均评分 $rating';
    return Scaffold(
      appBar: AppBar(title: Text(widget.preview ? '示例年度回顾' : '年度书影回顾')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (widget.preview) const Text('以下为示例数据，不是你的记录。'),
        DropdownButton<int>(
            value: year,
            items: [
              for (final y in years)
                DropdownMenuItem(value: y, child: Text('$y 年'))
            ],
            onChanged: widget.preview
                ? null
                : (v) {
                    if (v != null) setState(() => year = v);
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
          StatCell(value: rating, label: '平均评分')
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
                  Row(children: [
                    Text('${month + 1} 月'),
                    const Spacer(),
                    Text(
                        '${widget.preview ? (month + 1) * 30 : review.monthlyMinutes[month]} 分钟 · '
                        '${widget.preview ? 2 : review.monthlyWatches[month]} 次观影')
                  ]),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                      value: widget.preview
                          ? (month + 1) / 12
                          : _ratio(review.monthlyMinutes, month)),
                ])),
        ])),
        const SizedBox(height: 20),
        ElevatedButton(
            onPressed: widget.preview
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('年度回顾已复制')));
                  },
            child: const Text('复制年度回顾')),
      ]),
    );
  }

  double _ratio(List<int> values, int month) {
    final max = values.fold<int>(1, (a, b) => a > b ? a : b);
    return values[month] / max;
  }
}
