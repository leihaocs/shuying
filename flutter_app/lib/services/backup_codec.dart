import 'dart:convert';
import '../models/models.dart';
import '../domain/books.dart'
    show chronologicalRounds, readingProgresses, sortedLogs;

class BackupData {
  const BackupData(this.books, this.movies);
  final List<Book> books;
  final List<Movie> movies;
}

const maxBackupBytes = 20 * 1024 * 1024;

class BackupTooLargeException extends FormatException {
  const BackupTooLargeException() : super('备份超过 20 MB，请先确认大文件导入；原数据未修改');
}

enum BackupConflictResolution { keepLocal, useIncoming }

class BackupBookConflict {
  const BackupBookConflict(this.local, this.incoming, this.reason);
  final Book? local;
  final Book incoming;
  final String reason;
  String get bookId => incoming.id;
}

class BackupConflictException extends FormatException {
  BackupConflictException(List<BackupBookConflict> conflicts)
      : conflicts = List.unmodifiable(conflicts),
        super(conflicts.map((conflict) => conflict.reason).join('\n'));
  final List<BackupBookConflict> conflicts;
}

BackupData decodeBackup(String text,
    {bool legacy = false, bool allowLarge = false}) {
  // 外部文件限制不能阻止应用重新读取自己已成功保存的本机记录。
  if (!legacy && !allowLarge && utf8.encode(text).length > maxBackupBytes) {
    throw const BackupTooLargeException();
  }
  final value = jsonDecode(text.replaceFirst(RegExp(r'^\uFEFF'), ''));
  if (value is! Map<String, dynamic>) {
    throw const FormatException('备份必须是 JSON 对象');
  }
  if (!legacy &&
      (value['app'] != 'bookmovie_revisit' ||
          (value['schema'] != 1 &&
              value['schema'] != 2 &&
              value['schema'] != 3))) {
    throw const FormatException('不是书影温故备份，或备份版本暂不支持');
  }
  final books = _items(value['books']);
  final movies = _items(value['movies']);
  for (final book in books) {
    _entity(book, 'author');
    _number(book, 'totalPages', 0);
    _number(book, 'accent', 0, max: 0xffffffff);
    _string(book, 'cover');
    _string(book, 'edition');
    _number(book, 'rating', 1, max: 10);
    final rounds = _items(book['rounds']);
    for (final round in rounds) {
      _id(round);
      _number(round, 'index', 1);
      _date(round, 'startedAt');
      _date(round, 'finishedAt', optional: true);
      _string(round, 'note');
      _number(round, 'pages', 0);
      _number(round, 'minutes', 0);
      for (final log in _items(round['logs'])) {
        _id(log);
        _date(log, 'at');
        _number(log, 'pages', 0);
        _number(log, 'minutes', 0);
        _number(log, 'progress', 0, max: 100);
        _string(log, 'note');
      }
    }
  }
  for (final movie in movies) {
    _entity(movie, 'director');
    _string(movie, 'year');
    for (final watch in _items(movie['watches'])) {
      _id(watch);
      _date(watch, 'at');
      if (watch['ratingScale'] != null &&
          watch['ratingScale'] != 5 &&
          watch['ratingScale'] != 10) {
        throw const FormatException('评分制式暂不支持');
      }
      _number(watch, 'rating', 1, max: watch['ratingScale'] == 10 ? 10 : 5);
      _string(watch, 'note');
    }
  }
  // 全部校验和解析完成后，调用方才允许修改本机记录。
  return BackupData(
      books.map((json) {
        final book = Book.fromJson(json);
        return book.copyWith(rounds: chronologicalRounds(book.rounds));
      }).toList(),
      movies.map(Movie.fromJson).toList());
}

List<Map<String, dynamic>> _items(dynamic value) {
  if (value is! List) throw const FormatException('记录列表缺失或格式错误');
  final result = <Map<String, dynamic>>[];
  final ids = <String>{};
  for (final item in value) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('列表中存在无效记录');
    }
    _id(item);
    if (!ids.add(item['id'] as String)) {
      throw const FormatException('备份中有重复 ID');
    }
    result.add(item);
  }
  return result;
}

void _id(Map<String, dynamic> value) {
  if (value['id'] is! String || (value['id'] as String).trim().isEmpty) {
    throw const FormatException('记录缺少稳定 ID');
  }
}

void _entity(Map<String, dynamic> value, String creator) {
  if (value['title'] is! String ||
      (value['title'] as String).trim().isEmpty ||
      (value[creator] != null && value[creator] is! String)) {
    throw const FormatException('标题或作者信息格式错误');
  }
  _date(value, 'createdAt');
  _date(value, 'updatedAt');
  _string(value, 'note');
  final tags = value['tags'];
  if (tags != null && (tags is! List || tags.any((tag) => tag is! String))) {
    throw const FormatException('标签必须是文本列表');
  }
}

void _date(Map<String, dynamic> value, String key, {bool optional = false}) {
  final raw = value[key];
  if (optional && raw == null) return;
  if (raw is! String || DateTime.tryParse(raw) == null) {
    throw FormatException('$key 日期无效');
  }
}

