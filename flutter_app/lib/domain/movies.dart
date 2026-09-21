import '../models/models.dart';

MovieStatus movieStatus(Movie movie) =>
    movie.watches.isEmpty ? MovieStatus.want : MovieStatus.watched;

String movieStatusLabel(Movie movie) => movie.watches.isEmpty
    ? '想看'
    : '已看${movie.watches.length}次';

/// 观影记录按时间倒序
List<WatchRecord> sortedWatches(Movie movie) {
  final list = [...movie.watches];
  list.sort((a, b) => b.at.compareTo(a.at));
  return list;
}

WatchRecord? lastWatch(Movie movie) {
  final list = sortedWatches(movie);
  return list.isEmpty ? null : list.first;
}

/// 最近一次观看时间
DateTime movieLastTouch(Movie movie) => lastWatch(movie)?.at ?? movie.createdAt;
