import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/books.dart' as bl;
import '../domain/fmt.dart';
import '../models/models.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';
import 'book_detail_page.dart';
import 'home_shell.dart';
import 'movie_detail_page.dart';

const List<String> _weekLabels = ['日', '一', '二', '三', '四', '五', '六'];

class _DayBar {
  const _DayBar(this.label, this.day, this.minutes, this.isToday);

  final String label;
  final String day;
  final int minutes;
  final bool isToday;
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

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final store = context.watch<AppStore>();

    /* ---------------- 汇总 ---------------- */
    var minutes = 0;
    var pages = 0;
    var readTimes = 0;
    final allLogs = <({DateTime at, int? minutes, int? pages, int? progress,
        String bookId, String title, String cover})>[];

    for (final b in store.books) {
      readTimes += bl.bookSummary(b).readTimes;
      for (final r in b.rounds) {
        for (final l in r.logs) {
          minutes += l.minutes ?? 0;
          pages += l.pages ?? 0;
          allLogs.add((
            at: l.at,
            minutes: l.minutes,
            pages: l.pages,
            progress: l.progress,
            bookId: b.id,
            title: b.title,
            cover: b.cover,
          ));
        }
      }
    }

    var watchTimes = 0;
    final allWatches = <({DateTime at, int? rating, String movieId,
        String title})>[];
    for (final m in store.movies) {
      watchTimes += m.watches.length;
      for (final w in m.watches) {
        allWatches.add((
          at: w.at,
          rating: w.rating,
          movieId: m.id,
          title: m.title,
        ));
      }
    }

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
    final maxMins = days.fold<int>(1, (m, d) => d.minutes > m ? d.minutes : m);
    final weekTotal = days.fold<int>(0, (s, d) => s + d.minutes);

    /* ---------------- 最近动态 ---------------- */
    final activity = <_Activity>[
      for (final l in allLogs)
        _Activity(
          isRead: true,
          at: l.at,
          title: l.title,
          targetId: l.bookId,
          detail: [
            if (l.pages != null) '${l.pages} 页',
            if (l.minutes != null) formatDuration(l.minutes),
            if (l.progress != null) '进度 ${l.progress}%',
          ].join(' · '),
        ),
      for (final w in allWatches)
        _Activity(
          isRead: false,
          at: w.at,
          title: w.title,
          targetId: w.movieId,
          detail: w.rating != null ? '${w.rating} 星' : '看过',
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    final reading = store.books.where((b) => bl.activeRound(b) != null).toList()
      ..sort((a, b) => bl.bookLastTouch(b).compareTo(bl.bookLastTouch(a)));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          PageHeader(
            title: '统计',
            subtitle: '点点滴滴，都在这里',
            trailing: RoundIconButton(
              icon: store.themeMode == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              onPressed: store.toggleTheme,
              tooltip: '切换主题',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    StatCell(value: '${store.books.length}', label: '书架书籍'),
                    StatCell(value: '${store.movies.length}', label: '电影收藏'),
                    StatCell(value: '$watchTimes', label: '观影次数'),
                  ],
                ),

                const SizedBox(height: 24),
                const SectionTitle('近 7 天阅读时长'),
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
                                      height: d.minutes > 0
                                          ? (d.minutes / maxMins * 76)
                                              .clamp(6.0, 76.0)
                                              .toDouble()
                                          : 3.0,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 6),
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
                          '本周共 ${formatDuration(weekTotal)}',
                          style: TextStyle(fontSize: 12.5, color: c.text3),
                        ),
                      ),
                    ],
                  ),
                ),

                if (reading.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const SectionTitle('正在读'),
                  for (final b in reading) ...[
                    _ReadingTile(book: b),
                    const SizedBox(height: 10),
                  ],
                ],

                const SizedBox(height: 24),
                const SectionTitle('最近动态'),
                if (activity.isEmpty)
                  CardBox(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '还没有任何记录，去书架添加一本书开始吧。',
                      style: TextStyle(fontSize: 13.5, color: c.text3),
                    ),
                  )
                else ...[
                  for (final a in activity.take(8))
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
                                ],
                              ),
                            ),
                            Text(
                              relativeDay(a.at),
                              style: TextStyle(fontSize: 12, color: c.text3),
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
