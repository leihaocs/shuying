import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fmt.dart';
import '../models/models.dart';

/* ------------------------------------------------------------------ */
/* 输入类型                                                            */
/* ------------------------------------------------------------------ */

class BookInput {
  BookInput({
    required this.title,
    required this.author,
    this.totalPages,
    this.cover,
    this.accent,
    this.note,
  });

  final String title;
  final String author;
  final int? totalPages;
  final String? cover;
  final int? accent;
  final String? note;
}

class MovieInput {
  MovieInput({
    required this.title,
    required this.director,
    this.year,
    this.note,
  });

  final String title;
  final String director;
  final String? year;
  final String? note;
}

class LogInput {
  LogInput({
    required this.at,
    this.pages,
    this.minutes,
    this.progress,
    this.note,
  });

  final DateTime at;
  final int? pages;
  final int? minutes;
  final int? progress;
  final String? note;
}

class PastRoundInput {
  PastRoundInput({
    required this.startedAt,
    required this.finishedAt,
    this.pages,
    this.minutes,
    this.note,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final int? pages;
  final int? minutes;
  final String? note;
}

/* ------------------------------------------------------------------ */
/* Store                                                              */
/* ------------------------------------------------------------------ */

/// 全局状态 + 本地持久化。
///
/// 存储层被刻意收敛到 [load] / [_persist] 两个方法里，
/// 换成 sqflite、Hive 或鸿蒙专用存储时只需要改这两处。
class AppStore extends ChangeNotifier {
  static const String _kState = 'shuying.state.v1';
  static const String _kTheme = 'shuying.theme.v1';
  static const String _kPrivacy = 'shuying.privacy.v1';

  final List<Book> _books = <Book>[];
  final List<Movie> _movies = <Movie>[];

  late final List<Book> books = UnmodifiableListView<Book>(_books);
  late final List<Movie> movies = UnmodifiableListView<Movie>(_movies);

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  bool _privacyConsent = false;
  bool get privacyConsent => _privacyConsent;

  bool _ready = false;
  bool get ready => _ready;

  Timer? _saveTimer;

  /* ---------------- 读写 ---------------- */

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeRaw = prefs.getString(_kTheme);
      _themeMode =
          themeRaw == 'dark' ? ThemeMode.dark : ThemeMode.light;
      _privacyConsent = prefs.getBool(_kPrivacy) ?? false;

      final raw = prefs.getString(_kState);
      if (raw == null || raw.isEmpty) {
        _seed();
      } else {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _books
          ..clear()
          ..addAll(((map['books'] as List<dynamic>?) ?? const [])
              .map((e) => Book.fromJson((e as Map).cast<String, dynamic>())));
        _movies
          ..clear()
          ..addAll(((map['movies'] as List<dynamic>?) ?? const [])
              .map((e) => Movie.fromJson((e as Map).cast<String, dynamic>())));
      }
    } catch (_) {
      // 数据损坏时不要让 App 起不来
      _books.clear();
      _movies.clear();
    }
    _ready = true;
    notifyListeners();
  }

