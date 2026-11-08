import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/domain/period_review.dart';
import 'package:shuying/models/models.dart';
import 'package:shuying/services/backup_codec.dart';
import 'dart:convert';

void main() {
  test('千本万笔记录汇总仍按校正累计计数，备份标签往返不丢失', () {
    final books = List<Book>.generate(
        1000,
        (i) => Book(
            id: 'book-$i',
            title: '规模记录$i',
            tags: ['读书'],
            createdAt: DateTime(2026, 1),
            updatedAt: DateTime(2026, 1, 31),
            rounds: [
              ReadingRound(
                id: 'round-$i',
                index: 1,
                startedAt: DateTime(2026, 1),
                finishedAt: DateTime(2026, 1, 31),
                pages: i.isEven ? 5 : null,
                logs: List<ReadingLog>.generate(
                    10,
                    (j) => ReadingLog(
                        id: 'log-$i-$j',
                        at: DateTime(2026, 1, j + 1),
                        pages: 1,
                        minutes: 2)),
              )
            ]));
    final raw = jsonEncode({
      'app': 'bookmovie_revisit',
      'schema': 3,
      'books': books.map((b) => b.toJson()).toList(),
      'movies': []
    });
    final loaded = decodeBackup(raw);
    final review = PeriodReview(loaded.books, loaded.movies,
        start: DateTime(2026, 1), end: DateTime(2026, 1, 31));
    expect(loaded.books, hasLength(1000));
    expect(loaded.books.last.tags, ['读书']);
    expect(review.readTimes, 1000);
    expect(review.pages, 7500);
    expect(review.minutes, 20000);
    expect(review.readingDays, 10);
  });

  test('UTC备份时间按设备本地日历归属，午夜前后不跨错月份', () {
    final local = DateTime(2026, 1, 1, 0, 15);
    final movie = Movie(
        id: 'm',
        title: '跨时区记录',
        createdAt: local,
        updatedAt: local,
        watches: [
          WatchRecord(
              id: 'before',
              at: local.subtract(const Duration(minutes: 30)),
              rating: 6),
          WatchRecord(id: 'after', at: local.toUtc(), rating: 10),
        ]);
    final backup = decodeBackup(jsonEncode({
      'app': 'bookmovie_revisit',
      'schema': 3,
      'books': [],
      'movies': [movie.toJson()]
    }));
    final january = PeriodReview([], backup.movies,
        start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 1));
    final december = PeriodReview([], backup.movies,
        start: DateTime(2025, 12, 31), end: DateTime(2025, 12, 31));
    expect(january.watchTimes, 1);
    expect(january.averageRating, 10);
    expect(december.watchTimes, 1);
    expect(december.averageRating, 6);
  });
}
