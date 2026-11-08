import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/domain/period_review.dart';
import 'package:shuying/domain/year_review.dart';
import 'package:shuying/models/models.dart';

void main() {
  Book bookWith(List<ReadingRound> rounds, {int? rating}) => Book(
      id: 'book',
      title: '重读的书',
      totalPages: 200,
      rating: rating,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2026),
      rounds: rounds);

  test('任选日期含末日整天，累计校正和单次量各自只计入一次', () {
    final book = bookWith([
      ReadingRound(
          id: 'round',
          index: 1,
          startedAt: DateTime(2025, 12, 31),
          finishedAt: DateTime(2026, 1, 1, 23, 59, 59),
          pages: 100,
          logs: [
            ReadingLog(
                id: 'a',
                at: DateTime(2025, 12, 31, 22),
                pages: 20,
                minutes: 30),
            ReadingLog(
                id: 'b',
                at: DateTime(2026, 1, 1, 23, 59, 59),
                pages: 40,
                minutes: 50),
          ]),
    ]);
    final movie = Movie(
        id: 'movie',
        title: '电影',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2026),
        watches: [
          WatchRecord(
              id: 'one', at: DateTime(2026, 1, 1, 23, 59, 59), rating: 8),
          WatchRecord(id: 'two', at: DateTime(2026, 1, 2), rating: 10),
        ]);
    final lastYear = PeriodReview([book], [movie],
        start: DateTime(2025, 12, 31), end: DateTime(2025, 12, 31));
    expect(lastYear.pages, 0);
    expect(lastYear.minutes, 30);
    final firstDay = PeriodReview([book], [movie],
        start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 1));
    expect(firstDay.pages, 100);
    expect(firstDay.minutes, 50);
    expect(firstDay.readTimes, 1);
    expect(firstDay.watchTimes, 1);
    expect(firstDay.averageRating, 8);
    final all = PeriodReview([book], [movie],
        start: DateTime(2025), end: DateTime(2026, 12, 31));
    expect(all.pages, 100);
    expect(all.minutes, 80);
    expect(all.readingDays, 2);
    expect(all.movieCount, 1);
    expect(all.watchTimes, 2);
    expect(YearReview([book], [movie], 2026).pages, firstDay.pages);
    expect(YearReview([book], [movie], 2026, month: 1).minutes, 50);
  });

  test('跨年相同月日属于不同阅读天，未评分不变成零分', () {
    final book = bookWith([
      ReadingRound(id: 'round', index: 1, startedAt: DateTime(2025), logs: [
        ReadingLog(id: 'a', at: DateTime(2025, 1, 1), minutes: 10),
        ReadingLog(id: 'b', at: DateTime(2026, 1, 1), minutes: 20),
      ]),
    ]);
    final review = PeriodReview([book], [],
        start: DateTime(2025), end: DateTime(2026, 12, 31));
    expect(review.readingDays, 2);
    expect(review.averageRating, isNull);
    expect(review.bookCount, 1);
    expect(
        () => PeriodReview([], [], start: DateTime(2026), end: DateTime(2025)),
        throwsArgumentError);
    expect(() => YearReview([], [], 2026, month: 13), throwsArgumentError);
  });

  test('轮次对照只给当前轮次进度，历史校正独立且不伪造逐轮评分', () {
    final book = bookWith([
      ReadingRound(
          id: 'past',
          index: 1,
          startedAt: DateTime(2025),
          finishedAt: DateTime(2025, 2),
          pages: 80,
          minutes: 10,
          logs: [
            ReadingLog(
                id: 'old',
                at: DateTime(2025, 1, 2),
                pages: 200,
                minutes: 90,
                progress: 100,
                note: '早年的感想')
          ]),
      ReadingRound(id: 'current', index: 2, startedAt: DateTime(2026), logs: [
        ReadingLog(
            id: 'new',
            at: DateTime(2026, 1, 2),
            pages: 60,
            minutes: 30,
            progress: 30,
            note: '重读有了新感想')
      ]),
    ], rating: 9);
    final entries = bookRevisits(book);
    expect(entries.map((entry) => entry.number), [2, 1]);
    expect(entries.first.progress, 30);
    expect(entries.last.progress, isNull);
    expect(entries.last.pages, 80);
    expect(entries.last.minutes, 10);
    expect(entries.last.note, '早年的感想');
    expect(entries.every((entry) => entry.rating == null), isTrue);
    final timeOnly = bookWith([
      ReadingRound(id: 'time-only', index: 1, startedAt: DateTime(2026), logs: [
        ReadingLog(id: 'minutes', at: DateTime(2026, 1, 2), minutes: 30),
      ]),
    ]);
    expect(bookRevisits(timeOnly).single.progress, isNull);
  });

  test('观影对照按实际时间倒序并保留每次真实评分与感想', () {
    final movie = Movie(
        id: 'movie',
        title: '重看的电影',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2026),
        watches: [
          WatchRecord(id: 'new', at: DateTime(2026), rating: 10, note: '现在的理解'),
          WatchRecord(id: 'old', at: DateTime(2025), rating: 6, note: '以前的理解'),
        ]);
    final entries = movieRevisits(movie);
    expect(entries.map((entry) => entry.number), [2, 1]);
    expect(entries.map((entry) => entry.rating), [10, 6]);
    expect(entries.first.note, '现在的理解');
    expect(latestReviewDate([], [movie]), DateTime(2026));
  });

  test('空库的显式年度样例总数与每月趋势一致', () {
    final review =
        YearReview(sampleReviewBooks(2026), sampleReviewMovies(2026), 2026);
    expect(review.minutes,
        review.monthlyMinutes.fold<int>(0, (sum, value) => sum + value));
    expect(review.watchTimes,
        review.monthlyWatches.fold<int>(0, (sum, value) => sum + value));
    expect(review.pages, 300);
    expect(review.averageRating, 9);
  });
}
