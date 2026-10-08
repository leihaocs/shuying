import 'dart:convert';
import '../models/models.dart';

class BackupData {
  const BackupData(this.books, this.movies);
  final List<Book> books;
  final List<Movie> movies;
}

BackupData decodeBackup(String text, {bool legacy = false}) {
  if (utf8.encode(text).length > 20 * 1024 * 1024) {
    throw const FormatException('备份超过 20 MB，请拆分后导入');
  }
  final value = jsonDecode(text.replaceFirst(RegExp(r'^\uFEFF'), ''));
  if (value is! Map<String, dynamic>) {
    throw const FormatException('备份必须是 JSON 对象');
  }
  if (!legacy &&
      (value['app'] != 'bookmovie_revisit' || value['schema'] != 1)) {
    throw const FormatException('不是书影温故备份，或备份版本暂不支持');
  }
  final books = _items(value['books']);
  final movies = _items(value['movies']);
  for (final book in books) {
    _entity(book, 'author');
    _number(book, 'totalPages', 0);
    _number(book, 'accent', 0, max: 0xffffffff);
    _string(book, 'cover');
    final rounds = _items(book['rounds']);
    for (final round in rounds) {
      _id(round);
      _number(round, 'index', 1);
      _date(round, 'startedAt');
      _date(round, 'finishedAt', optional: true);
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
      _number(watch, 'rating', 1, max: 5);
      _string(watch, 'note');
    }
  }
  // 全部校验和解析完成后，调用方才允许修改本机记录。
  return BackupData(
      books.map(Book.fromJson).toList(), movies.map(Movie.fromJson).toList());
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
      value[creator] is! String) {
    throw const FormatException('标题或作者信息格式错误');
  }
  _date(value, 'createdAt');
  _date(value, 'updatedAt');
  _string(value, 'note');
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
    List<Book> books, List<Movie> movies, BackupData incoming) {
  final mergedBooks = {for (final b in books) b.id: b};
  for (final b in incoming.books) {
    final local = mergedBooks[b.id];
    if (local == null) {
      mergedBooks[b.id] = b;
      continue;
    }
    final incomingNewer = b.updatedAt.isAfter(local.updatedAt);
    final rounds = {for (final r in local.rounds) r.id: r};
    for (final r in b.rounds) {
      final old = rounds[r.id];
      if (old == null) {
        rounds[r.id] = r;
      } else {
        final base = incomingNewer ? r : old;
        rounds[r.id] = base.copyWith(
          // 完成状态不能被旧备份重新打开；新增日志不因元数据冲突被丢弃。
          finishedAt: base.finishedAt ?? old.finishedAt ?? r.finishedAt,
          logs: _union(old.logs, r.logs, (l) => l.id, incomingNewer),
        );
      }
    }
    final ordered = rounds.values.toList()
      ..sort((a, b) {
        final date = a.startedAt.compareTo(b.startedAt);
        return date != 0 ? date : a.id.compareTo(b.id);
      });
    mergedBooks[b.id] = (incomingNewer ? b : local).copyWith(
      rounds: [
        for (var i = 0; i < ordered.length; i++)
          ordered[i].copyWith(index: i + 1)
      ],
    );
  }
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

List<T> _union<T>(List<T> local, List<T> incoming, String Function(T) id,
    bool incomingNewer) {
  final result = {for (final item in local) id(item): item};
  for (final item in incoming) {
    if (incomingNewer || !result.containsKey(id(item))) result[id(item)] = item;
  }
  return result.values.toList();
}
