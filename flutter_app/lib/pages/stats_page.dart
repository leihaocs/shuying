import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/books.dart' as bl;
import '../domain/fmt.dart';
import '../models/models.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';
import '../widgets/sheets.dart' show pickDayOnly;
import 'book_detail_page.dart';
import 'home_shell.dart';
import 'movie_detail_page.dart';

const List<String> _weekLabels = ['日', '一', '二', '三', '四', '五', '六'];

class _DayBar {
  const _DayBar(this.label, this.day, this.value, this.isToday);

  final String label;
  final String day;
  final int value;
  final bool isToday;
}

/// 阅读记录行（统计页聚合用）
class _ReadingLogRow {
  const _ReadingLogRow({
    required this.at,
    this.minutes,
    this.pages,
    this.progress,
    required this.bookId,
    required this.title,
    required this.cover,
  });

  final DateTime at;
  final int? minutes;
  final int? pages;
  final int? progress;
  final String bookId;
  final String title;
  final String cover;
}

/// 观影记录行（统计页聚合用）
class _WatchRow {
  const _WatchRow({
    required this.at,
    this.rating,
    required this.movieId,
    required this.title,
  });

  final DateTime at;
  final int? rating;
  final String movieId;
  final String title;
}

class _Activity {
  const _Activity({
    required this.isRead,
    required this.at,
    required this.title,
    required this.detail,
    required this.targetId,
  });

  final bool isRead;
  final DateTime at;
  final String title;
  final String detail;
  final String targetId;
}

