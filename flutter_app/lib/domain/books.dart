import '../models/models.dart';
import 'fmt.dart';

/// 补记、删轮次及导入后统一按开始时间重排，从 1 编号。
List<ReadingRound> chronologicalRounds(Iterable<ReadingRound> rounds) {
  final ordered = rounds.toList()
    ..sort((a, b) {
      final date = a.startedAt.compareTo(b.startedAt);
      if (date != 0) return date;
      final index = a.index.compareTo(b.index);
      return index != 0 ? index : a.id.compareTo(b.id);
    });
  return [
    for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(index: i + 1)
  ];
}

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

/// 全部轮次倒序显示（最新一轮在最上面），编号仍从最早的第 1 轮开始。
/// 以开始时间为准，改过时间后顺序会跟着变。
List<ReadingRound> allRounds(Book book) {
  final list = [...book.rounds];
  list.sort((a, b) {
    final date = b.startedAt.compareTo(a.startedAt);
    if (date != 0) return date;
    final index = b.index.compareTo(a.index);
    return index != 0 ? index : b.id.compareTo(a.id);
  });
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

String statusLabel(Book book) {
  switch (bookStatus(book)) {
    case BookStatus.want:
      return '想读';
    case BookStatus.reading:
      return '在读';
    case BookStatus.rereading:
      return '再次阅读';
    case BookStatus.finished:
      return '已读${book.rounds.length}次';
  }
}

int roundPages(ReadingRound round) =>
    (!round.isActive ? round.pages : null) ??
    round.logs.fold(0, (sum, l) => sum + (l.pages ?? 0));

int roundMinutes(ReadingRound round) =>
    (!round.isActive ? round.minutes : null) ??
    round.logs.fold(0, (sum, l) => sum + (l.minutes ?? 0));

int roundLogCount(ReadingRound round) => round.logs.length;

/// 兼容旧轮次中保存在明细里的感想；显式保存空文本表示用户已清空。
String roundReflection(ReadingRound round) =>
    round.note ??
    sortedLogs(round)
        .map((log) => log.note?.trim() ?? '')
        .where((note) => note.isNotEmpty)
        .join('\n\n');

/// 阅读记录按时间倒序
List<ReadingLog> sortedLogs(ReadingRound round) {
  final entries = round.logs.asMap().entries.toList()
    ..sort((a, b) {
      final date = b.value.at.compareTo(a.value.at);
      return date != 0 ? date : b.key.compareTo(a.key);
    });
  return entries.map((entry) => entry.value).toList();
}

/// 按时间推导每一笔进度；自动页数从前一笔进度继续累加。
Iterable<int?> readingProgresses(Book book, Iterable<ReadingLog> logs) sync* {
  double? progress;
  for (final log in logs) {
    if (log.progress != null) {
      progress = log.progress!.toDouble();
    } else if ((book.totalPages ?? 0) > 0 && log.pages != null) {
      progress = (progress ?? 0) + log.pages! / book.totalPages! * 100;
    }
    yield progress == null ? null : clampInt(progress, 0, 100);
  }
}

/// 当前进度随最新记录变化，历史轮次不显示进度。
int roundProgress(Book book, ReadingRound? round) {
  if (round == null || !round.isActive) return 0;
  var progress = 0;
  for (final value in readingProgresses(book, sortedLogs(round).reversed)) {
    if (value != null) progress = value;
  }
  return progress;
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
    var touch = r.startedAt;
    final finished = r.finishedAt;
    if (finished != null && finished.isAfter(touch)) touch = finished;
    for (final l in r.logs) {
      if (l.at.isAfter(touch)) touch = l.at;
    }
    if (last == null || touch.isAfter(last)) last = touch;
  }
  return last ?? book.createdAt;
}
