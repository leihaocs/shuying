import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuying/store/app_store.dart';
import 'package:shuying/services/backup_codec.dart';
import 'package:shuying/domain/year_review.dart';
import 'package:shuying/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final stores = <AppStore>[];
  Future<AppStore> load() async {
    final store = AppStore(dataDirectory: directory.path);
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
    await directory.delete(recursive: true);
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
