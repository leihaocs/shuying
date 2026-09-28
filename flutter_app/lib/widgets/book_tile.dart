import 'package:flutter/material.dart';

import '../domain/books.dart' as bl;
import '../domain/fmt.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'bits.dart';

class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final active = bl.activeRound(book);
    final pct = bl.roundProgress(book, active);
    final summary = bl.bookSummary(book);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        onTap: onTap,
        padding: const EdgeInsets.all(13),
        // IntrinsicHeight：让 Row 拿到有界高度（取封面 74 与文字列的较大值），
        // 否则 stretch + Column 里的 Spacer 在无界高度约束下会崩溃。
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BookCover(
                cover: book.cover,
                accent: book.accent,
                width: 52,
                height: 74,
                fontSize: 24,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
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
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: c.text2),
                    ),
                    if (active != null) ...[
                      const SizedBox(height: 8),
                      ProgressBar(value: pct / 100),
                    ],
                    const Spacer(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        BookStatusPill(book),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _meta(summary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.text3),
                          ),
                        ),
                        Text(
                          relativeDay(bl.bookLastTouch(book)),
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

  String _meta(bl.BookSummary s) {
    final parts = <String>[];
    if (s.totalPages > 0) parts.add('${s.totalPages} 页');
    if (s.totalMinutes > 0) parts.add(formatDuration(s.totalMinutes));
    if (parts.isEmpty) return '还没有记录';
    return parts.join(' · ');
  }
}
