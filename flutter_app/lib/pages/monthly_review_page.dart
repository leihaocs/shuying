import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../domain/period_review.dart' show reviewYears;
import '../domain/year_review.dart';
import '../models/models.dart';
import '../services/report_exports.dart';
import '../store/app_store.dart';

/// 基础月度回顾免费提供；年度深度统计仍使用原有 Pro 入口。
class MonthlyReviewPage extends StatefulWidget {
  const MonthlyReviewPage(
      {super.key, this.includeBooks = true, this.includeMovies = true});

  final bool includeBooks;
  final bool includeMovies;

  @override
  State<MonthlyReviewPage> createState() => _MonthlyReviewPageState();
}

class _MonthlyReviewPageState extends State<MonthlyReviewPage> {
  final _cardKey = GlobalKey();
  final _scroll = ScrollController();
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _sharing = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final books = widget.includeBooks ? store.books : const <Book>[];
    final movies = widget.includeMovies ? store.movies : const <Movie>[];
    final review = YearReview(books, movies, _year, month: _month);
    final years = <int>{
      _year,
      ...reviewYears(books, movies),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final scope = widget.includeBooks && widget.includeMovies
        ? '书籍与电影'
        : widget.includeBooks
            ? '书籍'
            : '电影';
    final metrics = <String, String>{
      if (widget.includeBooks) ...{
        '读完次数': '${review.readTimes}',
        '阅读页数': '${review.pages}',
        '阅读时长（分钟）': '${review.minutes}',
        '阅读天数': '${review.readingDays}',
      },
      if (widget.includeMovies) ...{
        '观影次数': '${review.watchTimes}',
        '平均评分 /10': review.averageRating?.toStringAsFixed(1) ?? '—',
      },
    };
    final text = '$_year 年 $_month 月 · 书影温故\n$scope\n'
        '${metrics.entries.map((e) => '${e.key}：${e.value}').join('\n')}';
    return Scaffold(
      appBar: AppBar(title: const Text('月度回顾')),
      body: SafeArea(
        top: false,
        child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(spacing: 20, children: [
                DropdownButton<int>(
                  key: const Key('review-year'),
                  value: _year,
                  items: [
                    for (final y in years)
                      DropdownMenuItem(value: y, child: Text('$y 年'))
                  ],
                  onChanged: _sharing
                      ? null
                      : (value) {
                          if (value != null) setState(() => _year = value);
                        },
                ),
                DropdownButton<int>(
                  key: const Key('review-month'),
                  value: _month,
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text('$m 月'))
                  ],
                  onChanged: _sharing
                      ? null
                      : (value) {
                          if (value != null) setState(() => _month = value);
                        },
                ),
              ]),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _cardKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F0E5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DefaultTextStyle(
                    style:
                        const TextStyle(color: Color(0xFF302A23), fontSize: 14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('书影温故',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF965035),
                                  letterSpacing: 3)),
                          const SizedBox(height: 12),
                          Text('$_year 年 $_month 月',
                              style: const TextStyle(
                                  fontSize: 27, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('我的月度回顾 · $scope'),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(color: Color(0xFFD7C9B9)),
                          ),
                          LayoutBuilder(
                              builder: (context, constraints) => Wrap(
                                    spacing: 16,
                                    runSpacing: 22,
                                    children: [
                                      for (final metric in metrics.entries)
                                        SizedBox(
                                          width:
                                              (constraints.maxWidth - 16) / 2,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(metric.value,
                                                      style: const TextStyle(
                                                          fontSize: 29,
                                                          fontWeight: FontWeight
                                                              .w700))),
                                              const SizedBox(height: 4),
                                              Text(metric.key),
                                            ],
                                          ),
                                        ),
                                    ],
                                  )),
                          const SizedBox(height: 26),
                          const Text('把读过的书、看过的电影，留在生活里。',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF796B5B))),
                        ]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('share-monthly-card'),
                onPressed: _sharing ? null : _shareCard,
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(_sharing ? '正在生成卡片…' : '分享卡片'),
              ),
              OutlinedButton.icon(
                key: const Key('save-monthly-card'),
                onPressed: _sharing ? null : () => _shareCard(save: true),
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('保存卡片图片（免费）'),
              ),
              TextButton.icon(
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (mounted) _message('月度回顾已复制');
                  } catch (_) {
                    if (mounted) _message('复制未完成，请重试或保存卡片图片');
                  }
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('复制月度回顾'),
              ),
              const SizedBox(height: 12),
              const Text(
                  '手动调整的累计页数和时长，计入本轮最后记录或读完的月份。'
                  '分享卡片只含汇总数字，不包含书名、片名或个人感想。',
                  style: TextStyle(fontSize: 12)),
            ]),
      ),
    );
  }

  Future<void> _shareCard({bool save = false}) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    ui.Image? image;
    try {
      // 大字体或小屏幕上分享按钮可能在卡片下方，先让卡片重新绘制。
      await _scroll.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('卡片尚未生成');
      image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('无法生成图片');
      final png =
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
      if (save) {
        if (mounted) await ReportExports.saveImage(context, png);
      } else {
        await const MethodChannel('com.bookmovie.revisit/share')
            .invokeMethod<void>('image', {'bytes': png});
      }
    } on MissingPluginException {
      if (mounted) _message('此平台暂不支持图片分享，可使用复制月度回顾');
    } catch (_) {
      if (mounted) _message('分享未完成，请重试或复制月度回顾');
    } finally {
      image?.dispose();
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
