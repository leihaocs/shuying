import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuying/models/models.dart';
import 'package:shuying/pages/books_page.dart';
import 'package:shuying/pages/home_shell.dart';
import 'package:shuying/pages/movies_page.dart';
import 'package:shuying/services/pro_store.dart';
import 'package:shuying/store/app_store.dart';
import 'package:shuying/widgets/book_tile.dart';
import 'package:shuying/widgets/library_filters.dart';
import 'package:shuying/widgets/movie_tile.dart';
import 'package:shuying/widgets/sheets.dart';

import 'review_regression_test.dart' show harness;

Future<void> choose(WidgetTester tester, String key, String label) async {
  final control = find.byKey(Key(key));
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> category(WidgetTester tester, String label) async {
  final item = find.descendant(
      of: find.byType(SegmentedBar), matching: find.text(label));
  await tester.ensureVisible(item);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('标签解析兼容中英文逗号，去空白与重复；旧模型JSON默认空标签', () {
    expect(parseTags(' 科幻, SCI-FI，科幻, sci-fi, , '), ['科幻', 'SCI-FI']);
    final now = DateTime(2026, 1, 1);
    final oldBook = Book(id: 'b', title: '旧书', createdAt: now, updatedAt: now);
    final oldMovie =
        Movie(id: 'm', title: '旧片', createdAt: now, updatedAt: now);
    expect(Book.fromJson(oldBook.toJson()).tags, isEmpty);
    expect(Movie.fromJson(oldMovie.toJson()).tags, isEmpty);
    final book = oldBook.copyWith(tags: parseTags('小说,收藏'));
    final movie = oldMovie.copyWith(tags: parseTags('剧情,收藏'));
    expect(
        Book.fromJson(book.toJson()).copyWith(title: '改名').tags, ['小说', '收藏']);
    expect(Movie.fromJson(movie.toJson()).copyWith(title: '改名').tags,
        ['剧情', '收藏']);
  });

  test('评分筛选区分全部、未评分和包含边界的评分下限', () {
    expect(matchesRating(null, null), isTrue);
    expect(matchesRating(10, null), isTrue);
    expect(matchesRating(null, 0), isTrue);
    expect(matchesRating(1, 0), isFalse);
    expect(matchesRating(null, 8), isFalse);
    expect(matchesRating(7, 8), isFalse);
    expect(matchesRating(8, 8), isTrue);
    expect(matchesRating(10, 8), isTrue);
  });

  test('标签保存到本机并可重新载入；未传不丢失，显式空列表清除', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp('shuying-tags-');
    addTearDown(() => directory.delete(recursive: true));
    final store = AppStore(dataDirectory: directory.path, seedDemoData: false);
    await store.load();
    final inputTags = [' 科幻 ', 'SCI-FI', 'sci-fi'];
    final book = store.addBook(BookInput(title: '标签书', tags: inputTags));
    final movie = store.addMovie(MovieInput(title: '标签电影', tags: ['剧情']));
    inputTags.add('调用方后来改动');
    store.updateBook(book.id, BookInput(title: '标签书改名'));
    store.updateMovie(movie.id, MovieInput(title: '标签电影改名'));
    expect(await store.flush(), isTrue);
    store.dispose();

    final restored =
        AppStore(dataDirectory: directory.path, seedDemoData: false);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.loadFailed, isFalse);
    expect(restored.books.single.tags, ['科幻', 'SCI-FI']);
    expect(restored.movies.single.tags, ['剧情']);
    restored.updateBook(book.id, BookInput(title: '清除标签', tags: []));
    restored.updateMovie(movie.id, MovieInput(title: '清除标签', tags: []));
    expect(restored.books.single.tags, isEmpty);
    expect(restored.movies.single.tags, isEmpty);
    expect(await restored.flush(), isTrue);
  });

  group('免费标签和评分筛选', () {
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

    testWidgets('书籍标签、评分、搜索、状态叠加；重置只清标签评分，全库计数不变', (tester) async {
      await tester.binding.setSurfaceSize(const Size(440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final target = store.addBook(
          BookInput(title: 'Needle 高分', rating: 9, tags: ['科幻']),
          initialStatus: BookStatus.reading);
      final low = store.addBook(
          BookInput(title: 'Needle 低分', rating: 5, tags: ['科幻']),
          initialStatus: BookStatus.reading);
      final unrated = store.addBook(
          BookInput(title: 'Needle 未评分', tags: ['现实']),
          initialStatus: BookStatus.reading);
      store.addBook(BookInput(title: 'Needle 已读', rating: 10, tags: ['科幻']),
          initialStatus: BookStatus.finished);
      await tester
          .pumpWidget(harness(const Scaffold(body: BooksPage()), store, pro));
      List<String> ids() => tester
          .widgetList<BookTile>(find.byType(BookTile))
          .map((tile) => tile.book.id)
          .toList();
      await category(tester, '在读');
      await choose(tester, 'tag-filter', '科幻');
      await choose(tester, 'rating-filter', '8 分及以上');
      await tester.enterText(find.byKey(const Key('book-search')), 'needle');
      await tester.pumpAndSettle();
      expect(ids(), [target.id]);
      expect(
          tester
              .widget<SegmentedBar>(find.byType(SegmentedBar))
              .items
              .map((item) => item.count),
          [4, 0, 3, 0, 1]);
      await tester.enterText(find.byKey(const Key('book-search')), '低分');
      await tester.pumpAndSettle();
      expect(ids(), isEmpty);
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pumpAndSettle();
      expect(ids(), [target.id]);
      await tester.tap(find.byKey(const Key('reset-library-filters')));
      await tester.pumpAndSettle();
      expect(ids(), unorderedEquals([target.id, low.id, unrated.id]));
      await choose(tester, 'rating-filter', '未评分');
      expect(ids(), [unrated.id]);
      expect(pro.isPro, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('电影按实际最近一次观影评分筛选，未评分不会沿用较早评分', (tester) async {
      await tester.binding.setSurfaceSize(const Size(440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final target = store.addMovie(MovieInput(title: '目标电影', tags: ['科幻']));
      store.addWatch(target.id, at: DateTime(2026, 1, 1), rating: 10);
      store.addWatch(target.id, at: DateTime(2026, 1, 2), rating: 8);
      final unrated =
          store.addMovie(MovieInput(title: '最近未评分电影', tags: ['科幻']));
      store.addWatch(unrated.id, at: DateTime(2026, 1, 3));
      store.addWatch(unrated.id, at: DateTime(2026, 1, 1), rating: 10);
      final once = store.addMovie(MovieInput(title: '一次电影', tags: ['科幻']));
      store.addWatch(once.id, at: DateTime(2026, 1, 1), rating: 5);
      store.addMovie(MovieInput(title: '想看电影', tags: ['科幻']));
      await tester
          .pumpWidget(harness(const Scaffold(body: MoviesPage()), store, pro));
      List<String> ids() => tester
          .widgetList<MovieTile>(find.byType(MovieTile))
          .map((tile) => tile.movie.id)
          .toList();
      await category(tester, '多次观看');
      await choose(tester, 'tag-filter', '科幻');
      await choose(tester, 'rating-filter', '8 分及以上');
      await tester.enterText(find.byKey(const Key('movie-search')), '电影');
      await tester.pumpAndSettle();
      expect(ids(), [target.id]);
      expect(find.text('最近观影评分'), findsOneWidget);
      await choose(tester, 'rating-filter', '未评分');
      expect(ids(), [unrated.id]);
      await tester.tap(find.byKey(const Key('reset-library-filters')));
      await tester.pumpAndSettle();
      expect(ids(), unorderedEquals([target.id, unrated.id]));
      expect(
          tester
              .widget<SegmentedBar>(find.byType(SegmentedBar))
              .items
              .map((item) => item.count),
          [4, 1, 1, 2]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('书影表单可添加、重新编辑和清除逗号分隔标签', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late BuildContext host;
      await tester
          .pumpWidget(harness(Scaffold(body: Builder(builder: (context) {
        host = context;
        return const SizedBox();
      })), store, pro));
      for (final reading in [true, false]) {
        if (reading) {
          unawaited(showBookSheet(host));
        } else {
          unawaited(showMovieSheet(host));
        }
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '标签测试');
        final tags = find.byKey(Key(reading ? 'book-tags' : 'movie-tags'));
        await tester.ensureVisible(tags);
        await tester.enterText(tags, ' 收藏， SCI-FI, sci-fi ');
        await tester.tap(find.text(reading ? '加入书架' : '加入片单'));
        await tester.pumpAndSettle();
        expect(reading ? store.books.single.tags : store.movies.single.tags,
            ['收藏', 'SCI-FI']);
        if (reading) {
          unawaited(showBookSheet(host, book: store.books.single));
        } else {
          unawaited(showMovieSheet(host, movie: store.movies.single));
        }
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(tags).controller!.text, '收藏, SCI-FI');
        await tester.ensureVisible(tags);
        await tester.enterText(tags, '');
        await tester.tap(find.text('保存修改'));
        await tester.pumpAndSettle();
        expect(reading ? store.books.single.tags : store.movies.single.tags,
            isEmpty);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('320px大字与170px横屏可用高度下筛选控件仍可滚动操作', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      store.addBook(
          BookInput(title: '窄屏书籍', rating: 9, tags: ['很长的自定义标签用于窄屏验证']));
      store.addMovie(MovieInput(title: '窄屏电影', tags: ['很长的自定义标签用于窄屏验证']));
      for (final size in [const Size(320, 640), const Size(844, 390)]) {
        await tester.binding.setSurfaceSize(size);
        for (final page in [const BooksPage(), const MoviesPage()]) {
          await tester.pumpWidget(harness(
              Scaffold(
                  body: size.width > 600
                      ? SizedBox(height: 170, child: page)
                      : page),
              store,
              pro,
              scale: 1.5));
          await tester.pumpAndSettle();
          await choose(tester, 'rating-filter', '未评分');
          final reset = find.byKey(const Key('reset-library-filters'));
          await tester.ensureVisible(reset);
          await tester.pumpAndSettle();
          await tester.tap(reset);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '$size ${page.runtimeType}');
          await tester.pumpWidget(const SizedBox());
        }
      }
    });
  });
}
