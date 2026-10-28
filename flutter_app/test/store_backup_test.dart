import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuying/store/app_store.dart';
import 'package:shuying/services/backup_codec.dart';
import 'package:shuying/services/backup_files.dart';
import 'package:shuying/domain/year_review.dart';
import 'package:shuying/domain/books.dart' as books;
import 'package:shuying/domain/movies.dart' as movies;
import 'package:shuying/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final stores = <AppStore>[];
  Future<AppStore> load({bool? seedDemoData = false}) async {
    final store =
        AppStore(dataDirectory: directory.path, seedDemoData: seedDemoData);
    stores.add(store);
    await store.load();
    return store;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('shuying-test-');
  });
  tearDown(() async {
    for (final store in stores) {
      await store.flush();
      store.dispose();
    }
    stores.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFiles.channel, null);
    await directory.delete(recursive: true);
  });

  test('首次安装默认空库且重启后仍为空', () async {
    final store = await load();
    expect(store.books, isEmpty);
    expect(store.movies, isEmpty);
    expect(await store.flush(), isTrue);
    final reopened = await load();
    expect(reopened.books, isEmpty);
    expect(reopened.movies, isEmpty);
  });

  test('显式样例模式不覆盖已有记录', () async {
    final store = await load(seedDemoData: true);
    expect(store.books, isNotEmpty);
    expect(store.movies, isNotEmpty);
    store.clearAll();
    final book = store.addBook(BookInput(title: '我的记录', author: '作者'));
    expect(await store.flush(), isTrue);
    final reopened = await load(seedDemoData: true);
    expect(reopened.books.single.id, book.id);
    expect(reopened.movies, isEmpty);
  });

  for (final channel in {
    'iOS': true,
    'Google Play': true,
    'Android direct（含华为安卓）': false,
    'HarmonyOS': false
  }.entries) {
    test('${channel.key} 首启策略、保留记录与清空后不再生成样例', () async {
      var policyCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BackupFiles.channel, (call) async {
        expect(call.method, 'seedDemoData');
        policyCalls++;
        return channel.value;
      });
      final first = await load(seedDemoData: null);
      expect(first.loadFailed, isFalse);
      expect(first.books.isNotEmpty, channel.value);
      expect(first.movies.isNotEmpty, channel.value);
      final originalIds = first.books.map((b) => b.id).toList();
      expect(await first.flush(), isTrue);

      final reopened = await load(seedDemoData: null);
      expect(reopened.books.map((b) => b.id), originalIds);
      reopened.clearAll();
      expect(await reopened.flush(), isTrue);
      final cleared = await load(seedDemoData: null);
      expect(cleared.books, isEmpty);
      expect(cleared.movies, isEmpty);
      final book = cleared.addBook(BookInput(title: '我的记录', author: '作者'));
      expect(await cleared.flush(), isTrue);
      final existing = await load(seedDemoData: null);
      expect(existing.books.single.id, book.id);
      expect(existing.movies, isEmpty);
      expect(policyCalls, 1); // 只在完全没有本地记录时查询渠道策略。
    });
  }

  test('未知原生渠道不生成样例，仍能正常启动', () async {
    final store = await load(seedDemoData: null);
    expect(store.loadFailed, isFalse);
    expect(store.books, isEmpty);
    expect(store.movies, isEmpty);
  });

  test('作者导演选填，出版社版本支持保存、重启与跨端备份', () async {
    final store = await load();
    final book = store.addBook(BookInput(title: '选填书籍', edition: '出版社 · 第2版'));
    store.addMovie(MovieInput(title: '选填电影'));
    expect(store.books.single.author, isEmpty);
    expect(store.movies.single.director, isEmpty);
    expect(await store.flush(), isTrue);
    final reopened = await load();
    expect(reopened.books.single.edition, '出版社 · 第2版');
    final backup = decodeBackup(reopened.exportJson());
    expect(backup.books.single.edition, '出版社 · 第2版');
    expect(backup.movies.single.director, isEmpty);
    final other = AppStore(dataDirectory: '${directory.path}/other');
    stores.add(other);
    await other.load();
    other.importJson(reopened.exportJson());
    expect(other.books.single.edition, '出版社 · 第2版');
    store.updateBook(book.id, BookInput(title: book.title));
    expect(store.books.single.edition, isNull);
    // 老备份没有新字段；作者/导演缺失也可恢复为空文本。
    final legacy = jsonDecode(reopened.exportJson()) as Map<String, dynamic>;
    (legacy['books'][0] as Map).remove('edition');
    (legacy['books'][0] as Map).remove('author');
    (legacy['movies'][0] as Map).remove('director');
    final restored = decodeBackup(jsonEncode(legacy));
    expect(restored.books.single.edition, isNull);
    expect(restored.books.single.author, isEmpty);
    expect(restored.movies.single.director, isEmpty);
  });

  test('任意过去日期补记后阅读轮次重排，活动轮次和观影时间顺序保留', () async {
    final store = await load();
    final book = store.addBook(BookInput(title: '补记'));
    store.startReading(book.id);
    final activeId = store.bookById(book.id)!.rounds.single.id;
    store.addPastRound(
        book.id,
        PastRoundInput(
            startedAt: DateTime(2005, 1, 1), finishedAt: DateTime(2005, 1, 9)));
    final middleId = store.bookById(book.id)!.rounds.first.id;
    store.addPastRound(
        book.id,
        PastRoundInput(
            startedAt: DateTime(1990, 1, 1), finishedAt: DateTime(1990, 1, 9)));
    var rounds = store.bookById(book.id)!.rounds;
    expect(rounds.map((r) => r.index), [1, 2, 3]);
    expect(
        rounds.map((r) => r.startedAt.year), [1990, 2005, DateTime.now().year]);
    expect(books.activeRound(store.bookById(book.id)!)!.id, activeId);
    expect(books.activeRound(store.bookById(book.id)!)!.index, 3);
    // 已结束的轮次不再增加阅读次数（只能改已有记录），顺序与编号保持不变。
    expect(
        () => store.addLog(
            book.id, middleId, LogInput(at: DateTime(1980), pages: 10)),
        throwsStateError);
    rounds = store.bookById(book.id)!.rounds;
    expect(rounds.map((r) => r.index), [1, 2, 3]);
    expect(rounds.map((r) => r.startedAt.year),
        [1990, 2005, DateTime.now().year]);
    expect(rounds[1].id, middleId);
    expect(rounds[1].finishedAt, DateTime(2005, 1, 9));
    store.removeRound(book.id, middleId);
    expect(store.bookById(book.id)!.rounds.map((r) => r.index), [1, 2]);
    final movie = store.addMovie(MovieInput(title: '补记观影'));
    for (final year in [2005, 1980, 1990]) {
      store.addWatch(movie.id, at: DateTime(year));
    }
    expect(movies.sortedWatches(store.movies.single).map((w) => w.at.year),
        [2005, 1990, 1980]);
    expect(await store.flush(), isTrue);
    final reopened = await load();
    expect(reopened.books.single.rounds.map((r) => r.index), [1, 2]);
    expect(reopened.books.single.rounds.first.startedAt.year, 1990);
    expect(movies.sortedWatches(reopened.movies.single).last.at.year, 1980);
  });

  test('即时写入、重启与旧偏好迁移', () async {
    final store = await load();
    store.clearAll();
    final book = store.addBook(BookInput(title: '保存测试', author: '作者'));
    store.startReading(book.id);
    store.addLog(book.id, store.books.first.rounds.first.id,
        LogInput(at: DateTime(2026, 10, 2), pages: 12, minutes: 8));
    final movie = store.addMovie(MovieInput(title: '电影测试', director: '导演'));
    store.addWatch(movie.id, at: DateTime(2026, 10, 2), rating: 5);
    expect(await store.flush(), isTrue);
    final reopened = await load();
    expect(reopened.books.single.rounds.single.logs.single.pages, 12);
    expect(reopened.movies.single.watches.single.rating, 5);
    // 清空后的首轮保存不保留已删除记录；后续正常保存仍保留上一份。
    reopened.updateBook(book.id, BookInput(title: '更新后', author: '作者'));
    expect(await reopened.flush(), isTrue);
    expect(
        File('${directory.path}/state.v1.json.previous').existsSync(), isTrue);
  });

  test('旧 shared_preferences 数据迁移且升级不删除记录', () async {
    final now = DateTime(2026, 10, 2);
    final old = Book(
        id: 'old', title: '旧记录', author: '', createdAt: now, updatedAt: now);
    SharedPreferences.setMockInitialValues({
      'shuying.state.v1': jsonEncode({
        'books': [old.toJson()],
        'movies': [],
      }),
      'shuying.privacy.v1': true
    });
    final store = await load();
    expect(store.books.single.id, 'old');
    expect(store.privacyConsent, isFalse); // 新政策需重新确认，记录保留。
    expect(await store.flush(), isTrue);
    final reopened = await load();
    expect(reopened.books.single.id, 'old');
  });

  test('清空数据同时移除旧偏好和历史备份，重启不复活旧记录', () async {
    final now = DateTime(2026, 10, 2);
    final old = Book(
        id: 'legacy',
        title: '旧数据',
        author: '作者',
        createdAt: now,
        updatedAt: now);
    SharedPreferences.setMockInitialValues({
      'shuying.state.v1': jsonEncode({
        'books': [old.toJson()],
        'movies': []
      })
    });
    final store = await load();
    await store.flush();
    expect(store.books, isNotEmpty);
    store.clearAll();
    expect(await store.flush(), isTrue);
    expect(
        (await SharedPreferences.getInstance()).containsKey('shuying.state.v1'),
        isFalse);
    final disk = File('${directory.path}/state.v1.json').readAsStringSync();
    expect(disk.contains('legacy'), isFalse);
    final previous = File('${directory.path}/state.v1.json.previous');
    if (previous.existsSync()) {
      expect(previous.readAsStringSync().contains('legacy'), isFalse);
    }
    expect((await load()).books, isEmpty);
  });

  test('跨端双向合并嵌套记录且重复导入不重复', () async {
    final a = await load();
    a.clearAll();
    final book = a.addBook(BookInput(title: '共同书', author: '作者'));
    a.startReading(book.id);
    final round = a.books.single.rounds.single.id;
    final movie = a.addMovie(MovieInput(title: '共同电影', director: '导演'));
    final baseline = a.exportJson();
    final b = AppStore(dataDirectory: '${directory.path}/other');
    stores.add(b);
    await b.load();
    b.clearAll();
    b.importJson(baseline);
    a.addLog(book.id, round, LogInput(at: DateTime(2026, 1, 1), pages: 10));
    b.addLog(book.id, round, LogInput(at: DateTime(2026, 2, 1), pages: 20));
    a.addWatch(movie.id, at: DateTime(2026, 1, 1), rating: 4);
    b.addWatch(movie.id, at: DateTime(2026, 2, 1), rating: 5);
    a.importJson(b.exportJson());
    a.importJson(b.exportJson());
    b.importJson(a.exportJson());
    expect(a.books.single.rounds.single.logs.length, 2);
    expect(a.movies.single.watches.length, 2);
    expect(b.books.single.rounds.single.logs.length, 2);
    expect(b.movies.single.watches.length, 2);
    expect(await a.flush(), isTrue);
    expect((await load()).movies.single.watches.length, 2);
    expect(jsonDecode(a.exportJson()).containsKey('pro'), isFalse);
  });

  test('无效备份原子拒绝，空备份不清空本机', () async {
    final store = await load();
    store.addBook(BookInput(title: '保留的记录', author: '作者'));
    final before = store.books.length;
    final map = jsonDecode(store.exportJson()) as Map<String, dynamic>;
    map['books'].add({'id': 'bad', 'title': '坏记录'});
    expect(() => store.importJson(jsonEncode(map)), throwsFormatException);
    expect(store.books.length, before);
    expect(() => store.importJson('{"books":[],"movies":[]}'),
        throwsFormatException);
    store.importJson(
        '{"app":"bookmovie_revisit","schema":1,"books":[],"movies":[]}');
    expect(store.books.length, before);
    map['schema'] = 99;
    expect(() => store.importJson(jsonEncode(map)), throwsFormatException);
  });

  test('损坏本机文件保留并禁止导入或保存覆盖', () async {
    final file = File('${directory.path}/state.v1.json');
    await file.writeAsString('damaged');
    final store = await load();
    expect(store.loadFailed, isTrue);
    expect(await store.flush(), isFalse);
    expect(() => store.importJson('{}'), throwsStateError);
    expect(await file.readAsString(), 'damaged');
  });

  test('写入失败可见并可重试，不吞掉数据', () async {
    final store = await load();
    await store.flush();
    final temp = Directory('${directory.path}/state.v1.json.tmp');
    await temp.create();
    store.addMovie(MovieInput(title: '保留在内存', director: ''));
    expect(await store.flush(), isFalse);
    expect(store.storageError, isNotNull);
    await temp.delete();
    expect(await store.flush(), isTrue);
    expect(store.storageError, isNull);
    expect((await load()).movies.any((m) => m.title == '保留在内存'), isTrue);
  });

  test('未来时间与同 ID 元数据使用较新值、轮次不丢', () {
    final now = DateTime(2026);
    final old = Book(
        id: 'b',
        title: '旧',
        author: '',
        createdAt: now,
        updatedAt: now,
        rounds: [
          ReadingRound(id: 'r', index: 1, startedAt: now, finishedAt: now)
        ]);
    final newer = old.copyWith(
        title: '新',
        updatedAt: now.add(const Duration(days: 1)),
        rounds: [ReadingRound(id: 'r', index: 1, startedAt: now)]);
    final result = mergeBackup([old], [], BackupData([newer], []));
    expect(result.books.single.title, '新');
    expect(result.books.single.rounds.single.finishedAt, now);
  });

  test('年度回顾按时间聚合，空评分不当零分', () {
    final now = DateTime(2026, 1, 2);
    final b = Book(
        id: 'b',
        title: '书',
        author: '',
        createdAt: now,
        updatedAt: now,
        rounds: [
          ReadingRound(
              id: 'r',
              index: 1,
              startedAt: now,
              finishedAt: now,
              logs: [
                ReadingLog(id: 'l', at: now, pages: 10, minutes: 30),
                ReadingLog(id: 'l2', at: now, minutes: 20),
                ReadingLog(id: 'l3', at: DateTime(2025), minutes: 999)
              ])
        ]);
    final m = Movie(
        id: 'm',
        title: '电影',
        director: '',
        createdAt: now,
        updatedAt: now,
        watches: [
          WatchRecord(id: 'w', at: now, rating: 4),
          WatchRecord(id: 'w2', at: now)
        ]);
    final review = YearReview([b], [m], 2026);
    expect(review.minutes, 50);
    expect(review.pages, 10);
    expect(review.readTimes, 1);
    expect(review.readingDays, 1);
    expect(review.monthlyMinutes[0], 50);
    expect(review.watchTimes, 2);
    expect(review.averageRating, 4);
  });
}
