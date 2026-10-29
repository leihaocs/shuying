import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shuying/pages/settings_page.dart';
import 'package:shuying/pages/data_backup_page.dart';
import 'package:shuying/pages/privacy_policy_page.dart';
import 'package:shuying/pages/privacy_consent_gate.dart';
import 'package:shuying/pages/books_page.dart';
import 'package:shuying/pages/movies_page.dart';
import 'package:shuying/pages/stats_page.dart';
import 'package:shuying/pages/book_detail_page.dart';
import 'package:shuying/pages/movie_detail_page.dart';
import 'package:shuying/pages/pro_page.dart';
import 'package:shuying/pages/support_page.dart';
import 'package:shuying/pages/year_review_page.dart';
import 'package:shuying/domain/books.dart' as books;
import 'package:shuying/services/pro_store.dart';
import 'package:shuying/store/app_store.dart';
import 'package:shuying/theme/app_theme.dart';
import 'package:shuying/widgets/bits.dart';
import 'package:shuying/widgets/sheets.dart';

Widget harness(Widget page, AppStore store, ProStore pro,
        {EdgeInsets padding = EdgeInsets.zero,
        double scale = 1,
        TargetPlatform platform = TargetPlatform.android}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: pro),
      ],
      child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: platform),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('zh', 'CN')],
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  padding: padding,
                  viewPadding: padding,
                  // 兼容仍使用旧字体缩放 API 的 OHOS Flutter 3.7。
                  // ignore: deprecated_member_use
                  textScaleFactor: scale),
              child: child!),
          home: page),
    );

