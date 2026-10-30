import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/domain/books.dart' as bl;
import 'package:shuying/models/models.dart';
import 'package:shuying/pages/home_shell.dart';
import 'package:shuying/pages/book_detail_page.dart';
import 'package:shuying/pages/stats_page.dart';
import 'package:shuying/pages/usage_guide_page.dart';
import 'package:shuying/services/backup_codec.dart';
import 'package:shuying/services/pro_store.dart';
import 'package:shuying/store/app_store.dart';
import 'package:shuying/widgets/bits.dart';
import 'package:shuying/widgets/book_tile.dart';
import 'package:shuying/widgets/sheets.dart';
import 'review_regression_test.dart' show harness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('在读与再次阅读卡片只显示本轮优先数据，重读标明次数', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    final at = DateTime(2026, 10, 1);
    for (final index in [1, 2]) {
      Future<void> show(List<ReadingLog> logs) async {
        final book = Book(
          id: 'reading',
          title: '阅读中的书',
          totalPages: 100,
          createdAt: at,
          updatedAt: at,
          rounds: [
            if (index > 1)
              ReadingRound(
                  id: 'history',
                  index: 1,
                  startedAt: DateTime(2025),
                  finishedAt: DateTime(2025, 2),
                  pages: 900,
                  minutes: 900),
            ReadingRound(
                id: 'current', index: index, startedAt: at, logs: logs),
          ],
        );
        await tester.pumpWidget(harness(
            Scaffold(body: BookTile(book: book, onTap: () {})), store, pro,
            scale: 1.4));
        await tester.pumpAndSettle();
        expect(find.text(index == 1 ? '在读' : '第2次阅读'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await show([
        ReadingLog(
            id: 'time-only', at: at.add(const Duration(days: 3)), minutes: 15),
        ReadingLog(
            id: 'old', at: at.add(const Duration(days: 1)), progress: 20),
        ReadingLog(
            id: 'new',
            at: at.add(const Duration(days: 2)),
            progress: 45,
            pages: 40,
            minutes: 30),
      ]);
      expect(find.text('阅读进度 45%'), findsOneWidget);
      expect(find.textContaining('已阅读'), findsNothing);

      // 有总页数也不把未填写的百分比当成已填写进度；不混入历史轮次。
      await show([
        ReadingLog(id: 'p1', at: at, pages: 12, minutes: 30),
        ReadingLog(
            id: 'p2',
            at: at.add(const Duration(days: 1)),
            pages: 8,
            minutes: 15),
      ]);
      expect(find.text('已阅读 20 页'), findsOneWidget);
      expect(find.textContaining('阅读进度'), findsNothing);
      expect(find.byType(ProgressBar), findsNothing);
      expect(find.textContaining('45分钟'), findsNothing);

      await show([
        ReadingLog(id: 'm1', at: at, minutes: 10),
        ReadingLog(id: 'm2', at: at.add(const Duration(days: 1)), minutes: 20),
      ]);
      expect(find.text('已阅读 30分钟'), findsOneWidget);
      await show([]);
      expect(find.text('已阅读 0分钟'), findsOneWidget);
      await show([
        ReadingLog(id: 'zero', at: at, progress: 0, pages: 10, minutes: 10)
      ]);
      expect(find.text('阅读进度 0%'), findsOneWidget);
      expect(find.textContaining('已阅读'), findsNothing);
    }
  });

  testWidgets('详情显示三项本轮累计，直接修正总数不改动单次或进度', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    final book = store.addBook(BookInput(title: '累计与单次', totalPages: 200),
        initialStatus: BookStatus.reading, readPages: 50, readMinutes: 70);
    final round = book.rounds.single;
    store.addLog(
        book.id,
        round.id,
        LogInput(
            at: DateTime.now().add(const Duration(minutes: 1)), progress: 40));
    final originalLogs = store.books.single.rounds.single.logs;
    await tester
        .pumpWidget(harness(BookDetailPage(bookId: book.id), store, pro));
    await tester.pumpAndSettle();
    expect(find.text('本轮累计进度'), findsOneWidget);
    expect(find.text('本轮累计页数'), findsOneWidget);
    expect(find.text('本轮累计时长'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('edit-reading-totals')));
    await tester.tap(find.byKey(const Key('edit-reading-totals')));
    await tester.pumpAndSettle();
    Finder field(String key) => find.descendant(
        of: find.byKey(Key(key)), matching: find.byType(TextField));
    await tester.ensureVisible(field('round-total-pages'));
    await tester.enterText(field('round-total-pages'), '15');
    await tester.enterText(field('round-total-minutes'), '20');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    final updated = store.books.single.rounds.single;
    expect(bl.roundPages(updated), 15);
    expect(bl.roundMinutes(updated), 20);
    expect(updated.logs, originalLogs);
    expect(find.text('40%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('新书三种初始状态一次保存，四个分类互斥，非法初始进度不新增书籍', () {
    final store = AppStore();
    addTearDown(store.dispose);
    final want = store.addBook(BookInput(title: '想读书'));
    final reading = store.addBook(BookInput(title: '在读书', totalPages: 100),
        initialStatus: BookStatus.reading, readPages: 25, readMinutes: 40);
    final finished = store.addBook(BookInput(title: '读过的书'),
        initialStatus: BookStatus.finished);
    final reread = store.addBook(BookInput(title: '再读的书'),
        initialStatus: BookStatus.finished);
    store.startReading(reread.id);
    expect(bl.bookStatus(want), BookStatus.want);
    expect(bl.bookStatus(reading), BookStatus.reading);
    expect(bl.bookStatus(finished), BookStatus.finished);
    expect(bl.bookStatus(store.bookById(reread.id)!), BookStatus.rereading);
    expect(bl.roundProgress(reading, bl.activeRound(reading)), 25);
    expect(bl.bookSummary(reading).totalPages, 25);
    expect(bl.bookSummary(reading).totalMinutes, 40);
    for (final status in BookStatus.values) {
      expect(store.books.where((b) => bl.bookStatus(b) == status).length, 1);
    }
    expect(
        () => store.addBook(BookInput(title: '错误', totalPages: 100),
            initialStatus: BookStatus.reading, readPages: 101),
        throwsArgumentError);
    expect(store.books.length, 4);
    final restored = decodeBackup(store.exportJson());
    expect(
        bl
            .bookSummary(restored.books.firstWhere((b) => b.id == reading.id))
            .totalMinutes,
        40);
  });

  testWidgets('新书表单可选在读并录入页数时长，编辑资料不重置分类', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    Book? editing;
    await tester.pumpWidget(harness(
        Scaffold(
            body: Builder(
                builder: (ctx) => TextButton(
                    onPressed: () => showBookSheet(ctx, book: editing),
                    child: const Text('打开表单')))),
        store,
        pro));
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '已有阅读进度');
    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.hintText == '例如：191'),
        '100');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('在读'), 160,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('在读'));
    await tester.pumpAndSettle();
    final pages = find.descendant(
        of: find.byKey(const Key('book-initial-pages')),
        matching: find.byType(TextField));
    final minutes = find.descendant(
        of: find.byKey(const Key('book-initial-minutes')),
        matching: find.byType(TextField));
    await tester.ensureVisible(pages);
    await tester.enterText(pages, '25');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(minutes);
    await tester.enterText(minutes, '40');
    await tester.tap(find.text('加入书架'));
    await tester.pumpAndSettle();
    expect(bl.bookStatus(store.books.single), BookStatus.reading);
    expect(bl.bookSummary(store.books.single).totalPages, 25);
    expect(bl.bookSummary(store.books.single).totalMinutes, 40);
    editing = store.books.single;
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('book-initial-status')), findsNothing);
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(bl.bookStatus(store.books.single), BookStatus.reading);
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计范围同时切换汇总、周图表、正在读和动态', (tester) async {
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    store.addBook(BookInput(title: '范围书', totalPages: 100),
        initialStatus: BookStatus.reading, readPages: 25, readMinutes: 40);
    final movie = store.addMovie(MovieInput(title: '范围电影'));
    store.addWatch(movie.id, at: DateTime.now(), rating: 8);
    store.addWatch(movie.id, at: DateTime.now());
    await tester
        .pumpWidget(harness(const Scaffold(body: StatsPage()), store, pro));
    await tester.tap(find.text('只统计电影'));
    await tester.pumpAndSettle();
    expect(find.text('阅读时长'), findsNothing);
    expect(find.text('累计页数'), findsNothing);
    expect(find.text('正在读'), findsNothing);
    expect(find.textContaining('范围书'), findsNothing);
    expect(find.text('近 7 天阅读时长'), findsNothing);
    expect(find.text('近 7 天观影次数'), findsOneWidget);
    final cells = tester.widgetList<StatCell>(find.byType(StatCell));
    expect(cells.firstWhere((c) => c.label == '观影次数').value, '2');
    expect(cells.firstWhere((c) => c.label == '平均分 /10').value, '8.0');
    await tester.tap(find.text('只统计书籍'));
    await tester.pumpAndSettle();
    expect(find.text('阅读时长'), findsOneWidget);
    expect(find.text('电影收藏'), findsNothing);
    expect(find.text('观影次数'), findsNothing);
    expect(find.textContaining('范围电影'), findsNothing);
    expect(find.text('近 7 天观影次数'), findsNothing);
    expect(find.text('近 7 天阅读时长'), findsOneWidget);
    expect(find.text('正在读'), findsOneWidget);
    await tester.tap(find.text('都统计'));
    await tester.pumpAndSettle();
    expect(find.text('电影收藏'), findsOneWidget);
    expect(find.text('累计页数'), findsOneWidget);
    expect(find.textContaining('📖 范围书'), findsOneWidget);
    expect(find.textContaining('🎬 范围电影'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('设置可进入简明使用说明，介绍四类书籍和三类电影', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    await tester
        .pumpWidget(harness(const HomeShell(initialIndex: 3), store, pro));
    await tester.scrollUntilVisible(find.text('使用说明'), 150,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用说明'));
    await tester.pumpAndSettle();
    expect(find.byType(UsageGuidePage), findsOneWidget);
    expect(find.text('书籍的四类状态'), findsOneWidget);
    expect(find.text('电影的三类状态'), findsOneWidget);
    expect(find.textContaining('恰好有一次观影记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
