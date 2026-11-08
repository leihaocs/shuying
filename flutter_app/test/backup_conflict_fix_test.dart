import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuying/domain/books.dart';
import 'package:shuying/models/models.dart';
import 'package:shuying/services/backup_codec.dart';
import 'package:shuying/store/app_store.dart';

final _start = DateTime(2026, 1, 1);

ReadingLog _log(String id, int day,
        {int? pages, int? minutes, int? progress}) =>
    ReadingLog(
        id: id,
        at: DateTime(2026, 1, day),
        pages: pages,
        minutes: minutes,
        progress: progress);

ReadingRound _round(List<ReadingLog> logs,
        {int? pages, int? minutes, String id = 'r', DateTime? finishedAt}) =>
    ReadingRound(
        id: id,
        index: 1,
        startedAt: _start,
        finishedAt: finishedAt,
        pages: pages,
        minutes: minutes,
        logs: logs);

Book _book(List<ReadingRound> rounds, {int updatedDay = 1, int? totalPages}) =>
    Book(
        id: 'b',
        title: '共同阅读',
        createdAt: _start,
        updatedAt: DateTime(2026, 2, updatedDay),
        totalPages: totalPages,
        rounds: rounds);

String _backup(List<Book> books) => jsonEncode({
      'app': 'bookmovie_revisit',
      'schema': 2,
      'books': books.map((book) => book.toJson()).toList(),
      'movies': []
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('超过外部导入上限的本机记录仍能写入并重新打开，外部保护保留', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp('large-local-');
    final store = AppStore(dataDirectory: directory.path, seedDemoData: false);
    final reopened =
        AppStore(dataDirectory: directory.path, seedDemoData: false);
    try {
      await store.load();
      final note = 'x' * (20 * 1024 * 1024);
      store.addBook(BookInput(title: '大库', note: note));
      expect(await store.flush(), isTrue);
      final file = File('${directory.path}/state.v1.json');
      expect(await file.length(), greaterThan(20 * 1024 * 1024));

      await reopened.load();
      expect(reopened.loadFailed, isFalse);
      expect(reopened.books.single.note, note);
      expect(() => decodeBackup(store.exportJson()), throwsFormatException);
    } finally {
      await store.flush();
      await reopened.flush();
      store.dispose();
      reopened.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('无累计校正的分支正常合并，重复导入不重复累计', () {
    final local = _book([
      _round([_log('base', 1, pages: 100), _log('left', 2, pages: 10)])
    ]);
    final incoming = _book([
      _round([_log('base', 1, pages: 100), _log('right', 3, pages: 20)])
    ], updatedDay: 2);
    final merged = mergeBackup([local], [], BackupData([incoming], []));
    final again = mergeBackup(merged.books, [], BackupData([incoming], []));
    expect(roundPages(again.books.single.rounds.single), 130);
    expect(again.books.single.rounds.single.logs.length, 3);
  });

  test('累计校正的单向迁移及旧备份重复导入保留最新校正', () {
    final old = _book([
      _round([_log('base', 1, pages: 100)], pages: 70, minutes: 0)
    ]);
    final latest = _book([
      _round([_log('base', 1, pages: 100), _log('next', 2, pages: 10)],
          pages: 80, minutes: 0)
    ], updatedDay: 2);
    final migrated = mergeBackup([], [], BackupData([latest], []));
    final updated = mergeBackup([old], [], BackupData([latest], []));
    final repeated = mergeBackup(updated.books, [], BackupData([old], []));
    expect(migrated.books.single.rounds.single.pages, 80);
    expect(repeated.books.single.rounds.single.pages, 80);
    expect(repeated.books.single.rounds.single.minutes, 0);
    expect(repeated.books.single.rounds.single.logs.length, 2);
  });

  for (final dimension in ['pages', 'minutes']) {
    test('两端新增明细与 $dimension 累计校正冲突时拒绝猜测', () {
      final pages = dimension == 'pages';
      ReadingRound branch(String id, int amount) => _round([
            _log('base', 1,
                pages: pages ? 100 : null, minutes: pages ? null : 100),
            _log(id, 2,
                pages: pages ? amount : null, minutes: pages ? null : amount)
          ],
              pages: pages ? 100 + amount : null,
              minutes: pages ? null : 100 + amount);
      final local = _book([branch('left', 10)]);
      final incoming = _book([branch('right', 20)], updatedDay: 2);
      expect(() => mergeBackup([local], [], BackupData([incoming], [])),
          throwsFormatException);
      expect(local.rounds.single.logs.length, 2);
      expect(local.rounds.single.pages, pages ? 110 : null);
      expect(local.rounds.single.minutes, pages ? null : 110);
    });
  }

  test('累计 0 是校正值，不能当作未填写后自动加入另一端页数', () {
    final local = _book([
      _round([_log('left', 1, pages: 10)])
    ]);
    final incoming = _book([_round([], pages: 0)], updatedDay: 2);
    expect(() => mergeBackup([local], [], BackupData([incoming], [])),
        throwsFormatException);
  });

  test('另一端只补感想或零页数，不影响已有累计校正', () {
    final local = _book([
      _round([_log('note', 1, pages: 0)])
    ]);
    final incoming = _book([_round([], pages: 0, minutes: 30)], updatedDay: 2);
    final result = mergeBackup([local], [], BackupData([incoming], []));
    expect(result.books.single.rounds.single.pages, 0);
    expect(result.books.single.rounds.single.minutes, 30);
    expect(result.books.single.rounds.single.logs.length, 1);
  });

  test('合并两台设备独立开始的当前轮次时拒绝多轮同时在读', () {
    final local = _book([_round([], id: 'left')]);
    final incoming = _book([_round([], id: 'right')], updatedDay: 2);
    expect(() => mergeBackup([local], [], BackupData([incoming], [])),
        throwsFormatException);
  });

  test('分支各自有效但合并后进度倒退时拒绝', () {
    final local = _book([
      _round([_log('base', 1, progress: 10), _log('left', 2, progress: 20)])
    ]);
    final incoming = _book([
      _round([_log('base', 1, progress: 10), _log('right', 3, progress: 15)])
    ], updatedDay: 2);
    expect(() => mergeBackup([local], [], BackupData([incoming], [])),
        throwsFormatException);
  });

  test('合并进度也校验本次页数推导的进度，不能绕过后笔边界', () {
    final local = _book([
      _round([_log('left', 2, pages: 50)])
    ], totalPages: 100);
    final incoming = _book([
      _round([_log('right', 3, progress: 40)])
    ], updatedDay: 2, totalPages: 100);
    expect(() => mergeBackup([local], [], BackupData([incoming], [])),
        throwsFormatException);
  });

  test('历史日期与合入明细不相容时拒绝，不丢弃明细凑范围', () {
    final local = _book([
      _round([_log('left', 3)], finishedAt: DateTime(2026, 1, 4))
    ]);
    final incoming =
        _book([_round([], finishedAt: DateTime(2026, 1, 2))], updatedDay: 2);
    expect(() => mergeBackup([local], [], BackupData([incoming], [])),
        throwsFormatException);
    expect(local.rounds.single.logs.single.id, 'left');
  });

  test('新导入书籍也必须满足唯一当前轮次，不能只检查同 ID 合并', () {
    final book = _book([_round([], id: 'a'), _round([], id: 'b')]);
    expect(() => mergeBackup([], [], BackupData([book], [])),
        throwsFormatException);
  });

  test('导入晚遇冲突时全部原子拒绝，重启仍是原库', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp('atomic-import-');
    final store = AppStore(dataDirectory: directory.path, seedDemoData: false);
    final reopened =
        AppStore(dataDirectory: directory.path, seedDemoData: false);
    try {
      await store.load();
      final local = _book([
        _round([_log('base', 1, pages: 100), _log('left', 2, pages: 10)],
            pages: 110)
      ]);
      store.importJson(_backup([local]));
      final before =
          jsonEncode(store.books.map((book) => book.toJson()).toList());
      final incoming = _book([
        _round([_log('base', 1, pages: 100), _log('right', 3, pages: 20)],
            pages: 120)
      ], updatedDay: 2);
      expect(
          () => store.importJson(_backup([
                local.copyWith(id: 'new-book'),
                incoming,
              ])),
          throwsA(isA<FormatException>().having(
              (error) => error.message, 'message', contains('本机记录未修改'))));
      expect(jsonEncode(store.books.map((book) => book.toJson()).toList()),
          before);
      expect(await store.flush(), isTrue);
      await reopened.load();
      expect(reopened.loadFailed, isFalse);
      expect(jsonEncode(reopened.books.map((book) => book.toJson()).toList()),
          before);
    } finally {
      await store.flush();
      await reopened.flush();
      store.dispose();
      reopened.dispose();
      await directory.delete(recursive: true);
    }
  });
}