  /// 合并短时间内的多次写入，避免每敲一个字都落盘。
  void _schedulePersist() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), _persist);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kState,
        jsonEncode({
          'books': _books.map((b) => b.toJson()).toList(),
          'movies': _movies.map((m) => m.toJson()).toList(),
        }),
      );
      await prefs.setString(
        _kTheme,
        _themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
      await prefs.setBool(_kPrivacy, _privacyConsent);
    } catch (_) {
      // 存储不可用时忽略
    }
  }

  void _touch() {
    _schedulePersist();
    notifyListeners();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  /* ---------------- 主题 ---------------- */

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _touch();
  }

  /* ---------------- 隐私 ---------------- */

  /// 用户首次启动时点击「同意并继续」后调用，写入偏好并通知 UI 切换。
  void acceptPrivacy() {
    if (_privacyConsent) return;
    _privacyConsent = true;
    _touch();
  }

  /// 提供给「清空数据」或调试使用，重置同意标记后会再次进入首次启动引导。
  void resetPrivacyConsent() {
    if (!_privacyConsent) return;
    _privacyConsent = false;
    _touch();
  }

  /* ---------------- 通用 ---------------- */

  Book? bookById(String id) {
    for (final b in _books) {
      if (b.id == id) return b;
    }
    return null;
  }

  Movie? movieById(String id) {
    for (final m in _movies) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _patchBook(String id, Book Function(Book) fn) {
    final i = _books.indexWhere((b) => b.id == id);
    if (i < 0) return;
    _books[i] = fn(_books[i]).copyWith(updatedAt: DateTime.now());
    _touch();
  }

  void _patchMovie(String id, Movie Function(Movie) fn) {
    final i = _movies.indexWhere((m) => m.id == id);
    if (i < 0) return;
    _movies[i] = fn(_movies[i]).copyWith(updatedAt: DateTime.now());
    _touch();
  }

  /* ---------------- 书籍 ---------------- */

  Book addBook(BookInput input) {
    final now = DateTime.now();
    final book = Book(
      id: uid('bk_'),
      title: input.title.trim(),
      author: input.author.trim(),
      totalPages: input.totalPages,
      cover: input.cover ?? '📖',
      accent: input.accent ?? 0xFFB4552D,
      note: _nullIfBlank(input.note),
      createdAt: now,
      updatedAt: now,
    );
    _books.insert(0, book);
    _touch();
    return book;
  }

  void updateBook(String id, BookInput input) => _patchBook(
        id,
        (b) => b.copyWith(
          title: input.title.trim(),
          author: input.author.trim(),
          totalPages: input.totalPages,
          cover: input.cover ?? b.cover,
          accent: input.accent ?? b.accent,
          note: _nullIfBlank(input.note),
        ),
      );

  void removeBook(String id) {
    _books.removeWhere((b) => b.id == id);
    _touch();
  }

  /// 想读 -> 开始第一轮阅读（已有未完成轮次时不重复创建）
  void startReading(String bookId) => _patchBook(bookId, (b) {
        if (b.rounds.any((r) => r.isActive)) return b;
        return b.copyWith(
          rounds: [
            ...b.rounds,
            ReadingRound(
              id: uid('rd_'),
              index: b.rounds.length + 1,
              startedAt: DateTime.now(),
            ),
          ],
        );
      });

  void addLog(String bookId, String roundId, LogInput log) =>
      _patchBook(bookId, (b) {
        return b.copyWith(
          rounds: b.rounds
              .map((r) => r.id == roundId
                  ? r.copyWith(
                      logs: [
                        ...r.logs,
                        ReadingLog(
                          id: uid('lg_'),
                          at: log.at,
                          pages: log.pages,
                          minutes: log.minutes,
                          progress: log.progress,
                          note: _nullIfBlank(log.note),
                        ),
                      ],
                    )
                  : r)
              .toList(),
        );
      });

  void removeLog(String bookId, String logId) => _patchBook(
        bookId,
        (b) => b.copyWith(
          rounds: b.rounds
              .map((r) => r.copyWith(
                    logs: r.logs.where((l) => l.id != logId).toList(),
                  ))
              .toList(),
        ),
      );

  /// 标记读完当前这一轮
  void finishRound(String bookId, String roundId) => _patchBook(
        bookId,
        (b) => b.copyWith(
          rounds: b.rounds
              .map((r) => (r.id == roundId && r.isActive)
                  ? r.copyWith(finishedAt: DateTime.now())
                  : r)
              .toList(),
        ),
      );

  /// 补记往期已读（含起止时间）
  void addPastRound(String bookId, PastRoundInput input) =>
      _patchBook(bookId, (b) {
        final hasDetail = input.pages != null ||
            input.minutes != null ||
            (input.note != null && input.note!.trim().isNotEmpty);
        final logs = <ReadingLog>[
          if (hasDetail)
            ReadingLog(
              id: uid('lg_'),
              at: input.finishedAt,
              pages: input.pages,
              minutes: input.minutes,
              progress: 100,
              note: _nullIfBlank(input.note),
            ),
        ];
        return b.copyWith(
          rounds: [
            ...b.rounds,
            ReadingRound(
              id: uid('rd_'),
              index: b.rounds.length + 1,
              startedAt: input.startedAt,
              finishedAt: input.finishedAt,
              logs: logs,
            ),
          ],
        );
      });

  /// 删除某一轮，并重排 index
  void removeRound(String bookId, String roundId) => _patchBook(bookId, (b) {
        final kept = b.rounds.where((r) => r.id != roundId).toList();
        return b.copyWith(
          rounds: [
            for (var i = 0; i < kept.length; i++) kept[i].copyWith(index: i + 1),
          ],
        );
      });

  /* ---------------- 电影 ---------------- */

  Movie addMovie(MovieInput input) {
    final now = DateTime.now();
    final movie = Movie(
      id: uid('mv_'),
      title: input.title.trim(),
      director: input.director.trim(),
      year: _nullIfBlank(input.year),
      note: _nullIfBlank(input.note),
      createdAt: now,
      updatedAt: now,
    );
    _movies.insert(0, movie);
    _touch();
    return movie;
  }

  void updateMovie(String id, MovieInput input) => _patchMovie(
        id,
        (m) => m.copyWith(
          title: input.title.trim(),
          director: input.director.trim(),
          year: _nullIfBlank(input.year),
          note: _nullIfBlank(input.note),
        ),
      );

  void removeMovie(String id) {
    _movies.removeWhere((m) => m.id == id);
    _touch();
  }

  void addWatch(String movieId,
          {required DateTime at, int? rating, String? note}) =>
      _patchMovie(
        movieId,
        (m) => m.copyWith(
          watches: [
            ...m.watches,
            WatchRecord(
              id: uid('wt_'),
              at: at,
              rating: rating,
              note: _nullIfBlank(note),
            ),
          ],
        ),
      );

  void removeWatch(String movieId, String watchId) => _patchMovie(
        movieId,
        (m) => m.copyWith(
          watches: m.watches.where((w) => w.id != watchId).toList(),
        ),
      );

  /* ---------------- 示例数据 ---------------- */

  void _seed() {
    _books
      ..clear()
      ..addAll([
        Book(
          id: uid('bk_'),
          title: '活着',
          author: '余华',
          totalPages: 191,
          cover: '📕',
          accent: 0xFFB4552D,
          createdAt: atDayAgo(20, 10, 0),
          updatedAt: atDayAgo(1),
          rounds: [
            ReadingRound(
              id: uid('rd_'),
              index: 1,
              startedAt: atDayAgo(12),
              logs: [
                ReadingLog(
                  id: uid('lg_'),
                  at: atDayAgo(12),
                  pages: 46,
                  minutes: 52,
                  progress: 24,
                  note: '开篇就很抓人。',
                ),
                ReadingLog(
                  id: uid('lg_'),
                  at: atDayAgo(6),
                  pages: 58,
                  minutes: 61,
                  progress: 55,
                ),
                ReadingLog(
                  id: uid('lg_'),
                  at: atDayAgo(1),
                  pages: 41,
                  minutes: 45,
                  progress: 76,
                ),
              ],
            ),
          ],
        ),
        Book(
          id: uid('bk_'),
          title: '百年孤独',
          author: '加西亚·马尔克斯',
          totalPages: 360,
          cover: '📘',
          accent: 0xFF3A6EA5,
          createdAt: atDayAgo(9, 15, 20),
          updatedAt: atDayAgo(9, 15, 20),
        ),
      ]);

    _movies
      ..clear()
      ..add(
        Movie(
          id: uid('mv_'),
          title: '肖申克的救赎',
          director: '弗兰克·德拉邦特',
          year: '1994',
          createdAt: atDayAgo(30, 20, 0),
          updatedAt: atDayAgo(3, 20, 0),
          watches: [
            WatchRecord(
              id: uid('wt_'),
              at: atDayAgo(30, 20, 0),
              rating: 5,
              note: '希望是件好事，也许是世间最好的事。',
            ),
            WatchRecord(id: uid('wt_'), at: atDayAgo(3, 20, 0), rating: 5),
          ],
        ),
      );
  }

  /// 清空示例/全部数据
  void clearAll() {
    _books.clear();
    _movies.clear();
    _touch();
  }
}

String? _nullIfBlank(String? v) {
  final t = v?.trim();
  return (t == null || t.isEmpty) ? null : t;
}
