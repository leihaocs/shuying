import 'dart:math' as math;

/// 生成短 ID，prefix 用于区分实体类型（bk_ / rd_ / lg_ / mv_ / wt_）。
String uid([String prefix = '']) {
  final rand = math.Random();
  final a = rand.nextInt(1 << 30).toRadixString(36).padLeft(6, '0');
  final b = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return '$prefix${a.substring(0, 6)}$b';
}

/// copyWith 用的哨兵，用于区分「没传这个参数」和「显式传 null」。
const Object kUnset = Object();

int? checkedRating(int? rating) {
  if (rating != null && (rating < 1 || rating > 10)) {
    throw RangeError.range(rating, 1, 10, 'rating');
  }
  return rating;
}

DateTime _parseDate(dynamic v) {
  if (v is! String) return DateTime.now();
  return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
}

/// 新备份使用 UTC，跨时区迁移后按目标设备本地时间显示。
String isoOf(DateTime d) => d.toUtc().toIso8601String();

/* ------------------------------------------------------------------ */
/* 书籍                                                               */
/* ------------------------------------------------------------------ */

/// 一次阅读记录（某天读了多少页 / 多久 / 读完后的总进度）。
class ReadingLog {
  const ReadingLog({
    required this.id,
    required this.at,
    this.pages,
    this.minutes,
    this.progress,
    this.note,
  });

  final String id;

  /// 记录时间
  final DateTime at;

  /// 本次读了多少页
  final int? pages;

  /// 本次读了多久（分钟）
  final int? minutes;

  /// 本次结束后的总进度（0-100）
  final int? progress;

  /// 备注
  final String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': isoOf(at),
        if (pages != null) 'pages': pages,
        if (minutes != null) 'minutes': minutes,
        if (progress != null) 'progress': progress,
        if (note != null) 'note': note,
      };

  factory ReadingLog.fromJson(Map<String, dynamic> j) => ReadingLog(
        id: (j['id'] ?? uid('lg_')) as String,
        at: _parseDate(j['at']),
        pages: (j['pages'] as num?)?.toInt(),
        minutes: (j['minutes'] as num?)?.toInt(),
        progress: (j['progress'] as num?)?.toInt(),
        note: j['note'] as String?,
      );
}

/// 一轮阅读：从开始读一本书，到读完为止。同一本书可以有多轮 = 多次阅读。
class ReadingRound {
  const ReadingRound({
    required this.id,
    required this.index,
    required this.startedAt,
    this.finishedAt,
    this.note,
    this.pages,
    this.minutes,
    this.logs = const <ReadingLog>[],
  });

  final String id;

  /// 第几次阅读，从 1 开始
  final int index;

  final DateTime startedAt;

  /// null 表示这一轮还没读完
  final DateTime? finishedAt;
  final String? note;

  /// 本轮累计校正值（不是单次阅读量）；未填写时按已有明细汇总。
  final int? pages;
  final int? minutes;

  final List<ReadingLog> logs;

  bool get isActive => finishedAt == null;

  ReadingRound copyWith({
    String? id,
    int? index,
    DateTime? startedAt,
    Object? finishedAt = kUnset,
    Object? note = kUnset,
    Object? pages = kUnset,
    Object? minutes = kUnset,
    List<ReadingLog>? logs,
  }) =>
      ReadingRound(
        id: id ?? this.id,
        index: index ?? this.index,
        startedAt: startedAt ?? this.startedAt,
        finishedAt: identical(finishedAt, kUnset)
            ? this.finishedAt
            : finishedAt as DateTime?,
        note: identical(note, kUnset) ? this.note : note as String?,
        pages: identical(pages, kUnset) ? this.pages : pages as int?,
        minutes: identical(minutes, kUnset) ? this.minutes : minutes as int?,
        logs: logs ?? this.logs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'index': index,
        'startedAt': isoOf(startedAt),
        if (finishedAt != null) 'finishedAt': isoOf(finishedAt!),
        if (note != null) 'note': note,
        if (pages != null) 'pages': pages,
        if (minutes != null) 'minutes': minutes,
        'logs': logs.map((l) => l.toJson()).toList(),
      };

