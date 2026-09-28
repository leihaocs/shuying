import 'package:flutter/material.dart';

import '../domain/fmt.dart';
import '../domain/movies.dart' as ml;
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'bits.dart';

class MovieTile extends StatelessWidget {
  const MovieTile({super.key, required this.movie, required this.onTap});

  final Movie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final last = ml.lastWatch(movie);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        onTap: onTap,
        padding: const EdgeInsets.all(13),
        // IntrinsicHeight：文字列与底部状态行对齐需要 Spacer，
        // 必须先给 Row 一个有界高度，否则在无界高度的列表项里会崩溃。
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 44,
                height: 62,
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                alignment: Alignment.center,
                child: const Text('🎬', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      movie.year == null
                          ? movie.director
                          : '${movie.director} · ${movie.year}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: c.text2),
                    ),
                    const Spacer(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        MovieStatusPill(movie),
                        const SizedBox(width: 8),
                        if (last?.rating != null)
                          StarRow(rating: last!.rating, size: 13),
                        Text(
                          last == null
                              ? relativeDay(movie.createdAt)
                              : relativeDay(last.at),
                          style: TextStyle(fontSize: 12, color: c.text3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
