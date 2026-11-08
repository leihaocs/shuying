import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/domain/year_review.dart';
import 'package:shuying/models/models.dart';
import 'package:shuying/pages/books_page.dart';
import 'package:shuying/pages/home_shell.dart';
import 'package:shuying/pages/monthly_review_page.dart';
import 'package:shuying/pages/movies_page.dart';
import 'package:shuying/pages/pro_page.dart';
import 'package:shuying/pages/stats_page.dart';
import 'package:shuying/services/pro_store.dart';
import 'package:shuying/store/app_store.dart';
import 'package:shuying/widgets/book_tile.dart';
import 'package:shuying/widgets/movie_tile.dart';

import 'review_regression_test.dart' show harness;

Future<void> selectCategory(WidgetTester tester, String label) async {
  final item = find.descendant(
      of: find.byType(SegmentedBar), matching: find.text(label));
  await tester.ensureVisible(item);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('书影搜索', () {
    late AppStore store;
    late ProStore pro;

    setUp(() {
      store = AppStore();
      pro = ProStore();
    });
    tearDown(() {
      store.dispose();
      pro.dispose();
    });

    testWidgets('书籍按书名作者版本备注搜索，和四个互斥分类叠加，清空保留分类', (tester) async {
      await tester.binding.setSurfaceSize(const Size(440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final target = store.addBook(BookInput(
          title: 'Needle Book',
          author: 'Writer Alpha',
          edition: 'First Edition',
          note: 'ShelfNote'));
      final reading = store.addBook(BookInput(title: '在读书'),
          initialStatus: BookStatus.reading);
      final rereading = store.addBook(BookInput(title: '重读书'),
          initialStatus: BookStatus.finished);
      store.startReading(rereading.id);
      final finished = store.addBook(BookInput(title: '读完书'),
          initialStatus: BookStatus.finished);
      await tester
          .pumpWidget(harness(const Scaffold(body: BooksPage()), store, pro));

      List<String> visibleIds() => tester
          .widgetList<BookTile>(find.byType(BookTile))
          .map((tile) => tile.book.id)
          .toList();
      final search = find.byKey(const Key('book-search'));
      for (final query in [
        '  nEeDlE  ',
        'writer alpha',
        'EDITION',
        'shelfnote'
      ]) {
        await tester.enterText(search, query);
        await tester.pumpAndSettle();
        expect(visibleIds(), [target.id], reason: query);
        expect(
            tester
                .widget<SegmentedBar>(find.byType(SegmentedBar))
                .items
                .map((item) => item.count),
            [4, 1, 1, 1, 1]);
      }
      await selectCategory(tester, '在读');
      expect(visibleIds(), isEmpty);
      expect(find.text('没有找到匹配的书籍'), findsOneWidget);
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(visibleIds(), [reading.id]);
      await selectCategory(tester, '再次阅读');
      expect(visibleIds(), [rereading.id]);
      await selectCategory(tester, '已读');
      expect(visibleIds(), [finished.id]);
      await selectCategory(tester, '想读');
      expect(visibleIds(), [target.id]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('电影按片名导演年份备注搜索，已看和多次观看互斥且计数不受搜索影响', (tester) async {
      await tester.binding.setSurfaceSize(const Size(440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final target = store.addMovie(MovieInput(
          title: 'Needle Film',
          director: 'Director Alpha',
          year: '1994',
          note: 'CinemaNote'));
      final once = store.addMovie(MovieInput(title: '看过一次'));
      store.addWatch(once.id, at: DateTime(2026, 1, 1));
      final twice = store.addMovie(MovieInput(title: '反复观看'));
      store.addWatch(twice.id, at: DateTime(2026, 1, 1));
      store.addWatch(twice.id, at: DateTime(2026, 1, 2));
      await tester
          .pumpWidget(harness(const Scaffold(body: MoviesPage()), store, pro));
      List<String> visibleIds() => tester
          .widgetList<MovieTile>(find.byType(MovieTile))
          .map((tile) => tile.movie.id)
          .toList();
      final search = find.byKey(const Key('movie-search'));
      for (final query in ['nEeDlE', 'DIRECTOR ALPHA', '1994', 'cinemanote']) {
        await tester.enterText(search, query);
        await tester.pumpAndSettle();
        expect(visibleIds(), [target.id], reason: query);
        expect(
            tester
                .widget<SegmentedBar>(find.byType(SegmentedBar))
                .items
                .map((item) => item.count),
            [3, 1, 1, 1]);
      }
      await selectCategory(tester, '已看');
      expect(visibleIds(), isEmpty);
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pumpAndSettle();
      expect(visibleIds(), [once.id]);
      await selectCategory(tester, '多次观看');
      expect(visibleIds(), [twice.id]);
      await selectCategory(tester, '想看');
      expect(visibleIds(), [target.id]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('横屏键盘压缩后170px可用高度仍可搜索，拖动收起键盘而不溢出', (tester) async {
      await tester.binding.setSurfaceSize(const Size(844, 390));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      store.addBook(BookInput(title: '键盘测试书'));
      store.addMovie(MovieInput(title: '键盘测试电影'));
      for (final page in [const BooksPage(), const MoviesPage()]) {
        await tester.pumpWidget(harness(
            Scaffold(body: SizedBox(height: 170, child: page)), store, pro,
            scale: 1.4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
        final search =
            find.byKey(Key(page is BooksPage ? 'book-search' : 'movie-search'));
        await tester.ensureVisible(search);
        await tester.enterText(search, '键盘测试');
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('月度回顾数据归属', () {
    final december = DateTime(2025, 12, 31, 23, 59, 59);
    final january = DateTime(2026, 1, 1);
    Book book(String id, ReadingRound round) => Book(
        id: id,
        title: id,
        createdAt: december,
        updatedAt: january,
        rounds: [round]);
    final books = [
      book(
          '全部累计已校正',
          ReadingRound(
              id: 'all',
              index: 1,
              startedAt: december,
              pages: 120,
              minutes: 60,
              logs: [
                ReadingLog(id: 'a-dec', at: december, pages: 40, minutes: 10),
                ReadingLog(id: 'a-jan', at: january, pages: 50, minutes: 20),
              ])),
      book(
          '仅校正页数',
          ReadingRound(
              id: 'pages',
              index: 1,
              startedAt: december,
              finishedAt: DateTime(2026, 1, 2),
              pages: 80,
              logs: [
                ReadingLog(id: 'b-dec', at: december, pages: 10, minutes: 7),
                ReadingLog(
                    id: 'b-jan',
                    at: DateTime(2026, 1, 2),
                    pages: 20,
                    minutes: 9),
              ])),
      book(
          '逐次明细',
          ReadingRound(id: 'logs', index: 1, startedAt: december, logs: [
            ReadingLog(id: 'c-dec', at: december, pages: 3, minutes: 4),
            ReadingLog(id: 'c-jan', at: january, pages: 5, minutes: 6),
          ])),
      book(
          '只有历史累计',
          ReadingRound(
              id: 'past',
              index: 1,
              startedAt: DateTime(2025, 12, 1),
              finishedAt: december,
              pages: 11,
              minutes: 13)),
    ];
    final movies = [
      Movie(
          id: 'repeat',
          title: '跨年观影',
          createdAt: december,
          updatedAt: january,
          watches: [
            WatchRecord(id: 'dec', at: december, rating: 8),
            WatchRecord(id: 'jan', at: january, rating: 6),
            WatchRecord(id: 'feb', at: DateTime(2026, 2, 1), rating: 10),
          ]),
      Movie(
          id: 'unrated',
          title: '未评分',
          createdAt: january,
          updatedAt: january,
          watches: [
            WatchRecord(id: 'end-jan', at: DateTime(2026, 1, 31, 23, 59, 59)),
          ]),
    ];

    test('月边界和跨年以实际本地日期过滤，累计覆盖不叠加单次量', () {
      final dec = YearReview(books, movies, 2025, month: 12);
      expect([dec.pages, dec.minutes, dec.readTimes, dec.readingDays],
          [14, 24, 1, 1]);
      expect([dec.watchTimes, dec.movieCount, dec.averageRating], [1, 1, 8]);
      final jan = YearReview(books, movies, 2026, month: 1);
      expect([jan.pages, jan.minutes, jan.readTimes, jan.readingDays],
          [205, 75, 1, 2]);
      expect([jan.watchTimes, jan.movieCount, jan.averageRating], [2, 2, 6]);
      expect(jan.monthlyMinutes, [75, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      expect(jan.monthlyWatches, [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      final feb = YearReview(books, movies, 2026, month: 2);
      expect([feb.pages, feb.minutes, feb.readTimes, feb.readingDays],
          [0, 0, 0, 0]);
      expect([feb.watchTimes, feb.movieCount, feb.averageRating], [1, 1, 10]);
    });

    test('年度汇总保持既有含义，未评分不参与平均分，空月份为零', () {
      final year = YearReview(books, movies, 2026);
      expect([year.pages, year.minutes, year.readTimes, year.readingDays],
          [205, 75, 1, 2]);
      expect([year.watchTimes, year.movieCount, year.averageRating], [3, 2, 8]);
      expect(year.monthlyWatches, [2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      final empty = YearReview(books, movies, 2026, month: 3);
      expect([empty.pages, empty.minutes, empty.readTimes, empty.watchTimes],
          [0, 0, 0, 0]);
      expect(empty.averageRating, isNull);
      expect(
          () => YearReview(books, movies, 2026, month: 0), throwsArgumentError);
      expect(() => YearReview(books, movies, 2026, month: 13),
          throwsArgumentError);
    });
  });

  group('免费月度回顾页面', () {
    late AppStore store;
    late ProStore pro;
    String? copied;
    final now = DateTime.now();

    setUp(() {
      store = AppStore();
      pro = ProStore();
      copied = null;
      final book = store.addBook(BookInput(title: '不应进入分享内容的书名'));
      store.addPastRound(
          book.id,
          PastRoundInput(
              startedAt: DateTime(now.year, now.month, 1),
              finishedAt: DateTime(now.year, now.month, 2),
              pages: 123,
              minutes: 45,
              note: '私人的阅读感想'));
      final movie = store.addMovie(MovieInput(title: '不应进入分享内容的片名'));
      store.addWatch(movie.id,
          at: DateTime(now.year, now.month, 3), rating: 8, note: '私人的观影感想');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ProStore.channel, (call) async {
        fail('免费月度回顾不应查询或调用购买接口：${call.method}');
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
    });
    tearDown(() {
      store.dispose();
      pro.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ProStore.channel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('未购买可查看和复制，仅书籍或仅电影不会混入另一范围', (tester) async {
      await tester.binding.setSurfaceSize(const Size(440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      expect(pro.isPro, isFalse);
      for (final onlyBooks in [true, false]) {
        await tester.pumpWidget(harness(
            MonthlyReviewPage(
                includeBooks: onlyBooks, includeMovies: !onlyBooks),
            store,
            pro));
        await tester.pumpAndSettle();
        expect(find.byType(ProPage), findsNothing);
        expect(find.text('阅读页数'), onlyBooks ? findsOneWidget : findsNothing);
        expect(find.text('观影次数'), onlyBooks ? findsNothing : findsOneWidget);
        await tester.ensureVisible(find.text('复制月度回顾'));
        await tester.tap(find.text('复制月度回顾'));
        await tester.pumpAndSettle();
        expect(copied, contains('${now.year} 年 ${now.month} 月'));
        expect(copied, contains(onlyBooks ? '阅读页数：123' : '平均评分 /10：8.0'));
        expect(copied, isNot(contains(onlyBooks ? '观影次数' : '阅读页数')));
        expect(copied, isNot(contains('不应进入分享内容')));
        expect(copied, isNot(contains('私人的')));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('统计范围传入月度回顾，年月可选择到上年十二月', (tester) async {
      await tester.binding.setSurfaceSize(const Size(440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final movie = store.addMovie(MovieInput(title: '上年十二月'));
      store.addWatch(movie.id,
          at: DateTime(now.year - 1, 12, 31, 23, 59), rating: 9);
      await tester
          .pumpWidget(harness(const Scaffold(body: StatsPage()), store, pro));
      await selectCategory(tester, '只统计电影');
      await tester.tap(find.byKey(const Key('open-monthly-review')));
      await tester.pumpAndSettle();
      final page =
          tester.widget<MonthlyReviewPage>(find.byType(MonthlyReviewPage));
      expect(page.includeBooks, isFalse);
      expect(page.includeMovies, isTrue);
      await tester.tap(find.byKey(const Key('review-year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${now.year - 1} 年').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review-month')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('12 月').last);
      await tester.tap(find.text('12 月').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('复制月度回顾'));
      await tester.tap(find.text('复制月度回顾'));
      await tester.pumpAndSettle();
      expect(copied, contains('${now.year - 1} 年 12 月'));
      expect(copied, contains('观影次数：1'));
      expect(copied, contains('平均评分 /10：9.0'));
      expect(copied, isNot(contains('阅读页数')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('320px 大字体下搜索和月度回顾可滚动操作且不溢出', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      store.addBook(BookInput(
          title: '很长的书名包含搜索词用于窄屏显示测试',
          author: '很长的作者名字',
          edition: '某出版社典藏修订版'));
      store.addMovie(MovieInput(
          title: '很长的电影标题包含搜索词用于窄屏显示测试', director: '很长的导演名字', year: '2026'));
      for (final page in [
        const BooksPage(),
        const MoviesPage(),
        const MonthlyReviewPage(),
        const MonthlyReviewPage(includeBooks: true, includeMovies: false),
        const MonthlyReviewPage(includeBooks: false, includeMovies: true)
      ]) {
        await tester.pumpWidget(harness(Scaffold(body: page), store, pro,
            padding: const EdgeInsets.fromLTRB(12, 40, 12, 24), scale: 1.5));
        await tester.pumpAndSettle();
        final search =
            find.byKey(Key(page is BooksPage ? 'book-search' : 'movie-search'));
        if (page is BooksPage || page is MoviesPage) {
          await tester.enterText(search, '搜索词');
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('清空搜索'));
          await tester.pumpAndSettle();
        } else {
          await tester.scrollUntilVisible(find.text('复制月度回顾'), 200,
              scrollable: find.byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down));
          await tester.tap(find.text('复制月度回顾'));
          await tester.pumpAndSettle();
          expect(copied, contains('月'));
        }
        expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
