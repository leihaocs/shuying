import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/domain/books.dart' as bl;
import 'package:shuying/models/models.dart';
import 'package:shuying/pages/home_shell.dart';
import 'package:shuying/pages/stats_page.dart';
import 'package:shuying/pages/usage_guide_page.dart';
import 'package:shuying/services/backup_codec.dart';
import 'package:shuying/services/pro_store.dart';
import 'package:shuying/store/app_store.dart';
import 'package:shuying/widgets/bits.dart';
import 'package:shuying/widgets/sheets.dart';
import 'review_regression_test.dart' show harness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
