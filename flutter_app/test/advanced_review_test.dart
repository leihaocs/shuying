import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shuying/pages/advanced_review_page.dart';
import 'package:shuying/pages/pro_page.dart';
import 'package:shuying/pages/revisit_comparison_page.dart';
import 'package:shuying/pages/year_review_page.dart';
import 'package:shuying/services/pro_store.dart';
import 'package:shuying/store/app_store.dart';
import 'package:shuying/theme/app_theme.dart';
import 'package:shuying/widgets/review_export_actions.dart';

void main() {
  late AppStore store;
  late ProStore pro;
  Widget harness(Widget page) => MultiProvider(providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: pro)
      ], child: MaterialApp(theme: AppTheme.light(), home: page));
  setUp(() {
    store = AppStore();
    pro = ProStore();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ProStore.channel, (call) async {
      if (call.method == 'status') return false;
      if (call.method == 'product') return {'purchasesEnabled': false};
      fail('报告预览不得调用购买接口');
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

  testWidgets('真实年度预览优先使用用户记录，预览不能导出完整报告', (tester) async {
    final book = store.addBook(BookInput(title: '真实书籍'));
    store.addPastRound(
        book.id,
        PastRoundInput(
            startedAt: DateTime(2025, 1, 1),
            finishedAt: DateTime(2025, 2, 1),
            pages: 123,
            minutes: 45));
    await tester.pumpWidget(harness(const YearReviewPage(preview: true)));
    await tester.pumpAndSettle();
    expect(find.text('我的年度回顾 · 预览'), findsOneWidget);
    expect(find.text('123'), findsOneWidget);
    expect(find.textContaining('以下为示例'), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const Key('review-pdf')), 300);
    final pdf =
        tester.widget<OutlinedButton>(find.byKey(const Key('review-pdf')));
    expect(pdf.onPressed, isNull);
  });

  testWidgets('未购买直达完整深度页显示Pro，预览范围和完整导出保持门控', (tester) async {
    await tester.pumpWidget(harness(const AdvancedReviewPage()));
    await tester.pumpAndSettle();
    expect(find.byType(ProPage), findsOneWidget);
    await tester.pumpWidget(harness(const AdvancedReviewPage(preview: true)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('review-range')))
            .onPressed,
        isNull);
    await tester.scrollUntilVisible(find.byKey(const Key('review-pdf')), 300);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('review-pdf')))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('调用方传非预览也不能绕过未购买的导出门控', (tester) async {
    await tester.pumpWidget(harness(const Scaffold(
        body: ReviewExportActions(title: '测试', body: '记录', preview: false))));
    await tester.pumpAndSettle();
    for (final key in ['review-copy', 'review-pdf', 'review-card']) {
      expect(tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
          isNull);
    }
  });

  testWidgets('复制失败展示可恢复提示，不留下未处理的异步异常', (tester) async {
    pro.isPro = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard-unavailable');
      }
      return null;
    });
    await tester.pumpWidget(harness(const Scaffold(
        body: ReviewExportActions(title: '测试', body: '记录', preview: false))));
    await tester.tap(find.byKey(const Key('review-copy')));
    await tester.pumpAndSettle();
    expect(find.text('复制未完成，请重试或保存 PDF 报告。'), findsOneWidget);
    for (final key in ['review-copy', 'review-pdf', 'review-card']) {
      expect(tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
          isNotNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('完整回顾复制期间禁重入，完成后恢复全部导出按钮', (tester) async {
    pro.isPro = true;
    final pending = Completer<void>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete();
    });
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        calls++;
        await pending.future;
      }
      return null;
    });
    await tester.pumpWidget(harness(const Scaffold(
        body: ReviewExportActions(title: '测试', body: '记录', preview: false))));
    final onCopy = tester
        .widget<OutlinedButton>(find.byKey(const Key('review-copy')))
        .onPressed!;
    onCopy();
    onCopy(); // 即使保留旧回调并连续触发，也不能重复调平台剪贴板。
    await tester.pump();
    expect(calls, 1);
    for (final key in ['review-copy', 'review-pdf', 'review-card']) {
      expect(tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
          isNull);
    }
    expect(find.text('正在处理，请完成或取消当前操作。'), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();
    for (final key in ['review-copy', 'review-pdf', 'review-card']) {
      expect(tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
          isNotNull);
    }
    expect(find.text('正在处理，请完成或取消当前操作。'), findsNothing);
    expect(find.text('回顾已复制'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('退出完整报告页面后平台复制回调不更新已销毁页面', (tester) async {
    pro.isPro = true;
    final pending = Completer<void>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete();
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') await pending.future;
      return null;
    });
    await tester.pumpWidget(harness(const Scaffold(
        body: ReviewExportActions(title: '测试', body: '记录', preview: false))));
    await tester.tap(find.byKey(const Key('review-copy')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('回顾已复制'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('复制回调返回前权益失效，不提示成功且继续禁止完整导出', (tester) async {
    pro.isPro = true;
    final pending = Completer<void>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete();
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') await pending.future;
      return null;
    });
    await tester.pumpWidget(harness(const Scaffold(
        body: ReviewExportActions(title: '测试', body: '记录', preview: false))));
    await tester.tap(find.byKey(const Key('review-copy')));
    await tester.pump();
    pro.isPro = false;
    pro.notifyListeners();
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('回顾已复制'), findsNothing);
    expect(find.text('正在处理，请完成或取消当前操作。'), findsNothing);
    for (final key in ['review-copy', 'review-pdf', 'review-card']) {
      expect(tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
          isNull);
    }
    pro.isPro = true;
    pro.notifyListeners();
    await tester.pump();
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('review-copy')))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('取消回顾图片样式后恢复导出按钮', (tester) async {
    pro.isPro = true;
    await tester.pumpWidget(harness(const Scaffold(
        body: ReviewExportActions(title: '测试', body: '记录', preview: false))));
    await tester.tap(find.byKey(const Key('review-card')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(ReviewExportActions))).pop();
    await tester.pumpAndSettle();
    for (final key in ['review-copy', 'review-pdf', 'review-card']) {
      expect(tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
          isNotNull);
    }
    expect(find.text('正在处理，请完成或取消当前操作。'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已验证Pro可使用完整日期范围、跨年选择与报告导出', (tester) async {
    pro.isPro = true; // 仅模拟已由原生商店验证的测试状态。
    await tester.pumpWidget(harness(const AdvancedReviewPage()));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('review-range')))
            .onPressed,
        isNotNull);
    await tester.tap(find.text('跨年对比'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DropdownButton<int>>(find.byKey(const Key('review-year')))
            .onChanged,
        isNotNull);
    await tester.scrollUntilVisible(find.byKey(const Key('review-pdf')), 300);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('review-pdf')))
            .onPressed,
        isNotNull);
  });

  testWidgets('历次预览只展示最近两次，原始全书评分不变成逐轮评分', (tester) async {
    final book = store.addBook(BookInput(title: '对照书籍'));
    store.rateBook(book.id, 9);
    for (var year = 2023; year <= 2025; year++) {
      store.addPastRound(
          book.id,
          PastRoundInput(
              startedAt: DateTime(year, 1, 1),
              finishedAt: DateTime(year, 2, 1),
              pages: year,
              minutes: 10,
              note: '$year 年的感想'));
    }
    await tester.pumpWidget(
        harness(RevisitComparisonPage(bookId: book.id, preview: true)));
    await tester.pumpAndSettle();
    expect(find.text('第 3 次阅读'), findsOneWidget);
    expect(find.text('第 2 次阅读'), findsOneWidget);
    expect(find.text('第 1 次阅读'), findsNothing);
    expect(find.text('当前全书评分：9/10'), findsOneWidget);
    expect(find.textContaining('当前轮次进度'), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const Key('review-pdf')), 300);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('review-pdf')))
            .onPressed,
        isNull);
  });
}
