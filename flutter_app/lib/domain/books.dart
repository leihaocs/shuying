import '../models/models.dart';
import 'fmt.dart';

/// 当前正在进行、尚未读完的一轮阅读
ReadingRound? activeRound(Book book) {
  for (final r in book.rounds) {
    if (r.isActive) return r;
  }
  return null;
}

/// 已读完的轮次，按完成时间倒序
List<ReadingRound> finishedRounds(Book book) {
  final list = book.rounds.where((r) => r.finishedAt != null).toList();
  list.sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));
  return list;
}

/// 全部轮次，按第几次阅读正序
List<ReadingRound> allRounds(Book book) {
  final list = [...book.rounds];
  list.sort((a, b) => a.index.compareTo(b.index));
  return list;
}

/// 书籍状态推导
/// - 没有任何轮次          -> 想读
/// - 有未读完的第 1 轮      -> 在读
/// - 有未读完的第 N 轮(N>1) -> 再次阅读
/// - 所有轮次都已读完       -> 已读N次
BookStatus bookStatus(Book book) {
  final active = activeRound(book);
  if (active != null) {
    return active.index <= 1 ? BookStatus.reading : BookStatus.rereading;
  }
  return book.rounds.isEmpty ? BookStatus.want : BookStatus.finished;
}

String statusLabel(Book book) => switch (bookStatus(book)) {
      BookStatus.want => '想读',
      BookStatus.reading => '在读',
      BookStatus.rereading => '再次阅读',
      BookStatus.finished => '已读${book.rounds.length}次',
    };

int roundPages(ReadingRound round) =>
    round.logs.fold(0, (sum, l) => sum + (l.pages ?? 0));

int roundMinutes(ReadingRound round) =>
    round.logs.fold(0, (sum, l) => sum + (l.minutes ?? 0));

int roundLogCount(ReadingRound round) => round.logs.length;

/// 阅读记录按时间倒序
List<ReadingLog> sortedLogs(ReadingRound round) {
  final list = [...round.logs];
  list.sort((a, b) => b.at.compareTo(a.at));
  return list;
}

/// 当前进度：优先取最近一次显式填写的进度，否则按页数估算。
int roundProgress(Book book, ReadingRound? round) {
  if (round == null) return 0;
  for (final l in sortedLogs(round)) {
    if (l.progress != null) return clampInt(l.progress!, 0, 100);
  }
  final total = book.totalPages;
  if (total != null && total > 0) {
    return clampInt(roundPages(round) / total * 100, 0, 100);
  }
  return 0;
}

class BookSummary {
  const BookSummary({
    required this.readTimes,
    required this.totalPages,
    required this.totalMinutes,
    required this.totalLogs,
    this.lastLogAt,
    this.lastFinishedAt,
  });

  final int readTimes;
  final int totalPages;
  final int totalMinutes;
  final int totalLogs;
  final DateTime? lastLogAt;
  final DateTime? lastFinishedAt;
}

/// 全书汇总
BookSummary bookSummary(Book book) {
  var totalPages = 0;
  var totalMinutes = 0;
  var totalLogs = 0;
  DateTime? lastLogAt;

  for (final r in book.rounds) {
    totalPages += roundPages(r);
    totalMinutes += roundMinutes(r);
    totalLogs += r.logs.length;
    for (final l in r.logs) {
      if (lastLogAt == null || l.at.isAfter(lastLogAt)) lastLogAt = l.at;
    }
  }

  final done = finishedRounds(book);
  return BookSummary(
    readTimes: done.length,
    totalPages: totalPages,
    totalMinutes: totalMinutes,
    totalLogs: totalLogs,
    lastLogAt: lastLogAt,
    lastFinishedAt: done.isEmpty ? null : done.first.finishedAt,
  );
}

/// 最近一次接触这本书的时间（用于排序）
DateTime bookLastTouch(Book book) {
  DateTime? last;
  for (final r in book.rounds) {
    if (r.finishedAt != null &&
        (last == null || r.finishedAt!.isAfter(last))) {
      last = r.finishedAt;
    }
    for (final l in r.logs) {
      if (last == null || l.at.isAfter(last)) last = l.at;
    }
  }
  return last ?? book.createdAt;
}
