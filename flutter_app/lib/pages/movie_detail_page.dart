import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/fmt.dart';
import '../domain/movies.dart' as ml;
import '../models/models.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';
import '../widgets/sheets.dart';

class MovieDetailPage extends StatelessWidget {
  const MovieDetailPage({super.key, required this.movieId});

  final String movieId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final movie = store.movieById(movieId);
    final c = AppColors.of(context);

    if (movie == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              NavBar(title: '电影'),
              const Expanded(
                child: EmptyState(icon: '🗑️', title: '这部电影已经不在片单里了'),
              ),
            ],
          ),
        ),
      );
    }

    final watches = ml.sortedWatches(movie);
    final rated = watches.where((w) => w.rating != null).toList();
    final avg = rated.isEmpty
        ? null
        : rated.fold<int>(0, (s, w) => s + w.rating!) / rated.length;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NavBar(
              title: movie.title,
              actions: [
                RoundIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: '编辑',
                  onPressed: () => showMovieSheet(context, movie: movie),
                ),
                RoundIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: '删除',
                  onPressed: () async {
                    final ok = await confirmSheet(
                      context,
                      title: '删除《${movie.title}》？',
                      message: watches.isEmpty
                          ? '这部电影会从片单里移除。'
                          : '连同 ${watches.length} 次观影记录一起删除，无法恢复。',
                    );
                    if (!ok || !context.mounted) return;
                    store.removeMovie(movie.id);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _Hero(movie: movie),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          label: watches.isEmpty ? '标记为看过' : '再看一次',
                          kind: BtnKind.primary,
                          icon: watches.isEmpty
                              ? Icons.check_rounded
                              : Icons.replay_rounded,
                          expand: true,
                          onPressed: () async {
                            final ok = await showWatchSheet(
                              context,
                              movie: movie,
                            );
                            if (ok == true && context.mounted) {
                              showToast(context, '已记下这次观看');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SectionTitle('统计'),
                  StatGrid(
                    cells: [
                      StatCell(
                        value: '${watches.length}',
                        label: '观看次数',
                      ),
                      StatCell(
                        value: avg == null ? '—' : avg.toStringAsFixed(1),
                        label: '平均评分',
                      ),
                      StatCell(
                        value: watches.isEmpty
                            ? '—'
                            : relativeDay(watches.first.at),
                        label: '最近观看',
                      ),
                    ],
                  ),
                  if (movie.note != null) ...[
                    const SizedBox(height: 22),
                    SectionTitle('备注'),
                    CardBox(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        movie.note!,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: c.text2,
                          height: 1.7,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SectionTitle(
                    '观影记录',
                    trailing: Text(
                      '${watches.length} 次',
                      style: TextStyle(fontSize: 12, color: c.text3),
                    ),
                  ),
                  if (watches.isEmpty)
                    CardBox(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '还没看过。看完之后点上面的「标记为看过」，可以补上观看时间和打分。\n'
                        '同一部电影可以反复标记，经典值得多看几次。',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: c.text3,
                          height: 1.7,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < watches.length; i++)
                          _WatchTile(
                            movie: movie,
                            watch: watches[i],
                            index: watches.length - i,
                          ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  SectionTitle('电影信息'),
                  CardBox(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 2),
                    child: Column(
                      children: [
                        _InfoRow('导演', movie.director),
                        _InfoRow('上映年份', movie.year ?? '—'),
                        _InfoRow('加入时间', formatDate(movie.createdAt)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 92,
          height: 124,
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          alignment: Alignment.center,
          child: const Text('🎬', style: TextStyle(fontSize: 38)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movie.title,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                movie.director,
                style: TextStyle(fontSize: 13.5, color: c.text2),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  MovieStatusPill(movie),
                  if (movie.year != null)
                    Pill(
                      text: movie.year!,
                      background: c.surface2,
                      foreground: c.text2,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WatchTile extends StatelessWidget {
  const _WatchTile({
    required this.movie,
    required this.watch,
    required this.index,
  });

  final Movie movie;
  final WatchRecord watch;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardBox(
        padding: const EdgeInsets.fromLTRB(13, 11, 6, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.okSoft,
              ),
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.ok,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        relativeDay(watch.at),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatDate(watch.at),
                        style: TextStyle(fontSize: 11.5, color: c.text3),
                      ),
                    ],
                  ),
                  if (watch.rating != null) ...[
                    const SizedBox(height: 4),
                    StarRow(rating: watch.rating, size: 15),
                  ],
                  if (watch.note != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      watch.note!,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.text2,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: c.text3),
              splashRadius: 18,
              onPressed: () async {
                final ok = await confirmSheet(
                  context,
                  title: '删除这次观影记录？',
                  message: formatDateTime(watch.at),
                  confirmText: '删除',
                );
                if (!ok || !context.mounted) return;
                context.read<AppStore>().removeWatch(movie.id, watch.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: c.text3)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: c.text),
            ),
          ),
        ],
      ),
    );
  }
}
