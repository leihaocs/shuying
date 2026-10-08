import 'dart:io';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fmt.dart';
import '../models/models.dart';
import '../services/backup_codec.dart';
import '../services/backup_files.dart';

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
/// 存储层被刻意收敛到 [load] / [flush] 两个方法里，
/// 换成 sqflite、Hive 或鸿蒙专用存储时只需要改这两处。
class AppStore extends ChangeNotifier with WidgetsBindingObserver {
  AppStore({this.dataDirectory}) {
    WidgetsBinding.instance.addObserver(this);
  }
  final String? dataDirectory;
  File? _stateFile;
  static const String _kState = 'shuying.state.v1';
  static const String _kTheme = 'shuying.theme.v1';
  static const String _kPrivacy = 'shuying.privacy.v1';
  static const String _kPrivacyVersion = 'shuying.privacy.version';
  static const String privacyVersion = '2026-10-02';

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

  Future<void> _saveQueue = Future<void>.value();
  SharedPreferences? _prefs;
  String? storageError;
  bool loadFailed = false;
  bool _disposed = false;
  int _savingJobs = 0;
  bool get saving => _savingJobs > 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _ready && !loadFailed) flush();
  }

  Future<bool> flush() async {
    if (loadFailed || !_ready) return false;
    _schedulePersist();
    await _saveQueue;
    return storageError == null;
  }

  /* ---------------- 读写 ---------------- */

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _themeMode = _prefs!.getString(_kTheme) == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;
      _privacyConsent = (_prefs!.getBool(_kPrivacy) ?? false) &&
          _prefs!.getString(_kPrivacyVersion) == privacyVersion;
      final directory = dataDirectory ??
          await BackupFiles.channel.invokeMethod<String>('storagePath');
      if (directory == null) throw StateError('本地存储目录不可用');
      await Directory(directory).create(recursive: true);
      _stateFile = File('$directory/state.v1.json');
      final raw = await _stateFile!.exists()
          ? await _stateFile!.readAsString()
          : _prefs!.getString(_kState);
      if (raw == null) {
        _seed();
      } else {
        final data = decodeBackup(raw, legacy: true);
        _books
          ..clear()
          ..addAll(data.books);
        _movies
          ..clear()
          ..addAll(data.movies);
      }
      loadFailed = false;
      storageError = null;
    } catch (_) {
      loadFailed = true;
      storageError = '本机记录读取失败，原数据已保留。请重试，勿卸载应用。';
    }
    _ready = true;
    notifyListeners();
    if (!loadFailed) _schedulePersist();
  }

  // 每次修改立即排队写入，不再等待 250ms；按顺序保存不可变快照。
  void _schedulePersist() {
    if (loadFailed || _prefs == null) return;
    final snapshot = jsonEncode({
      'books': _books.map((b) => b.toJson()).toList(),
      'movies': _movies.map((m) => m.toJson()).toList(),
    });
    final theme = _themeMode == ThemeMode.dark ? 'dark' : 'light';
    final consent = _privacyConsent;
    _savingJobs++;
    _saveQueue = _saveQueue.then((_) async {
      try {
        final file = _stateFile!;
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(snapshot, flush: true);
        if (await file.exists()) await file.copy('${file.path}.previous');
        await temporary.rename(file.path);
        if (!await _prefs!.setString(_kTheme, theme) ||
            !await _prefs!.setBool(_kPrivacy, consent) ||
            !await _prefs!
                .setString(_kPrivacyVersion, consent ? privacyVersion : '')) {
          throw StateError('保存失败');
        }
        storageError = null;
      } catch (_) {
        storageError = '记录尚未保存成功，请重试保存或立即导出备份，勿关闭应用。';
      }
      _savingJobs--;
      if (!_disposed) notifyListeners();
    });
  }

  void _touch() {
    if (loadFailed) throw StateError('读取失败时禁止覆盖本机数据');
    _schedulePersist();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    super.dispose();
  }

  /* ---------------- 备份 / 恢复 ---------------- */

  /// 导出全部记录为带缩进的 JSON 文本，用于手动备份（粘到备忘录、发到电脑等）。
  ///
  /// 三端共用同一个 JSON 协议，文件导出不包含购买权益。
  String exportJson() {
    final data = <String, dynamic>{
      'app': 'bookmovie_revisit',
      'schema': 1,
      'exportedAt': isoOf(DateTime.now()),
      'books': _books.map((b) => b.toJson()).toList(),
      'movies': _movies.map((m) => m.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 跨端合并：按稳定 ID 合并书籍、轮次、日志与观影记录，不传播删除。
  Map<String, int> importJson(String text) {
    if (loadFailed) throw StateError('请先解决本机读取错误');
    final incoming = decodeBackup(text);
    final merged = mergeBackup(_books, _movies, incoming);
    _books
      ..clear()
      ..addAll(merged.books);
    _movies
      ..clear()
      ..addAll(merged.movies);
    _touch();
    return {'books': incoming.books.length, 'movies': incoming.movies.length};
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
            for (var i = 0; i < kept.length; i++)
              kept[i].copyWith(index: i + 1),
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