  factory ReadingRound.fromJson(Map<String, dynamic> j) => ReadingRound(
        id: (j['id'] ?? uid('rd_')) as String,
        index: (j['index'] as num?)?.toInt() ?? 1,
        startedAt: _parseDate(j['startedAt']),
        finishedAt:
            j['finishedAt'] == null ? null : _parseDate(j['finishedAt']),
        note: j['note'] as String?,
        pages: (j['pages'] as num?)?.toInt(),
        minutes: (j['minutes'] as num?)?.toInt(),
        logs: ((j['logs'] as List<dynamic>?) ?? const [])
            .map((e) => ReadingLog.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class Book {
  const Book({
    required this.id,
    required this.title,
    this.author = '',
    this.edition,
    this.totalPages,
    this.cover = '📖',
    this.accent = 0xFFB4552D,
    this.note,
    this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.rounds = const <ReadingRound>[],
  });

  final String id;
  final String title;
  final String author;

  /// 选填：出版社或版本说明。
  final String? edition;

  /// 选填：总页数
  final int? totalPages;

  /// 封面 emoji
  final String cover;

  /// 主题色（ARGB）
  final int accent;

  /// 全书评分，1～10 分；null 表示未评分。
  final int? rating;

  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ReadingRound> rounds;

  Book copyWith({
    String? id,
    String? title,
    String? author,
    Object? edition = kUnset,
    Object? totalPages = kUnset,
    String? cover,
    int? accent,
    Object? rating = kUnset,
    Object? note = kUnset,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ReadingRound>? rounds,
  }) =>
      Book(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        edition: identical(edition, kUnset) ? this.edition : edition as String?,
        totalPages: identical(totalPages, kUnset)
            ? this.totalPages
            : totalPages as int?,
        cover: cover ?? this.cover,
        accent: accent ?? this.accent,
        rating: identical(rating, kUnset) ? this.rating : rating as int?,
        note: identical(note, kUnset) ? this.note : note as String?,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        rounds: rounds ?? this.rounds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        if (edition != null) 'edition': edition,
        if (totalPages != null) 'totalPages': totalPages,
        'cover': cover,
        'accent': accent,
        if (rating != null) 'rating': rating,
        if (note != null) 'note': note,
        'createdAt': isoOf(createdAt),
        'updatedAt': isoOf(updatedAt),
        'rounds': rounds.map((r) => r.toJson()).toList(),
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: (j['id'] ?? uid('bk_')) as String,
        title: (j['title'] ?? '') as String,
        author: (j['author'] ?? '') as String,
        edition: j['edition'] as String?,
        totalPages: (j['totalPages'] as num?)?.toInt(),
        cover: (j['cover'] as String?) ?? '📖',
        accent: (j['accent'] as num?)?.toInt() ?? 0xFFB4552D,
        rating: (j['rating'] as num?)?.toInt(),
        note: j['note'] as String?,
        createdAt: _parseDate(j['createdAt']),
        updatedAt: _parseDate(j['updatedAt']),
        rounds: ((j['rounds'] as List<dynamic>?) ?? const [])
            .map((e) =>
                ReadingRound.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

enum BookStatus { want, reading, rereading, finished }

/* ------------------------------------------------------------------ */
/* 电影                                                               */
/* ------------------------------------------------------------------ */

/// 一次观影记录。
class WatchRecord {
  const WatchRecord({
    required this.id,
    required this.at,
    this.rating,
    this.note,
  });

  final String id;

  /// 观看时间
  final DateTime at;

  /// 1～10 分；旧五星记录读取时按比例转换。
  final int? rating;

  final String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': isoOf(at),
        if (rating != null) 'rating': rating,
        if (rating != null) 'ratingScale': 10,
        if (note != null) 'note': note,
      };

  factory WatchRecord.fromJson(Map<String, dynamic> j) => WatchRecord(
        id: (j['id'] ?? uid('wt_')) as String,
        at: _parseDate(j['at']),
        rating: j['rating'] == null
            ? null
            : (j['rating'] as num).toInt() * (j['ratingScale'] == 10 ? 1 : 2),
        note: j['note'] as String?,
      );
}

class Movie {
  const Movie({
    required this.id,
    required this.title,
    this.director = '',
    this.year,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.watches = const <WatchRecord>[],
  });

  final String id;
  final String title;
  final String director;
  final String? year;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WatchRecord> watches;

  Movie copyWith({
    String? id,
    String? title,
    String? director,
    Object? year = kUnset,
    Object? note = kUnset,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<WatchRecord>? watches,
  }) =>
      Movie(
        id: id ?? this.id,
        title: title ?? this.title,
        director: director ?? this.director,
        year: identical(year, kUnset) ? this.year : year as String?,
        note: identical(note, kUnset) ? this.note : note as String?,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        watches: watches ?? this.watches,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'director': director,
        if (year != null) 'year': year,
        if (note != null) 'note': note,
        'createdAt': isoOf(createdAt),
        'updatedAt': isoOf(updatedAt),
        'watches': watches.map((w) => w.toJson()).toList(),
      };

  factory Movie.fromJson(Map<String, dynamic> j) => Movie(
        id: (j['id'] ?? uid('mv_')) as String,
        title: (j['title'] ?? '') as String,
        director: (j['director'] ?? '') as String,
        year: j['year'] as String?,
        note: j['note'] as String?,
        createdAt: _parseDate(j['createdAt']),
        updatedAt: _parseDate(j['updatedAt']),
        watches: ((j['watches'] as List<dynamic>?) ?? const [])
            .map(
                (e) => WatchRecord.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

enum MovieStatus { want, watched, rewatched }
