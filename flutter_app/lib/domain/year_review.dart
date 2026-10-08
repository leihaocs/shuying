import '../models/models.dart';

class YearReview {
  YearReview(List<Book> books, List<Movie> movies, int year) {
    final activeDays = <String>{};
    for (final book in books) {
      for (final round in book.rounds) {
        if (round.finishedAt?.year == year) readTimes++;
        for (final log in round.logs.where((l) => l.at.year == year)) {
          minutes += log.minutes ?? 0;
          pages += log.pages ?? 0;
          monthlyMinutes[log.at.month - 1] += log.minutes ?? 0;
          activeDays.add('${log.at.month}-${log.at.day}');
        }
      }
    }
    readingDays = activeDays.length;
    for (final movie in movies) {
      final watches = movie.watches.where((w) => w.at.year == year).toList();
      watchTimes += watches.length;
      if (watches.isNotEmpty) movieCount++;
      for (final watch in watches) {
        monthlyWatches[watch.at.month - 1]++;
        if (watch.rating != null) {
          ratingTotal += watch.rating!;
          ratingCount++;
        }
      }
    }
  }
  int minutes = 0, pages = 0, readTimes = 0, readingDays = 0;
  int watchTimes = 0, movieCount = 0, ratingTotal = 0, ratingCount = 0;
  final monthlyMinutes = List<int>.filled(12, 0);
  final monthlyWatches = List<int>.filled(12, 0);
  double? get averageRating =>
      ratingCount == 0 ? null : ratingTotal / ratingCount;
}