void main() {
  for (final device in ['iOS', 'Android', 'HarmonyOS']) {
    testWidgets('$device 安全区域：三个自定义标题均避开状态栏', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = AppStore();
      final pro = ProStore();
      addTearDown(() {
        store.dispose();
        pro.dispose();
      });
      final inset = device == 'iOS' ? 59.0 : 40.0;
      for (final page in [
        const SettingsPage(),
        const DataBackupPage(),
        const PrivacyPolicyPage()
      ]) {
        await tester.pumpWidget(harness(page, store, pro,
            platform:
                device == 'iOS' ? TargetPlatform.iOS : TargetPlatform.android,
            padding: EdgeInsets.only(top: inset, bottom: 34)));
        await tester.pumpAndSettle();
        final nav = find.byType(NavBar);
        expect(tester.getRect(nav).top, greaterThanOrEqualTo(inset));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('窄屏大字体和横屏安全区域不使设置及隐私页面溢出', (tester) async {
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [const Size(320, 640), const Size(844, 390)]) {
      await tester.binding.setSurfaceSize(size);
      for (final page in [
        const SettingsPage(),
        const DataBackupPage(),
        const PrivacyPolicyPage(),
        const PrivacyConsentGate()
      ]) {
        await tester.pumpWidget(harness(page, store, pro,
            padding: const EdgeInsets.fromLTRB(30, 40, 30, 24), scale: 1.4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('阅读和观影：选择日期直接返回，主动点击才显示可取消的24小时滚轮', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final pro = ProStore();
    final book = store.addBook(BookInput(title: '日期测试', author: '作者'));
    store.startReading(book.id);
    final movie = store.addMovie(MovieInput(title: '观影测试', director: '导演'));
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    late BuildContext host;
    await tester.pumpWidget(harness(Scaffold(body: Builder(builder: (context) {
      host = context;
      return const SizedBox();
    })), store, pro));
    for (final reading in [true, false]) {
      if (reading) {
        unawaited(showLogSheet(host,
            book: store.books.single, round: store.books.single.rounds.single));
      } else {
        unawaited(showWatchSheet(host, movie: movie));
      }
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsNothing);
      await tester.tap(find.byKey(const Key('record-date')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('确定').last);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(find.textContaining('（当前时间）'), findsOneWidget);
      await tester.tap(find.byKey(const Key('record-time')));
      await tester.pumpAndSettle();
      final picker =
          tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
      expect(picker.mode, CupertinoDatePickerMode.time);
      expect(picker.use24hFormat, isTrue);
      picker.onDateTimeChanged(DateTime(2000, 1, 1, 8, 35));
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('（当前时间）'), findsOneWidget);
      await tester.tap(find.byKey(const Key('record-time')));
      await tester.pumpAndSettle();
      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2000, 1, 1, 8, 35));
      await tester.tap(find.text('确定').last);
      await tester.pumpAndSettle();
      expect(find.text('08:35'), findsOneWidget);
      if (reading) {
        await tester.enterText(
            find.widgetWithText(TextField, '今天读到了什么？'), '日期记录');
        await tester.ensureVisible(find.text('保存记录'));
        await tester.tap(find.text('保存记录'));
      } else {
        await tester.ensureVisible(find.text('保存'));
        await tester.tap(find.text('保存'));
      }
      await tester.pumpAndSettle();
      final at = reading
          ? store.books.single.rounds.single.logs.single.at
          : store.movies.single.watches.single.at;
      expect(at.hour, 8);
      expect(at.minute, 35);
      expect(at.year, DateTime.now().year);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('已有记录的书架电影统计详情在窄屏大字体下正常布局', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final pro = ProStore();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ProStore.channel, (call) async {
      if (call.method == 'status') return false;
      if (call.method == 'product') return {'purchasesEnabled': false};
      fail('布局测试不应调用交易接口');
    });
    addTearDown(() {
      store.dispose();
      pro.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ProStore.channel, null);
    });
    final book = store.addBook(
        BookInput(title: '一本很长标题的书籍用于显示测试', author: '作者', totalPages: 200));
    store.startReading(book.id);
    store.addLog(book.id, store.books.single.rounds.single.id,
        LogInput(at: DateTime(2025), pages: 30, minutes: 40));
    final movie = store.addMovie(MovieInput(title: '电影测试', director: '导演'));
    store.addWatch(movie.id, at: DateTime(2025), rating: 5);
    for (final page in [
      const BooksPage(),
      const MoviesPage(),
      const StatsPage(),
      BookDetailPage(bookId: book.id),
      MovieDetailPage(movieId: movie.id),
      const YearReviewPage(preview: true),
      const ProPage(),
      const SupportPage(),
    ]) {
      await tester.pumpWidget(harness(Scaffold(body: page), store, pro,
          padding: const EdgeInsets.fromLTRB(12, 40, 12, 24), scale: 1.4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
      final scroll = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
      for (var n = 0; n < 4; n++) {
        await tester.drag(scroll.first, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${page.runtimeType} after scroll');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('作者导演可留空，书籍版本可编辑，在读书籍和电影均可补记往期', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    late BuildContext host;
    await tester.pumpWidget(harness(Scaffold(body: Builder(builder: (context) {
      host = context;
      return const SizedBox();
    })), store, pro));
    unawaited(showBookSheet(host));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '只有书名');
    await tester.enterText(find.byType(TextField).at(2), '某出版社 · 修订版');
    await tester.tap(find.text('加入书架'));
    await tester.pumpAndSettle();
    expect(store.books.single.author, isEmpty);
    expect(store.books.single.edition, '某出版社 · 修订版');
    unawaited(showBookSheet(host, book: store.books.single));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text,
        '某出版社 · 修订版');
    await tester.enterText(find.byType(TextField).at(2), '新版');
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(store.books.single.edition, '新版');
    unawaited(showMovieSheet(host));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '只有片名');
    await tester.tap(find.text('加入片单'));
    await tester.pumpAndSettle();
    expect(store.movies.single.director, isEmpty);
    final book = store.books.single;
    store.startReading(book.id);
    await tester
        .pumpWidget(harness(BookDetailPage(bookId: book.id), store, pro));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('补记往期'));
    await tester.tap(find.text('补记往期'));
    await tester.pumpAndSettle();
    expect(find.text('补记往期阅读'), findsOneWidget);
    Navigator.of(tester.element(find.text('补记往期阅读'))).pop();
    await tester.pumpAndSettle();
    await tester.pumpWidget(
        harness(MovieDetailPage(movieId: store.movies.single.id), store, pro));
    await tester.pumpAndSettle();
    await tester.tap(find.text('补记往期'));
    await tester.pumpAndSettle();
    expect(find.text('补记往期观影'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('只选日期可保存观影；阅读空记录拒绝，填写页数自动计算进度', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    final movie = store.addMovie(MovieInput(title: '仅日期', director: '导演'));
    final book =
        store.addBook(BookInput(title: '页数', author: '作者', totalPages: 100));
    store.startReading(book.id);
    late BuildContext host;
    await tester.pumpWidget(harness(Scaffold(body: Builder(builder: (context) {
      host = context;
      return const SizedBox();
    })), store, pro));
    unawaited(showWatchSheet(host, movie: movie));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsNothing);
    final beforeSave = DateTime.now();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.movies.single.watches, hasLength(1));
    final savedAt = store.movies.single.watches.single.at;
    expect(savedAt.isBefore(beforeSave), isFalse);
    expect(savedAt.isAfter(DateTime.now()), isFalse);
    unawaited(showLogSheet(host,
        book: store.books.single, round: store.books.single.rounds.single));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();
    expect(store.books.single.rounds.single.logs, isEmpty);
    final pages = find.descendant(
        of: find.byType(NumberField).first, matching: find.byType(TextField));
    await tester.enterText(pages, '20');
    await tester.ensureVisible(find.text('保存记录'));
    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();
    expect(
        books.roundProgress(
            store.books.single, store.books.single.rounds.single),
        20);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('补记同一天允许保存，完成日期早于开始日期时拦截', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    final book = store.addBook(BookInput(title: '同一天', author: '作者'));
    late BuildContext host;
    await tester.pumpWidget(harness(Scaffold(body: Builder(builder: (context) {
      host = context;
      return const SizedBox();
    })), store, pro));
    unawaited(showPastRoundSheet(host, book: book));
    await tester.pumpAndSettle();
    Future<void> choose(int index, DateTime day) async {
      // 每个日期字段渲染出「日期 + 时间」两个 PickerRow，
      // 按 key 取日期行，避免按下标点到时间行。
      await tester.tap(find.byKey(const Key('record-date')).at(index));
      await tester.pumpAndSettle();
      final dialog = find.byType(DatePickerDialog);
      final localizations = MaterialLocalizations.of(tester.element(dialog));
      await tester.tap(find.byTooltip(localizations.inputDateModeButtonLabel));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(of: dialog, matching: find.byType(TextField)),
          localizations.formatCompactDate(day));
      await tester.tap(find.text(localizations.okButtonLabel).last);
      await tester.pumpAndSettle();
    }

    final today = DateTime.now();
    await choose(0, today);
    await choose(1, today.subtract(const Duration(days: 1)));
    await tester.tap(find.text('保存这一轮'));
    await tester.pumpAndSettle();
    expect(store.books.single.rounds, isEmpty);
    expect(find.text('完成时间不能早于开始时间'), findsOneWidget);
    await choose(1, today);
    await tester.tap(find.text('保存这一轮'));
    await tester.pumpAndSettle();
    final round = store.books.single.rounds.single;
    expect(DateUtils.dateOnly(round.startedAt),
        DateUtils.dateOnly(round.finishedAt!));
    expect(round.isActive, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('编辑阅读观影保留原时间并重排，历史可改页数时长但无进度', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    final book = store.addBook(BookInput(title: '编辑', totalPages: 100));
    store.startReading(book.id);
    final roundId = store.books.single.rounds.single.id;
    store.addLog(book.id, roundId,
        LogInput(at: DateTime(2000, 1, 1, 8, 35), pages: 10, progress: 10));
    store.addLog(book.id, roundId,
        LogInput(at: DateTime(2005), pages: 20, progress: 30));
    final log = books.sortedLogs(store.books.single.rounds.single).last;
    final movie = store.addMovie(MovieInput(title: '编辑观影'));
    store.addWatch(movie.id, at: DateTime(2000, 1, 1, 8, 35), rating: 2);
    final watch = store.movies.single.watches.single;
    late BuildContext host;
    await tester.pumpWidget(harness(Scaffold(body: Builder(builder: (context) {
      host = context;
      return const SizedBox();
    })), store, pro));
    unawaited(showLogSheet(host,
        book: store.books.single,
        round: store.books.single.rounds.single,
        log: log));
    await tester.pumpAndSettle();
    var field =
        tester.widget<RecordDateTimeField>(find.byType(RecordDateTimeField));
    expect(field.preserveTime, isTrue);
    field.onChanged(DateTime(2010, 1, 1, 8, 35));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(NumberField).first,
            matching: find.byType(TextField)),
        '25');
    tester.widget<Slider>(find.byType(Slider)).onChanged!(40);
    await tester.ensureVisible(find.text('保存记录'));
    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();
    final updated = books.sortedLogs(store.books.single.rounds.single).first;
    expect(updated.id, log.id);
    expect(updated.at, DateTime(2010, 1, 1, 8, 35));
    expect(updated.pages, 25);
    expect(updated.progress, 40);
    unawaited(showWatchSheet(host, movie: store.movies.single, watch: watch));
    await tester.pumpAndSettle();
    field =
        tester.widget<RecordDateTimeField>(find.byType(RecordDateTimeField));
    expect(field.preserveTime, isTrue);
    await tester.enterText(find.byType(TextField), '更新感想');
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.movies.single.watches.single.id, watch.id);
    expect(store.movies.single.watches.single.at, watch.at);
    expect(store.movies.single.watches.single.note, '更新感想');
    store.addPastRound(
        book.id,
        PastRoundInput(
            startedAt: DateTime(1990),
            finishedAt: DateTime(1990, 2),
            note: '历史感想'));
    final historical = store.books.single.rounds.first;
    unawaited(
        showPastRoundSheet(host, book: store.books.single, round: historical));
    await tester.pumpAndSettle();
    expect(find.byType(NumberField), findsNWidgets(2));
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(RecordDateTimeField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).at(0), '120');
    await tester.enterText(find.byType(TextField).at(1), '150');
    await tester.enterText(find.byType(TextField).last, '修订后的历史感想');
    await tester.ensureVisible(find.text('保存修改'));
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(store.books.single.rounds.first.note, '修订后的历史感想');
    expect(store.books.single.rounds.first.logs, isEmpty);
    expect(store.books.single.rounds.first.pages, 120);
    expect(store.books.single.rounds.first.minutes, 150);
    await tester
        .pumpWidget(harness(const Scaffold(body: StatsPage()), store, pro));
    await tester.pumpAndSettle();
    expect(find.text('165'), findsOneWidget); // 当前 45 页 + 历史 120 页。
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('商店查询无回调会超时释放busy，iOS离线仍有恢复购买入口', (tester) async {
    final pro = ProStore();
    addTearDown(() {
      pro.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ProStore.channel, null);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            ProStore.channel, (_) => Completer<Object?>().future);
    final refresh = pro.refresh();
    await tester.pump(const Duration(seconds: 16));
    await refresh;
    expect(pro.busy, isFalse);
    expect(pro.purchasesEnabled, isTrue);
    expect(pro.isPro, isFalse);
    expect(pro.message, isNotNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
