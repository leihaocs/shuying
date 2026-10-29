import '../models/models.dart';

MovieStatus movieStatus(Movie movie) => movie.watches.isEmpty
    ? MovieStatus.want
    : movie.watches.length == 1
        ? MovieStatus.watched
        : MovieStatus.rewatched;

String movieStatusLabel(Movie movie) => movie.watches.isEmpty
    ? '想看'
    : movie.watches.length == 1
        ? '已看1次'
        : '多次观看 · ${movie.watches.length}次';

/// 观影记录按时间倒序
List<WatchRecord> sortedWatches(Movie movie) {
  final entries = movie.watches.asMap().entries.toList()
    ..sort((a, b) {
      final date = b.value.at.compareTo(a.value.at);
      return date != 0 ? date : b.key.compareTo(a.key);
    });
  return entries.map((entry) => entry.value).toList();
}

WatchRecord? lastWatch(Movie movie) {
  final list = sortedWatches(movie);
  return list.isEmpty ? null : list.first;
}

/// 最近一次观看时间
DateTime movieLastTouch(Movie movie) => lastWatch(movie)?.at ?? movie.createdAt;
