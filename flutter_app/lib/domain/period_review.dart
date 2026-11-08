import '../models/models.dart';
import 'books.dart' as books;
import 'movies.dart' as movies;

/// 按设备本地日历日汇总，起止日期均包含；累计校正与单次明细不重复计入。
class PeriodReview {
  PeriodReview(List<Book> bookList, List<Movie> movieList,
      {required DateTime start, required DateTime end})
      : start = DateTime(start.year, start.month, start.day),
        end = DateTime(end.year, end.month, end.day) {
    if (this.end.isBefore(this.start)) {
      throw ArgumentError('结束日期不能早于开始日期');
    }
    final until = DateTime(this.end.year, this.end.month, this.end.day + 1);
    bool contains(DateTime? at) =>
        at != null && !at.isBefore(this.start) && at.isBefore(until);
    final days = <String>{};
    for (final book in bookList) {
      var touched = false;
      for (final round in book.rounds) {
        if (contains(round.startedAt)) touched = true;
        if (contains(round.finishedAt)) {
          readTimes++;
          touched = true;
        }
        final totalsAt = books.roundTotalsDate(round).toLocal();
        if (contains(totalsAt)) {
          pages += round.pages ?? 0;
          minutes += round.minutes ?? 0;
          monthlyMinutes[totalsAt.month - 1] += round.minutes ?? 0;
          if ((round.pages ?? 0) > 0 || (round.minutes ?? 0) > 0) {
            touched = true;
            if (round.logs.isEmpty) days.add(_dayKey(totalsAt));
          }
        }
        for (final log in round.logs.where((log) => contains(log.at))) {
          if (round.pages == null) pages += log.pages ?? 0;
          if (round.minutes == null) {
            minutes += log.minutes ?? 0;
            monthlyMinutes[log.at.toLocal().month - 1] += log.minutes ?? 0;
          }
          days.add(_dayKey(log.at));
          touched = true;
        }
      }
      if (touched) {
        bookCount++;
      }
    }
    readingDays = days.length;
    for (final movie in movieList) {
      final records = movie.watches.where((watch) => contains(watch.at));
      if (records.isNotEmpty) movieCount++;
      for (final watch in records) {
        watchTimes++;
        monthlyWatches[watch.at.toLocal().month - 1]++;
        if (watch.rating != null) {
          ratingTotal += watch.rating!;
          ratingCount++;
        }
      }
    }
  }

  final DateTime start;
  final DateTime end;
  int minutes = 0, pages = 0, readTimes = 0, readingDays = 0, bookCount = 0;
  int watchTimes = 0, movieCount = 0, ratingTotal = 0, ratingCount = 0;
  final monthlyMinutes = List<int>.filled(12, 0);
  final monthlyWatches = List<int>.filled(12, 0);
  double? get averageRating =>
      ratingCount == 0 ? null : ratingTotal / ratingCount;
}

String _dayKey(DateTime at) {
  final local = at.toLocal();
  return '${local.year}-${local.month}-${local.day}';
}

List<int> reviewYears(List<Book> bookList, List<Movie> movieList) => <int>{
      DateTime.now().year,
      for (final at in _reviewDates(bookList, movieList)) at.toLocal().year,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

DateTime? latestReviewDate(List<Book> bookList, List<Movie> movieList) {
  DateTime? latest;
  for (final at in _reviewDates(bookList, movieList)) {
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return latest?.toLocal();
}

Iterable<DateTime> _reviewDates(
    List<Book> bookList, List<Movie> movieList) sync* {
  for (final book in bookList) {
    for (final round in book.rounds) {
      yield round.startedAt;
      yield books.roundTotalsDate(round);
      for (final log in round.logs) {
        yield log.at;
      }
    }
  }
  for (final movie in movieList) {
    for (final watch in movie.watches) {
      yield watch.at;
    }
  }
}

class RevisitEntry {
  const RevisitEntry(
      {required this.number,
      required this.startedAt,
      this.finishedAt,
      this.pages,
      this.minutes,
      this.progress,
      this.rating,
      this.note = ''});
  final int number;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? pages, minutes, progress, rating;
  final String note;
}

List<RevisitEntry> bookRevisits(Book book) => [
      for (final round in books.allRounds(book))
        RevisitEntry(
            number: round.index,
            startedAt: round.startedAt,
            finishedAt: round.finishedAt,
            pages: books.roundPages(round),
            minutes: books.roundMinutes(round),
            progress: _activeProgress(book, round),
            note: books.roundReflection(round)),
    ];

int? _activeProgress(Book book, ReadingRound round) {
  if (!round.isActive) return null;
  int? latest;
  for (final value
      in books.readingProgresses(book, books.sortedLogs(round).reversed)) {
    if (value != null) latest = value;
  }
  return latest;
}

List<RevisitEntry> movieRevisits(Movie movie) {
  final records = movies.sortedWatches(movie);
  return [
    for (var i = 0; i < records.length; i++)
      RevisitEntry(
          number: records.length - i,
          startedAt: records[i].at,
          rating: records[i].rating,
          note: records[i].note ?? ''),
  ];
}

/// 仅用于没有任何阅读或观影记录时的显式预览，不写入 AppStore。
List<Book> sampleReviewBooks(int year) => [
      Book(
          id: 'review-example-book',
          title: '示例书籍',
          createdAt: DateTime(year, 1),
          updatedAt: DateTime(year, 3, 10),
          rounds: [
            ReadingRound(
                id: 'review-example-round',
                index: 1,
                startedAt: DateTime(year, 1, 5),
                finishedAt: DateTime(year, 3, 10),
                logs: [
                  ReadingLog(
                      id: 'example-log-1',
                      at: DateTime(year, 1, 5),
                      pages: 80,
                      minutes: 120),
                  ReadingLog(
                      id: 'example-log-2',
                      at: DateTime(year, 2, 8),
                      pages: 100,
                      minutes: 150),
                  ReadingLog(
                      id: 'example-log-3',
                      at: DateTime(year, 3, 10),
                      pages: 120,
                      minutes: 180),
                ]),
          ]),
    ];

List<Movie> sampleReviewMovies(int year) => [
      Movie(
          id: 'review-example-movie',
          title: '示例电影',
          createdAt: DateTime(year, 2),
          updatedAt: DateTime(year, 3, 10),
          watches: [
            WatchRecord(
                id: 'example-watch-1', at: DateTime(year, 2, 8), rating: 8),
            WatchRecord(
                id: 'example-watch-2', at: DateTime(year, 3, 10), rating: 10),
          ]),
    ];