void _number(Map<String, dynamic> value, String key, int min, {int? max}) {
  final raw = value[key];
  if (raw == null) return;
  if (raw is! num ||
      !raw.isFinite ||
      raw != raw.toInt() ||
      raw < min ||
      (max != null && raw > max)) {
    throw FormatException('$key 数值无效');
  }
}

void _string(Map<String, dynamic> value, String key) {
  if (value[key] != null && value[key] is! String) {
    throw FormatException('$key 必须是文本');
  }
}

BackupData mergeBackup(
    List<Book> books, List<Movie> movies, BackupData incoming,
    {Map<String, BackupConflictResolution> resolutions = const {}}) {
  final mergedBooks = {for (final b in books) b.id: b};
  final conflicts = <BackupBookConflict>[];
  for (final b in incoming.books) {
    final local = mergedBooks[b.id];
    try {
      mergedBooks[b.id] = _mergeBook(local, b);
    } on FormatException catch (error) {
      final resolution = resolutions[b.id];
      if (resolution == BackupConflictResolution.keepLocal) continue;
      if (resolution == BackupConflictResolution.useIncoming) {
        try {
          // 整书选择来源也不能放行来源自身已损坏的阅读规则。
          _validateMergedBook(b);
          mergedBooks[b.id] = b;
          continue;
        } on FormatException catch (sourceError) {
          conflicts.add(BackupBookConflict(local, b, sourceError.message));
          continue;
        }
      }
      conflicts.add(BackupBookConflict(local, b, error.message));
    }
  }
  if (conflicts.isNotEmpty) throw BackupConflictException(conflicts);
  final mergedMovies = {for (final m in movies) m.id: m};
  for (final m in incoming.movies) {
    final local = mergedMovies[m.id];
    if (local == null) {
      mergedMovies[m.id] = m;
    } else {
      final newer = m.updatedAt.isAfter(local.updatedAt);
      mergedMovies[m.id] = (newer ? m : local).copyWith(
        watches: _union(local.watches, m.watches, (w) => w.id, newer),
      );
    }
  }
  return BackupData(mergedBooks.values.toList(), mergedMovies.values.toList());
}

Book _mergeBook(Book? local, Book b) {
  if (local == null) {
    _validateMergedBook(b);
    return b;
  }
  final incomingNewer = b.updatedAt.isAfter(local.updatedAt);
  final rounds = {for (final r in local.rounds) r.id: r};
  for (final r in b.rounds) {
    final old = rounds[r.id];
    if (old == null) {
      rounds[r.id] = r;
    } else {
      final base = incomingNewer ? r : old;
      final logs = _union(old.logs, r.logs, (l) => l.id, incomingNewer);
      final baseIds = base.logs.map((log) => log.id).toSet();
      final added = logs.where((log) => !baseIds.contains(log.id));
      // 校正累计不一定等于明细之和；缺少共同基线时不能猜测或直接相加。
      if ((base.pages != null && added.any((log) => (log.pages ?? 0) != 0)) ||
          (base.minutes != null &&
              added.any((log) => (log.minutes ?? 0) != 0))) {
        _conflict(b, '同一轮阅读的累计校正与另一端新增记录冲突');
      }
      rounds[r.id] = base.copyWith(
        // 完成状态不能被旧备份重新打开；新增日志不因元数据冲突被丢弃。
        finishedAt: base.finishedAt ?? old.finishedAt ?? r.finishedAt,
        logs: logs,
      );
    }
  }
  final merged = (incomingNewer ? b : local).copyWith(
    rounds: chronologicalRounds(rounds.values),
  );
  _validateMergedBook(merged);
  return merged;
}

void _validateMergedBook(Book book) {
  if (book.rounds.where((round) => round.isActive).length > 1) {
    _conflict(book, '合并后出现多轮未完成阅读');
  }
  for (final round in book.rounds) {
    final end = round.finishedAt;
    if (end != null &&
        (end.isBefore(round.startedAt) ||
            round.logs.any((log) =>
                log.at.isBefore(round.startedAt) || log.at.isAfter(end)))) {
      _conflict(book, '历史轮次的起止时间未包含全部阅读记录');
    }
    if (!round.isActive) continue;
    int? previous;
    for (final progress
        in readingProgresses(book, sortedLogs(round).reversed)) {
      if (progress == null) continue;
      if (previous != null && progress < previous) {
        _conflict(book, '合并后阅读进度倒退');
      }
      previous = progress;
    }
  }
}

Never _conflict(Book book, String reason) =>
    throw FormatException('《${book.title}》$reason，本机记录未修改。请先在来源设备核对、调整后再导入。');

List<T> _union<T>(List<T> local, List<T> incoming, String Function(T) id,
    bool incomingNewer) {
  final result = {for (final item in local) id(item): item};
  for (final item in incoming) {
    if (incomingNewer || !result.containsKey(id(item))) result[id(item)] = item;
  }
  return result.values.toList();
}
