import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 故障注入使用已锁定的 shared_preferences 平台测试实现，不增加运行时依赖。
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shuying/models/models.dart';
import 'package:shuying/pages/data_backup_page.dart';
import 'package:shuying/services/backup_codec.dart';
import 'package:shuying/services/backup_files.dart';
import 'package:shuying/store/app_store.dart';

final _date = DateTime(2026, 1, 1);

Book _branch(String id, String side, int amount, {int updatedDay = 1}) => Book(
        id: id,
        title: '冲突书 $id',
        createdAt: _date,
        updatedAt: DateTime(2026, 2, updatedDay),
        rounds: [
          ReadingRound(
              id: 'round-$id',
              index: 1,
              startedAt: _date,
              pages: 100 + amount,
              logs: [
                ReadingLog(id: 'base-$id', at: _date, pages: 100),
                ReadingLog(
                    id: '$side-$id', at: DateTime(2026, 1, 2), pages: amount),
              ])
        ]);

String _json(List<Book> books, {int schema = 3}) => jsonEncode({
      'app': 'bookmovie_revisit',
      'schema': schema,
      'books': books.map((book) => book.toJson()).toList(),
      'movies': []
    });

Widget _page(AppStore store) => ChangeNotifierProvider.value(
    value: store, child: const MaterialApp(home: DataBackupPage()));

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text), 250,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

class _LargeImportStore extends AppStore {
  final approvals = <bool>[];
  @override
  Map<String, int> importJson(String text,
      {bool allowLarge = false,
      Map<String, BackupConflictResolution> resolutions = const {}}) {
    approvals.add(allowLarge);
    if (!allowLarge) throw const BackupTooLargeException();
    return {'books': 0, 'movies': 0};
  }

  @override
  Future<bool> flush() async => true;
}

class _FailRename extends IOOverrides {
  _FailRename(this.path);
  final String path;

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return path == this.path ? _RenameFailureFile(file) : file;
  }
}

class _RenameFailureFile implements File {
  _RenameFailureFile(this.file);
  final File file;

  @override
  Future<File> writeAsString(String contents,
          {FileMode mode = FileMode.write,
          Encoding encoding = utf8,
          bool flush = false}) =>
      file.writeAsString(contents,
          mode: mode, encoding: encoding, flush: flush);

  @override
  Future<File> rename(String newPath) async =>
      throw FileSystemException('模拟最终替换失败', file.path);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailPreferences extends InMemorySharedPreferencesStore {
  _FailPreferences() : super.empty();
  bool failWrites = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failWrites) return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('外部大备份默认拒绝，仅显式确认可越过大小保护，内容校验仍有效', () {
    final book = Book(
        id: 'large',
        title: '大备份',
        createdAt: _date,
        updatedAt: _date,
        note: 'x' * maxBackupBytes);
    final text = _json([book]);
    expect(() => decodeBackup(text), throwsA(isA<BackupTooLargeException>()));
    expect(decodeBackup(text, allowLarge: true).books.single.note, book.note);
    expect(() => decodeBackup('{bad', allowLarge: true), throwsFormatException);
  });

