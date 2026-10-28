import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/domain/fmt.dart';
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
        () => store.addLog(
            book.id, roundId, LogInput(at: atDayAgo(1), pages: 5)),
        throwsStateError,
      );
    });
  });
}
