import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:shuying/domain/fmt.dart';
import 'package:shuying/models/models.dart';
import 'package:shuying/pages/home_shell.dart';
import 'package:shuying/pages/movies_page.dart';
import 'package:shuying/pages/stats_page.dart';
import 'package:shuying/pages/settings_page.dart';
import 'package:shuying/pages/book_detail_page.dart';
import 'package:shuying/services/backup_codec.dart';
import 'package:shuying/services/pro_store.dart';
import 'package:shuying/store/app_store.dart';
import 'package:shuying/theme/app_theme.dart';
import 'package:shuying/widgets/bits.dart';
import 'review_regression_test.dart' show harness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('旧五星评分只换算一次，新十分制评分与书籍评分备份保持原值', () {
    final now = DateTime(2026, 10, 1);
    final movie =
        Movie(id: 'old', title: '旧电影', createdAt: now, updatedAt: now).toJson();
    movie['watches'] = [
      {'id': 'watch', 'at': isoOf(now), 'rating': 4}
    ];
    final old = jsonEncode({
      'app': 'bookmovie_revisit',
      'schema': 1,
      'books': [],
      'movies': [movie]
    });
    final store = AppStore();
    addTearDown(store.dispose);
    store.importJson(old);
    expect(store.movies.single.watches.single.rating, 8);
    store.addWatch('old', at: now, rating: 3);
    final book = store.addBook(BookInput(title: '十分制书籍', rating: 9));
    final backup = store.exportJson();
    expect(jsonDecode(backup)['schema'], 2);
    final restored = decodeBackup(backup);
    expect(restored.movies.single.watches.map((w) => w.rating), [8, 3]);
    expect(restored.books.single.rating, 9);
    store.rateBook(book.id, null);
    expect(store.books.single.rating, isNull);
    expect(() => store.rateBook(book.id, 11), throwsRangeError);
    expect(() => store.addWatch('old', at: now, rating: 0), throwsRangeError);
    final invalid = jsonDecode(backup) as Map<String, dynamic>;
    invalid['movies'][0]['watches'][0]['rating'] = 11;
    expect(() => decodeBackup(jsonEncode(invalid)), throwsFormatException);
  });

  test('升级后的评分和随系统主题重启后保持，五星旧本地记录自动迁移', () async {
    final directory =
        await Directory.systemTemp.createTemp('shuying-features-');
    SharedPreferences.setMockInitialValues({'shuying.theme.v1': 'dark'});
    final now = DateTime(2026, 10, 1);
    final movie =
        Movie(id: 'old', title: '旧电影', createdAt: now, updatedAt: now).toJson();
    movie['watches'] = [
      {'id': 'watch', 'at': isoOf(now), 'rating': 5}
    ];
    await File('${directory.path}/state.v1.json').writeAsString(jsonEncode({
      'books': [],
      'movies': [movie]
    }));
    final stores = <AppStore>[];
    addTearDown(() async {
      for (final store in stores) {
        await store.flush();
        store.dispose();
      }
      await directory.delete(recursive: true);
    });
    Future<AppStore> load() async {
      final store =
          AppStore(dataDirectory: directory.path, seedDemoData: false);
      stores.add(store);
      await store.load();
      expect(store.loadFailed, isFalse);
      return store;
    }

    final first = await load();
    expect(first.themeMode, ThemeMode.dark);
    expect(first.movies.single.watches.single.rating, 10);
    first.setThemeMode(ThemeMode.system);
    first.addBook(BookInput(title: '评分持久化', rating: 7));
    expect(await first.flush(), isTrue);
    final second = await load();
    expect(second.themeMode, ThemeMode.system);
    expect(second.movies.single.watches.single.rating, 10);
    expect(second.books.single.rating, 7);
  });

  testWidgets('四个固定Tab：设置最右，无返回箭头和添加按钮，切回电影可添加', (tester) async {
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    await tester.pumpWidget(harness(const HomeShell(), store, pro));
    expect(tester.getCenter(find.text('设置')).dx,
        greaterThan(tester.getCenter(find.text('统计')).dx));
    expect(find.byTooltip('设置 / 关于'), findsNothing);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('主题模式'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(NavBar),
            matching: find.byIcon(Icons.arrow_back_ios_new_rounded)),
        findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    await tester.tap(find.text('电影'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('多次观看分类随新增和删除记录实时更新', (tester) async {
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    final repeated = store.addMovie(MovieInput(title: '重看电影'));
    final once = store.addMovie(MovieInput(title: '只看一次'));
    store.addWatch(repeated.id, at: DateTime(2025), rating: 9);
    store.addWatch(repeated.id, at: DateTime(2026), rating: 8);
    store.addWatch(once.id, at: DateTime(2026));
    await tester.pumpWidget(harness(const MoviesPage(), store, pro));
    await tester.tap(find.text('已看'));
    await tester.pumpAndSettle();
    expect(find.text('重看电影'), findsNothing);
    expect(find.text('只看一次'), findsOneWidget);
    await tester.tap(find.text('多次观看'));
    await tester.pumpAndSettle();
    expect(find.text('重看电影'), findsOneWidget);
    expect(find.text('只看一次'), findsNothing);
    expect(find.text('8/10'), findsOneWidget);
    store.removeWatch(
        repeated.id, store.movieById(repeated.id)!.watches.last.id);
    await tester.pumpAndSettle();
    expect(find.text('重看电影'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('最近动态可切换日期，每条显示时分，指定日期不截断为八条', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    final movie = store.addMovie(MovieInput(title: '昨天的电影'));
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    for (var i = 0; i < 9; i++) {
      store.addWatch(movie.id,
          at: DateTime(
              yesterday.year, yesterday.month, yesterday.day, 8 + i, 35),
          rating: 10);
    }
    await tester
        .pumpWidget(harness(const Scaffold(body: StatsPage()), store, pro));
    await tester.scrollUntilVisible(
        find.byKey(const Key('activity-pick-date')), 150,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    await tester.tap(find.text('昨天'));
    await tester.pumpAndSettle();
    expect(find.text(formatDate(yesterday)), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-previous-day')));
    await tester.pumpAndSettle();
    expect(find.text('这一天还没有阅读或观影记录。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-next-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-pick-date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    final oldest = formatDateTime(
        DateTime(yesterday.year, yesterday.month, yesterday.day, 8, 35));
    await tester.scrollUntilVisible(find.text(oldest), 200,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    expect(find.text(oldest), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('书籍可直接评分并清除，十分制选择在窄屏不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    final book = store.addBook(BookInput(title: '评分测试'));
    await tester.pumpWidget(
        harness(BookDetailPage(bookId: book.id), store, pro, scale: 1.4));
    await tester.scrollUntilVisible(find.byType(RatingPicker), 100);
    expect(tester.getSize(find.byType(RatingPicker)).height, lessThan(80));
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('10 分'), 100,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('10 分').last);
    await tester.pumpAndSettle();
    expect(store.books.single.rating, 10);
    await tester.tap(find.text('清除评分'));
    await tester.pumpAndSettle();
    expect(store.books.single.rating, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('主题随系统明暗变化，也能手动固定浅色', (tester) async {
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: pro),
        ],
        child: Builder(
            builder: (context) => MaterialApp(
                  theme: AppTheme.light(),
                  darkTheme: AppTheme.dark(),
                  themeMode: context.watch<AppStore>().themeMode,
                  home: const SettingsPage(asTab: true),
                ))));
    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('随系统'));
    await tester.pumpAndSettle();
    expect(store.themeMode, ThemeMode.system);
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('主题模式'))).brightness,
        Brightness.dark);
    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('浅色').last);
    await tester.pumpAndSettle();
    expect(store.themeMode, ThemeMode.light);
    expect(Theme.of(tester.element(find.text('主题模式'))).brightness,
        Brightness.light);
  });
}
