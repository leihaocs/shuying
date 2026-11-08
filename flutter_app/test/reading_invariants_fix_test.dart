import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/domain/books.dart' as books;
import 'package:shuying/models/models.dart';
import 'package:shuying/store/app_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppStore store;
  final firstAt = DateTime(2026, 1, 1, 12);
  final lastAt = DateTime(2026, 1, 2, 12);

  Book mixedProgressBook() {
    final book = store.addBook(BookInput(title: '原书名', totalPages: 100));
    store.startReading(book.id);
    final roundId = store.bookById(book.id)!.rounds.single.id;
    store.addLog(
        book.id, roundId, LogInput(at: firstAt, pages: 50, minutes: 10));
    store.addLog(book.id, roundId, LogInput(at: lastAt, progress: 60));
    return store.bookById(book.id)!;
  }

  Book finishedBook() {
    final book = mixedProgressBook();
    store.finishRound(book.id, book.rounds.single.id);
    return store.bookById(book.id)!;
  }

  setUp(() => store = AppStore());
  tearDown(() => store.dispose());

  group('修改书籍总页数', () {
    test('重新推导后进度倒退时整体拒绝，书籍资料与记录不部分保存', () {
      final book = mixedProgressBook();
      final before = book.toJson();

      expect(
        () => store.updateBook(
            book.id, BookInput(title: '不能部分保存', totalPages: 50)),
        throwsA(isA<ArgumentError>().having(
            (error) => error.message, 'message', contains('100% → 60%'))),
      );

      expect(store.bookById(book.id)!.toJson(), before);
    });

    test('合法更正总页数后重新推导进度，累计校正和单次量保持独立', () {
      final book = mixedProgressBook();
      final round = book.rounds.single;
      store.updateRound(book.id, round.id,
          startedAt: firstAt, note: '', pages: 30, minutes: 5);
      final originalLogs = store
          .bookById(book.id)!
          .rounds
          .single
          .logs
          .map((log) => log.toJson())
          .toList();

      store.updateBook(book.id, BookInput(title: '更正后书名', totalPages: 200));

      final updated = store.bookById(book.id)!;
      final updatedRound = updated.rounds.single;
      expect(updated.title, '更正后书名');
      expect(updated.totalPages, 200);
      expect(
          books.readingProgresses(
              updated, books.sortedLogs(updatedRound).reversed),
          [25, 60]);
      expect(updatedRound.pages, 30);
      expect(updatedRound.minutes, 5);
      expect(updatedRound.logs.map((log) => log.toJson()), originalLogs);
    });

    test('已完成轮次不重新解释或限制历史进度', () {
      final book = finishedBook();
      final originalLogs =
          book.rounds.single.logs.map((log) => log.toJson()).toList();

      store.updateBook(book.id, BookInput(title: '历史书', totalPages: 50));

      final updated = store.bookById(book.id)!;
      expect(updated.totalPages, 50);
      expect(
          updated.rounds.single.logs.map((log) => log.toJson()), originalLogs);
    });
  });

  group('历史轮次起止范围', () {
    test('开始时间不能排除已有最早明细，拒绝时不保存累计和感想', () {
      final book = finishedBook();
      final before = book.toJson();

      expect(
        () => store.updateRound(book.id, book.rounds.single.id,
            startedAt: firstAt.add(const Duration(minutes: 1)),
            note: '不能部分保存',
            pages: 1,
            minutes: 1),
        throwsA(isA<ArgumentError>().having(
            (error) => error.message, 'message', contains('开始时间不能晚于本轮最早阅读记录'))),
      );

      expect(store.bookById(book.id)!.toJson(), before);
    });

    test('结束时间不能排除已有最后明细，拒绝时保留原始记录时间', () {
      final book = finishedBook();
      final before = book.toJson();

      expect(
        () => store.updateRound(book.id, book.rounds.single.id,
            startedAt: firstAt,
            finishedAt: lastAt.subtract(const Duration(minutes: 1)),
            note: ''),
        throwsA(isA<ArgumentError>().having(
            (error) => error.message, 'message', contains('结束时间不能早于本轮最后阅读记录'))),
      );

      expect(store.bookById(book.id)!.toJson(), before);
    });

    test('起止等于明细时间有效，累计可向下更正且不改明细', () {
      final book = finishedBook();
      final originalLogs =
          book.rounds.single.logs.map((log) => log.toJson()).toList();

      store.updateRound(book.id, book.rounds.single.id,
          startedAt: firstAt,
          finishedAt: lastAt,
          note: '完成感想',
          pages: 0,
          minutes: 0);

      final round = store.bookById(book.id)!.rounds.single;
      expect(round.startedAt, firstAt);
      expect(round.finishedAt, lastAt);
      expect(round.note, '完成感想');
      expect(books.roundPages(round), 0);
      expect(books.roundMinutes(round), 0);
      expect(round.logs.map((log) => log.toJson()), originalLogs);
    });

    test('没有逐次明细的历史轮次仍可合法修改起止日期', () {
      final book = store.addBook(BookInput(title: '仅历史累计'));
      store.addPastRound(
          book.id, PastRoundInput(startedAt: firstAt, finishedAt: lastAt));
      final roundId = store.bookById(book.id)!.rounds.single.id;
      final newStart = DateTime(2025, 1, 1);
      final newEnd = DateTime(2025, 1, 2);

      store.updateRound(book.id, roundId,
          startedAt: newStart, finishedAt: newEnd, note: '修正日期');

      final round = store.bookById(book.id)!.rounds.single;
      expect(round.startedAt, newStart);
      expect(round.finishedAt, newEnd);
      expect(round.logs, isEmpty);
    });
  });
}
