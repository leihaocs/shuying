import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/domain/fmt.dart';
import 'package:shuying/domain/books.dart' as books;
import 'package:shuying/domain/movies.dart' as movies;
import 'package:shuying/domain/year_review.dart';
import 'package:shuying/services/backup_codec.dart';
import 'package:shuying/models/models.dart';
import 'package:shuying/store/app_store.dart';
import 'package:shuying/theme/app_theme.dart';
import 'package:shuying/widgets/sheets.dart';

void main() {
  group('记录时间文案', () {
    Widget field(DateTime value) => MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordDateTimeField(
              label: '阅读日期',
              value: value,
              onChanged: (_) {},
            ),
          ),
        );

    testWidgets('没手动改时间且是今天：显示（当前时间）', (tester) async {
      await tester.pumpWidget(field(DateTime.now()));
      expect(find.textContaining('（当前时间）'), findsOneWidget);
    });

    testWidgets('日期切到不是今天：不再显示（当前时间）', (tester) async {
      await tester.pumpWidget(field(DateTime.now()));
      expect(find.textContaining('（当前时间）'), findsOneWidget);

      // 同一棵树换成昨天的日期（复现用户操作后的状态）
      await tester.pumpWidget(field(atDayAgo(1)));
      expect(find.textContaining('（当前时间）'), findsNothing);
    });
  });

  group('阅读进度规则', () {
    late AppStore store;

    Book newBook() {
      final book = store.addBook(BookInput(title: '进度书', totalPages: 200));
      store.startReading(book.id);
      return store.books.firstWhere((b) => b.id == book.id);
    }

    setUp(() => store = AppStore());
    tearDown(() => store.dispose());

    test('进度不能小于上一次记录的进度', () {
      final book = newBook();
      final roundId = book.rounds.single.id;
      store.addLog(book.id, roundId, LogInput(at: atDayAgo(2), progress: 30));
      expect(
        () => store.addLog(
            book.id, roundId, LogInput(at: DateTime.now(), progress: 20)),
        throwsArgumentError,
      );
    });

    test('两次记录中间补记一次，进度必须落在两者之间', () {
      final book = newBook();
      final roundId = book.rounds.single.id;
      store.addLog(book.id, roundId, LogInput(at: atDayAgo(3), progress: 10));
      store.addLog(book.id, roundId, LogInput(at: atDayAgo(1), progress: 30));

      // 落在 10 ~ 30 之间：允许
      expect(
        () => store.addLog(
            book.id, roundId, LogInput(at: atDayAgo(2), progress: 20)),
        returnsNormally,
      );
      // 小于前一次 10：拦截
      expect(
        () => store.addLog(
            book.id, roundId, LogInput(at: atDayAgo(2), progress: 5)),
        throwsArgumentError,
      );
    });

    test('已结束的轮次：能改已有记录，但不能新增阅读次数', () {
      final book = newBook();
      final roundId = book.rounds.single.id;
      store.addLog(book.id, roundId,
          LogInput(at: atDayAgo(2), pages: 20, minutes: 30, progress: 10));
      store.finishRound(book.id, roundId);

      final done = store.books.firstWhere((b) => b.id == book.id).rounds.single;
      expect(done.isActive, isFalse);
      final logId = done.logs.single.id;

      // 改已有记录的日期、页数、时长：允许
      expect(
        () => store.updateLog(book.id, roundId, logId,
            LogInput(at: atDayAgo(2), pages: 25, minutes: 40)),
        returnsNormally,
      );

      // 再补一次阅读：拦截
      expect(
        () =>
            store.addLog(book.id, roundId, LogInput(at: atDayAgo(1), pages: 5)),
        throwsStateError,
      );
      store.updateLog(book.id, roundId, logId,
          LogInput(at: atDayAgo(2), pages: 25, minutes: 40, progress: 99));
      expect(store.books.single.rounds.single.logs.single.progress, 10);
      expect(store.books.single.rounds.single.logs.length, 1);
    });

    test('中间进度上下界及修改后的时间顺序校验，失败不改变原数据', () {
      final book = newBook();
      final id = book.rounds.single.id;
      store.addLog(book.id, id, LogInput(at: DateTime(2000), progress: 10));
      store.addLog(book.id, id, LogInput(at: DateTime(2010), progress: 30));
      expect(
          () => store.addLog(
              book.id, id, LogInput(at: DateTime(2005), progress: 35)),
          throwsArgumentError);
      expect(store.books.single.rounds.single.logs.length, 2);
      store.addLog(book.id, id, LogInput(at: DateTime(2005), progress: 10));
      final middle = books.sortedLogs(store.books.single.rounds.single)[1];
      expect(
          () => store.updateLog(book.id, id, middle.id,
              LogInput(at: DateTime(2020), progress: 20)),
          throwsArgumentError);
      expect(books.sortedLogs(store.books.single.rounds.single)[1].at,
          DateTime(2005));
      store.updateLog(
          book.id, id, middle.id, LogInput(at: DateTime(2005), progress: 30));
    });

    test('自动页数接续手动进度，插入时也检查相邻的进度上界', () {
      final book = newBook();
      final id = book.rounds.single.id;
      store.addLog(book.id, id, LogInput(at: DateTime(2000), progress: 10));
      store.addLog(book.id, id, LogInput(at: DateTime(2010), progress: 30));
      expect(
          () => store.addLog(
              book.id, id, LogInput(at: DateTime(2005), pages: 60)),
          throwsArgumentError);
      store.addLog(book.id, id, LogInput(at: DateTime(2005), pages: 20));
      store.addLog(book.id, id, LogInput(at: DateTime(2020), pages: 20));
      expect(
          books.roundProgress(
              store.books.single, store.books.single.rounds.single),
          40);
    });

    test('同一时间记录以最新添加为先，进度校验与显示一致', () {
      final book = newBook();
      final id = book.rounds.single.id;
      final at = DateTime(2000);
      store.addLog(book.id, id, LogInput(at: at, progress: 10));
      store.addLog(book.id, id, LogInput(at: at, progress: 20));
      expect(books.sortedLogs(store.books.single.rounds.single).first.progress,
          20);
      expect(
          books.roundProgress(
              store.books.single, store.books.single.rounds.single),
          20);
      expect(() => store.addLog(book.id, id, LogInput(at: at, progress: 15)),
          throwsArgumentError);
    });

    test('历史累计页数时长修改、备份及年度统计一致，不制造新明细', () {
      final book = store.addBook(BookInput(title: '历史汇总'));
      store.addPastRound(
          book.id,
          PastRoundInput(
              startedAt: DateTime(2000),
              finishedAt: DateTime(2000, 2),
              pages: 100,
              minutes: 60));
      final old = store.books.single.rounds.single;
      store.updateRound(book.id, old.id,
          startedAt: DateTime(2001),
          finishedAt: DateTime(2001, 2),
          pages: 200,
          minutes: 90,
          note: '感想');
      final round = store.books.single.rounds.single;
      expect(round.logs, isEmpty);
      expect(round.id, old.id);
      expect(books.roundPages(round), 200);
      expect(books.roundMinutes(round), 90);
      expect(books.roundProgress(store.books.single, round), 0);
      final restored = decodeBackup(store.exportJson());
      expect(restored.books.single.rounds.single.pages, 200);
      final review = YearReview(restored.books, [], 2001);
      expect(review.pages, 200);
      expect(review.minutes, 90);
      expect(review.monthlyMinutes[1], 90);
      expect(YearReview(restored.books, [], 2000).pages, 0);
    });

    test('历史总数与已有明细的修改、删除同步，进度始终不变', () {
      final book = newBook();
      final id = book.rounds.single.id;
      store.addLog(book.id, id,
          LogInput(at: DateTime(2000), pages: 20, minutes: 30, progress: 10));
      store.finishRound(book.id, id);
      final round = store.books.single.rounds.single;
      store.updateRound(book.id, id,
          startedAt: round.startedAt,
          finishedAt: round.finishedAt,
          note: '',
          pages: 100,
          minutes: 60);
      store.updateLog(book.id, id, round.logs.single.id,
          LogInput(at: DateTime(2000), pages: 25, minutes: 40, progress: 99));
      var updated = store.books.single.rounds.single;
      expect(updated.pages, 105);
      expect(updated.minutes, 70);
      expect(updated.logs.single.progress, 10);
      final review = YearReview(store.books, [], updated.finishedAt!.year);
      expect(review.pages, 105); // 不再重复叠加旧明细页数。
      expect(review.minutes, 70);
      store.removeLog(book.id, round.logs.single.id);
      updated = store.books.single.rounds.single;
      expect(updated.logs, isEmpty);
      expect(updated.pages, 80);
      expect(updated.minutes, 30);
    });

    test('当前阅读改时间页数进度，保留 ID 并按新时间重排', () {
      final book = newBook();
      final round = book.rounds.single.id;
      store.addLog(book.id, round,
          LogInput(at: DateTime(2000), pages: 10, progress: 10));
      store.addLog(book.id, round,
          LogInput(at: DateTime(2005), pages: 20, progress: 30));
      final old = books.sortedLogs(store.books.single.rounds.single).last;
      store.updateLog(book.id, round, old.id,
          LogInput(at: DateTime(2010), pages: 25, progress: 40, note: '修正'));
      final updated = store.books.single.rounds.single;
      expect(updated.logs.length, 2);
      expect(books.sortedLogs(updated).first.id, old.id);
      expect(books.sortedLogs(updated).first.pages, 25);
      expect(books.roundProgress(store.books.single, updated), 40);
    });

    test('历史只保存起止时间和感想，编辑重排且感想可清空', () {
      final book = store.addBook(BookInput(title: '历史'));
      for (final year in [2000, 2005]) {
        store.addPastRound(
            book.id,
            PastRoundInput(
                startedAt: DateTime(year),
                finishedAt: DateTime(year, 2),
                note: '感想 $year'));
      }
      final older = books.allRounds(store.books.single).last;
      expect(older.logs, isEmpty);
      store.updateRound(book.id, older.id,
          startedAt: DateTime(2010),
          finishedAt: DateTime(2010, 2),
          note: '修订感想');
      final newest = books.allRounds(store.books.single).first;
      expect(newest.id, older.id);
      expect(newest.index, 2);
      expect(newest.logs, isEmpty);
      expect(books.roundProgress(store.books.single, newest), 0);
      expect(ReadingRound.fromJson(newest.toJson()).note, '修订感想');
      store.updateRound(book.id, newest.id,
          startedAt: newest.startedAt, finishedAt: newest.finishedAt, note: '');
      expect(books.roundReflection(books.allRounds(store.books.single).first),
          isEmpty);
    });

    test('观影时间评分感想修改后重新排序且不增加次数', () {
      final movie = store.addMovie(MovieInput(title: '观影'));
      store.addWatch(movie.id, at: DateTime(2000), rating: 2, note: '旧');
      store.addWatch(movie.id, at: DateTime(2005), rating: 3);
      final old = movies.sortedWatches(store.movies.single).last;
      store.updateWatch(movie.id, old.id,
          at: DateTime(2010), rating: 5, note: '新');
      final latest = movies.sortedWatches(store.movies.single).first;
      expect(store.movies.single.watches.length, 2);
      expect(latest.id, old.id);
      expect(latest.at, DateTime(2010));
      expect(latest.rating, 5);
      expect(latest.note, '新');
    });
  });
}