  test('文件选择明确透传大小授权，默认仍为 false', () async {
    final approvals = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, (call) async {
      expect(call.method, 'open');
      approvals.add((call.arguments as Map)['allowLarge'] as bool);
      return '{}';
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, null));
    await BackupFiles.open();
    await BackupFiles.open(allowLarge: true);
    expect(approvals, [false, true]);
  });

  test('新导出 schema3 保留标签，旧schema1/2仍可导入，错误标签原子拒绝', () {
    final store = AppStore();
    addTearDown(store.dispose);
    final book = Book(
        id: 'tagged',
        title: '标签书',
        createdAt: _date,
        updatedAt: _date,
        tags: const ['文学', '重读']);
    for (final schema in [1, 2, 3]) {
      expect(decodeBackup(_json([book], schema: schema)).books.single.tags,
          ['文学', '重读']);
    }
    store.importJson(_json([book]));
    final backup = jsonDecode(store.exportJson()) as Map<String, dynamic>;
    expect(backup['schema'], 3);
    expect(decodeBackup(jsonEncode(backup)).books.single.tags, ['文学', '重读']);
    final before = store.books.single.toJson();
    for (final invalid in [
      42,
      '文学',
      ['文学', 2]
    ]) {
      backup['books'][0]['tags'] = invalid;
      expect(() => store.importJson(jsonEncode(backup)), throwsFormatException);
      expect(store.books.single.toJson(), before);
    }
    backup['books'][0].remove('tags');
    expect(decodeBackup(jsonEncode(backup)).books.single.tags, isEmpty);
    backup['books'] = [];
    backup['movies'] = [
      Movie(id: 'm', title: '标签电影', createdAt: _date, updatedAt: _date).toJson()
        ..['tags'] = [false]
    ];
    expect(() => decodeBackup(jsonEncode(backup)), throwsFormatException);
  });

  test('冲突预览列出所有冲突及两端快照，默认不提交任何部分', () {
    final local = [_branch('a', 'left', 10), _branch('b', 'left', 10)];
    final source = [
      _branch('a', 'right', 20, updatedDay: 2),
      _branch('b', 'right', 20, updatedDay: 2)
    ];
    try {
      mergeBackup(local, [], BackupData(source, []));
      fail('有冲突时必须拒绝默认合并');
    } on BackupConflictException catch (error) {
      expect(error.conflicts.map((conflict) => conflict.bookId), ['a', 'b']);
      expect(error.conflicts.first.local, same(local.first));
      expect(error.conflicts.first.incoming, same(source.first));
      expect(error.conflicts.first.reason, contains('累计校正'));
    }
    expect(local.first.rounds.single.pages, 110);
    expect(local.first.rounds.single.logs.last.id, 'left-a');
  });

  test('逐书保留本机/采用来源只处理冲突书，来源累计不与本机猜测相加', () {
    final local = [_branch('a', 'left', 10), _branch('b', 'left', 10)];
    final source = [
      _branch('a', 'right', 20, updatedDay: 2),
      _branch('b', 'right', 20, updatedDay: 2),
      Book(id: 'new', title: '新书', createdAt: _date, updatedAt: _date)
    ];
    final merged = mergeBackup(local, [], BackupData(source, []),
        resolutions: {
          'a': BackupConflictResolution.keepLocal,
          'b': BackupConflictResolution.useIncoming,
        });
    final a = merged.books.firstWhere((book) => book.id == 'a');
    final b = merged.books.firstWhere((book) => book.id == 'b');
    expect(a.rounds.single.pages, 110);
    expect(a.rounds.single.logs.last.id, 'left-a');
    expect(b.rounds.single.pages, 120);
    expect(b.rounds.single.logs.last.id, 'right-b');
    expect(merged.books.any((book) => book.id == 'new'), isTrue);
    expect(local.last.rounds.single.logs.last.id, 'left-b');
  });

  test('来源自身违反进度规则时不可强制采用，可明确跳过新书', () {
    final invalid = Book(
        id: 'bad',
        title: '来源错误',
        createdAt: _date,
        updatedAt: _date,
        rounds: [
          ReadingRound(id: 'r', index: 1, startedAt: _date, logs: [
            ReadingLog(id: 'a', at: _date, progress: 20),
            ReadingLog(id: 'b', at: DateTime(2026, 1, 2), progress: 10)
          ])
        ]);
    expect(
        () => mergeBackup([], [], BackupData([invalid], []),
            resolutions: {
              'bad': BackupConflictResolution.useIncoming,
            }),
        throwsA(isA<BackupConflictException>()));
    expect(
        mergeBackup([], [], BackupData([invalid], []),
            resolutions: {
              'bad': BackupConflictResolution.keepLocal,
            }).books,
        isEmpty);
  });

  group('保存故障与显式恢复上次成功副本', () {
    late Directory directory;
    late File file;
    final stores = <AppStore>[];
    Future<AppStore> load() async {
      final store =
          AppStore(dataDirectory: directory.path, seedDemoData: false);
      stores.add(store);
      await store.load();
      return store;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      directory = await Directory.systemTemp.createTemp('recovery-choice-');
      file = File('${directory.path}/state.v1.json');
    });
    tearDown(() async {
      for (final store in stores) {
        await store.flush();
        store.dispose();
      }
      stores.clear();
      await directory.delete(recursive: true);
    });

    test('复制恢复副本失败保留主库和原副本，重试可保存内存中的新记录', () async {
      final store = await load();
      store.addBook(BookInput(title: '已落盘的书'));
      expect(await store.flush(), isTrue);
      final previous = File('${file.path}.previous');
      final before = await file.readAsString();
      final beforePrevious = await previous.readAsString();
      final blocked = Directory('${file.path}.previous.tmp');
      await blocked.create();
      store.addMovie(MovieInput(title: '等待重试的电影'));
      expect(await store.flush(), isFalse);
      expect(await file.readAsString(), before);
      expect(await previous.readAsString(), beforePrevious);
      expect(store.movies.single.title, '等待重试的电影');
      expect(store.saving, isFalse);
      await blocked.delete();
      expect(await store.flush(), isTrue);
      expect((await load()).movies.single.title, '等待重试的电影');
    });

    test('主库最终替换失败保留原文件和完整副本，失败队列不会阻塞重试', () async {
      final store = await load();
      store.addBook(BookInput(title: '原始记录'));
      expect(await store.flush(), isTrue);
      final before = await file.readAsString();
      await IOOverrides.runWithIOOverrides(() async {
        store.addMovie(MovieInput(title: '最终替换后才能落盘'));
        expect(await store.flush(), isFalse);
      }, _FailRename('${file.path}.tmp'));
      expect(await file.readAsString(), before);
      expect(await File('${file.path}.previous').readAsString(), before);
      expect(store.storageError, isNotNull);
      expect(store.saving, isFalse);
      expect(await store.flush(), isTrue);
      expect((await load()).movies.single.title, '最终替换后才能落盘');
    });

    test('偏好写入失败仍保留已落盘记录，重试后偏好与记录均可重开', () async {
      final original = SharedPreferencesStorePlatform.instance;
      final prefs = _FailPreferences();
      SharedPreferencesStorePlatform.instance = prefs;
      try {
        final store = await load();
        expect(await store.flush(), isTrue);
        prefs.failWrites = true;
        store.addMovie(MovieInput(title: '偏好失败不丢记录'));
        store.setThemeMode(ThemeMode.dark);
        expect(await store.flush(), isFalse);
        expect(
            decodeBackup(await file.readAsString(), legacy: true)
                .movies
                .single
                .title,
            '偏好失败不丢记录');
        expect(store.storageError, isNotNull);
        prefs.failWrites = false;
        expect(await store.flush(), isTrue);
        expect((await prefs.getAll())['flutter.shuying.theme.v1'], 'dark');
        await (await SharedPreferences.getInstance()).reload();
        final reopened = await load();
        expect(reopened.movies.single.title, '偏好失败不丢记录');
        expect(reopened.themeMode, ThemeMode.dark);
      } finally {
        prefs.failWrites = false;
        SharedPreferencesStorePlatform.instance = original;
      }
    });

    test('清空记录同时移除失败保存遗留的恢复副本临时文件', () async {
      final store = await load();
      store.addBook(BookInput(title: '需要彻底清空的记录'));
      expect(await store.flush(), isTrue);
      final temporaryPrevious = File('${file.path}.previous.tmp');
      await file.copy(temporaryPrevious.path);
      store.clearAll();
      expect(await store.flush(), isTrue);
      expect(await temporaryPrevious.exists(), isFalse);
      expect(
          decodeBackup(await file.readAsString(), legacy: true).books, isEmpty);
    });

    test('读取失败不自动回滚，确认恢复先保留损坏原件，恢复后可重开', () async {
      final source = _json([_branch('restore', 'last-good', 10)]);
      await file.writeAsString('damaged-original');
      await File('${file.path}.previous').writeAsString(source);
      final store = await load();
      expect(store.loadFailed, isTrue);
      expect(store.canRestorePrevious, isTrue);
      expect(store.books, isEmpty);
      expect(await file.readAsString(), 'damaged-original');
      expect(await store.restorePrevious(), isTrue);
      final damaged = directory
          .listSync()
          .whereType<File>()
          .where((entry) => entry.path.contains('.damaged-'))
          .single;
      expect(await damaged.readAsString(), 'damaged-original');
      expect(store.books.single.id, 'restore');
      expect(await store.flush(), isTrue);
      expect((await load()).books.single.id, 'restore');
      store.clearAll();
      expect(await store.flush(), isTrue);
      expect(await damaged.exists(), isFalse);
    });

    test('副本损坏时恢复失败，不覆盖当前原件或副本', () async {
      await file.writeAsString('damaged-current');
      final previous = File('${file.path}.previous');
      await previous.writeAsString('damaged-previous');
      final store = await load();
      expect(await store.restorePrevious(), isFalse);
      expect(store.loadFailed, isTrue);
      expect(await file.readAsString(), 'damaged-current');
      expect(await previous.readAsString(), 'damaged-previous');
    });

    test('恢复临时文件无法写入时，不覆盖损坏原件且保留可用副本', () async {
      await file.writeAsString('damaged-current');
      final source = _json([_branch('restore', 'last-good', 10)]);
      final previous = File('${file.path}.previous');
      await previous.writeAsString(source);
      await Directory('${file.path}.recovery.tmp').create();
      final store = await load();
      expect(await store.restorePrevious(), isFalse);
      expect(await file.readAsString(), 'damaged-current');
      expect(await previous.readAsString(), source);
      expect(store.books, isEmpty);
    });

    test('恢复最终替换失败保留损坏原件和可用副本，稍后仍可重试', () async {
      await file.writeAsString('damaged-current');
      final source = _json([_branch('restore', 'last-good', 10)]);
      final previous = File('${file.path}.previous');
      await previous.writeAsString(source);
      final store = await load();
      await IOOverrides.runWithIOOverrides(() async {
        expect(await store.restorePrevious(), isFalse);
      }, _FailRename('${file.path}.recovery.tmp'));
      expect(await file.readAsString(), 'damaged-current');
      expect(await previous.readAsString(), source);
      expect(store.restoringPrevious, isFalse);
      expect(await store.restorePrevious(), isTrue);
      expect(store.books.single.id, 'restore');
    });

    test('部分冲突选择未补全时，importJson 仍原子拒绝', () async {
      final store = await load();
      store.importJson(
          _json([_branch('a', 'left', 10), _branch('b', 'left', 10)]));
      final before = store.books.map((book) => book.toJson()).toList();
      expect(
          () => store.importJson(
              _json([
                _branch('a', 'right', 20, updatedDay: 2),
                _branch('b', 'right', 20, updatedDay: 2),
              ]),
              resolutions: {'a': BackupConflictResolution.useIncoming}),
          throwsA(isA<BackupConflictException>()));
      expect(store.books.map((book) => book.toJson()).toList(), before);
    });
  });

  testWidgets('大文件选择必须先确认，取消不会打开文件选择器', (tester) async {
    final store = AppStore();
    addTearDown(store.dispose);
    final approvals = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, (call) async {
      expect(call.method, 'open');
      approvals.add((call.arguments as Map)['allowLarge'] as bool);
      return _json([]);
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, null));
    await tester.pumpWidget(_page(store));
    await _tap(tester, '选择大文件（超过 20 MB，需确认）');
    expect(approvals, isEmpty);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(approvals, isEmpty);
    await _tap(tester, '选择大文件（超过 20 MB，需确认）');
    await tester.tap(find.text('确认导入大文件'));
    await tester.pumpAndSettle();
    expect(approvals, [true]);
    expect(find.textContaining('为避免卡顿不展开全文'), findsOneWidget);
  });

  testWidgets('大备份不展开全文，但复制仍保留完整免费 JSON', (tester) async {
    final store = AppStore();
    addTearDown(store.dispose);
    final note = 'x' * 25000;
    store.addBook(BookInput(title: '大备份复制', note: note));
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_page(store));
    await _tap(tester, '生成备份文本');
    expect(find.text('备份较大，不展开全文。请复制完整内容或导出 JSON 文件。'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    await _tap(tester, '复制到剪贴板');
    expect(decodeBackup(copied!).books.single.note, note);
  });

  testWidgets('粘贴导入超限提示取消不重试，确认才传 allowLarge', (tester) async {
    final store = _LargeImportStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_page(store));
    await tester.enterText(find.byKey(const Key('backup-import-text')), '{}');
    await _tap(tester, '合并导入（保留现有记录）');
    expect(store.approvals, [false]);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(store.approvals, [false]);
    await _tap(tester, '合并导入（保留现有记录）');
    await tester.tap(find.text('确认导入大文件'));
    await tester.pumpAndSettle();
    expect(store.approvals, [false, false, true]);
    expect(find.textContaining('已处理备份'), findsOneWidget);
  });

  testWidgets('冲突页面先展示两端累计，取消不改库，显式选择来源才整书替换', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp('conflict-page-');
    final store = AppStore(dataDirectory: directory.path, seedDemoData: false);
    addTearDown(() async {
      await store.flush();
      store.dispose();
      await directory.delete(recursive: true);
    });
    await store.load();
    store.importJson(_json([_branch('a', 'left', 10)]));
    await store.flush();
    await tester.pumpWidget(_page(store));
    final field = find.byKey(const Key('backup-import-text'));
    await tester.scrollUntilVisible(field, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.enterText(
        field, _json([_branch('a', 'right', 20, updatedDay: 2)]));
    tester.testTextInput.hide();
    await _tap(tester, '合并导入（保留现有记录）');
    expect(find.text('备份有冲突，尚未修改本机'), findsOneWidget);
    expect(find.textContaining('110 页'), findsOneWidget);
    expect(find.textContaining('120 页'), findsOneWidget);
    expect(find.textContaining('本机独有内容将不再保留'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(store.books.single.rounds.single.logs.last.id, 'left-a');
    await _tap(tester, '合并导入（保留现有记录）');
    await tester.scrollUntilVisible(find.text('采用导入来源这本书（替换）'), 180,
        scrollable: find
            .descendant(
                of: find.byType(AlertDialog), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('采用导入来源这本书（替换）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按选择导入'));
    await tester.runAsync(() => store.flush());
    await tester.pumpAndSettle();
    expect(store.books.single.rounds.single.pages, 120);
    expect(store.books.single.rounds.single.logs.last.id, 'right-a');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