enum _StatsScope { all, books, movies }

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTime? _activityDay;
  _StatsScope _scope = _StatsScope.all;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final store = context.watch<AppStore>();
    final showBooks = _scope != _StatsScope.movies;
    final showMovies = _scope != _StatsScope.books;
    final books = showBooks ? store.books : const <Book>[];
    final movies = showMovies ? store.movies : const <Movie>[];

    /* ---------------- 汇总 ---------------- */
    var minutes = 0;
    var pages = 0;
    var readTimes = 0;
    final allLogs = <_ReadingLogRow>[];

    for (final b in books) {
      readTimes += bl.bookSummary(b).readTimes;
      for (final r in b.rounds) {
        minutes += bl.roundMinutes(r);
        pages += bl.roundPages(r);
        final aggregate = r.pages != null || r.minutes != null;
        if (aggregate || (!r.isActive && r.logs.isEmpty)) {
          // 本轮累计校正只投影到统计，不制造或修改单次阅读明细。
          allLogs.add(_ReadingLogRow(
              at: bl.roundTotalsDate(r),
              pages: r.pages,
              minutes: r.minutes,
              bookId: b.id,
              title: b.title,
              cover: b.cover));
        }
        for (final l in r.logs) {
          final logPages = r.pages != null ? null : l.pages;
          final logMinutes = r.minutes != null ? null : l.minutes;
          if (aggregate && logPages == null && logMinutes == null) continue;
          allLogs.add(_ReadingLogRow(
            at: l.at,
            minutes: logMinutes,
            pages: logPages,
            progress: r.isActive ? l.progress : null,
            bookId: b.id,
            title: b.title,
            cover: b.cover,
          ));
        }
      }
    }

    var watchTimes = 0;
    final allWatches = <_WatchRow>[];
    for (final m in movies) {
      watchTimes += m.watches.length;
      for (final w in m.watches) {
        allWatches.add(_WatchRow(
          at: w.at,
          rating: w.rating,
          movieId: m.id,
          title: m.title,
        ));
      }
    }

    final rated = allWatches.where((w) => w.rating != null).toList();
    final averageRating = rated.isEmpty
        ? '—'
        : (rated.fold<int>(0, (sum, w) => sum + w.rating!) / rated.length)
            .toStringAsFixed(1);

    /* ---------------- 近 7 天 ---------------- */
    final now = DateTime.now();
    final days = <_DayBar>[];
    for (var i = 0; i < 7; i++) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - i));
      var mins = 0;
      for (final l in allLogs) {
        if (isSameDay(l.at, d)) mins += l.minutes ?? 0;
      }
      days.add(_DayBar(
        _weekLabels[d.weekday % 7],
        '${d.month}/${d.day}',
        mins,
        i == 6,
      ));
    }
    final watchDays = [
      for (var i = 0; i < 7; i++)
        _DayBar(
            days[i].label,
            days[i].day,
            allWatches
                .where((w) => isSameDay(
                    w.at, DateTime(now.year, now.month, now.day - 6 + i)))
                .length,
            i == 6),
    ];
    final weekWatches = watchDays.fold<int>(0, (sum, d) => sum + d.value);
    final weekTotal = days.fold<int>(0, (s, d) => s + d.value);

    /* ---------------- 最近动态 ---------------- */
    final activity = <_Activity>[
      for (final book in books)
        for (final round in book.rounds) ...[
          if (round.logs.isEmpty && !round.isActive)
            _Activity(
                isRead: true,
                at: round.finishedAt!,
                title: book.title,
                targetId: book.id,
                detail: [
                  '读完',
                  if (bl.roundPages(round) > 0) '${bl.roundPages(round)} 页',
                  if (bl.roundMinutes(round) > 0)
                    formatDuration(bl.roundMinutes(round))
                ].join(' · ')),
          for (final l in round.logs)
            _Activity(
              isRead: true,
              at: l.at,
              title: book.title,
              targetId: book.id,
              detail: [
                if (l.pages != null) '${l.pages} 页',
                if (l.minutes != null) formatDuration(l.minutes),
                if (round.isActive && l.progress != null) '进度 ${l.progress}%',
              ].join(' · '),
            ),
        ],
      for (final w in allWatches)
        _Activity(
          isRead: false,
          at: w.at,
          title: w.title,
          targetId: w.movieId,
          detail: w.rating != null ? '${w.rating}/10 分' : '看过',
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    final visibleActivity = _activityDay == null
        ? activity.take(8).toList()
        : activity.where((a) => isSameDay(a.at, _activityDay!)).toList();

    final reading = books.where((b) => bl.activeRound(b) != null).toList()
      ..sort((a, b) => bl.bookLastTouch(b).compareTo(bl.bookLastTouch(a)));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const PageHeader(
            title: '统计',
            subtitle: '点点滴滴，都在这里',
          ),
          SegmentedBar(
              index: _scope.index,
              items: const [SegItem('都统计'), SegItem('只统计书籍'), SegItem('只统计电影')],
              onChanged: (i) => setState(() => _scope = _StatsScope.values[i])),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBooks)
                  StatGrid(
                    cells: [
                      StatCell(value: '$readTimes', label: '读完次数'),
                      StatCell(value: compactDuration(minutes), label: '阅读时长'),
                      StatCell(value: '$pages', label: '累计页数'),
                    ],
                  ),
                const SizedBox(height: 10),
                StatGrid(
                  cells: [
                    if (showBooks)
                      StatCell(value: '${books.length}', label: '书架书籍'),
                    if (showMovies) ...[
                      StatCell(value: '${movies.length}', label: '电影收藏'),
                      StatCell(value: '$watchTimes', label: '观影次数'),
                      if (!showBooks)
                        StatCell(value: averageRating, label: '平均分 /10'),
                    ] else ...[
                      StatCell(value: '${reading.length}', label: '在读书籍'),
                      StatCell(
                          value:
                              '${books.where((b) => bl.bookStatus(b) == BookStatus.finished).length}',
                          label: '已读书籍'),
                    ],
                  ],
                ),
                if (showBooks) ...[
                  const SizedBox(height: 24),
                  _WeekChart(
                      title: '近 7 天阅读时长',
                      days: days,
                      footer: '本周共 ${formatDuration(weekTotal)}'),
                ],
                if (showMovies) ...[
                  const SizedBox(height: 24),
                  _WeekChart(
                      title: '近 7 天观影次数',
                      days: watchDays,
                      footer: '本周共 $weekWatches 次观影'),
                ],
                if (showBooks && reading.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const SectionTitle('正在读'),
                  for (final b in reading) ...[
                    _ReadingTile(book: b),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 24),
                const SectionTitle('最近动态'),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  ChoiceChip(
                      label: const Text('全部'),
                      selected: _activityDay == null,
                      onSelected: (_) => setState(() => _activityDay = null)),
                  ChoiceChip(
                      label: const Text('今天'),
                      selected:
                          _activityDay != null && isSameDay(_activityDay!, now),
                      onSelected: (_) => setState(() => _activityDay =
                          DateTime(now.year, now.month, now.day))),
                  ChoiceChip(
                      label: const Text('昨天'),
                      selected: _activityDay != null &&
                          isSameDay(_activityDay!,
                              DateTime(now.year, now.month, now.day - 1)),
                      onSelected: (_) => setState(() => _activityDay =
                          DateTime(now.year, now.month, now.day - 1))),
                  TextButton.icon(
                      key: const Key('activity-pick-date'),
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: const Text('选择日期'),
                      onPressed: () async {
                        final day =
                            await pickDayOnly(context, _activityDay ?? now);
                        if (day != null && mounted) {
                          setState(() => _activityDay = day);
                        }
                      }),
                ]),
                if (_activityDay != null)
                  Row(children: [
                    IconButton(
                        key: const Key('activity-previous-day'),
                        tooltip: '前一天',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(() => _activityDay = DateTime(
                            _activityDay!.year,
                            _activityDay!.month,
                            _activityDay!.day - 1))),
                    Expanded(
                        child: Text(formatDate(_activityDay),
                            textAlign: TextAlign.center)),
                    IconButton(
                        key: const Key('activity-next-day'),
                        tooltip: '后一天',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: isSameDay(_activityDay!, now)
                            ? null
                            : () => setState(() => _activityDay = DateTime(
                                _activityDay!.year,
                                _activityDay!.month,
                                _activityDay!.day + 1))),
                  ]),
                const SizedBox(height: 8),
                if (visibleActivity.isEmpty)
                  CardBox(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _activityDay == null
                          ? '还没有${showBooks && showMovies ? '阅读或观影' : showBooks ? '阅读' : '观影'}记录。'
                          : '这一天还没有${showBooks && showMovies ? '阅读或观影' : showBooks ? '阅读' : '观影'}记录。',
                      style: TextStyle(fontSize: 13.5, color: c.text3),
                    ),
                  )
                else ...[
                  for (final a in visibleActivity)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CardBox(
                        padding: const EdgeInsets.all(13),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => a.isRead
                                ? BookDetailPage(bookId: a.targetId)
                                : MovieDetailPage(movieId: a.targetId),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${a.isRead ? '📖' : '🎬'} ${a.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: c.text,
                                    ),
                                  ),
                                  if (a.detail.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      a.detail,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: c.text2,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(formatDateTime(a.at),
                                      style: TextStyle(
                                          fontSize: 12, color: c.text3)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 26),
                Center(
                  child: Text(
                    '数据只保存在这台设备上',
                    style: TextStyle(fontSize: 12, color: c.text3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart(
      {required this.title, required this.days, required this.footer});
  final String title;
  final List<_DayBar> days;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final maxValue = days.fold<int>(1, (m, d) => d.value > m ? d.value : m);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(title),
      CardBox(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        child: Column(
          children: [
            SizedBox(
              height: 118,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: d.value > 0
                                ? (d.value / maxValue * 76)
                                    .clamp(6.0, 76.0)
                                    .toDouble()
                                : 3.0,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              gradient: c.accentGradient,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(7),
                                topRight: Radius.circular(7),
                                bottomLeft: Radius.circular(3),
                                bottomRight: Radius.circular(3),
                              ),
                              boxShadow: d.isToday
                                  ? [
                                      BoxShadow(
                                        color: c.accentSoft,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            d.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: c.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 13),
              child: Text(
                footer,
                style: TextStyle(fontSize: 12.5, color: c.text3),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final b = book;
    final active = bl.activeRound(b);
    final pct = bl.roundProgress(b, active);

    return CardBox(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookDetailPage(bookId: b.id),
        ),
      ),
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          BookCover(
            cover: b.cover,
            accent: b.accent,
            width: 40,
            height: 56,
            fontSize: 18,
            radius: 8,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 8),
                ProgressBar(value: pct / 100),
                const SizedBox(height: 8),
                Text(
                  '${b.author} · 第 ${active!.index} 轮 · $pct%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
