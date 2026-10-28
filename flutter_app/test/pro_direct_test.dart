import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shuying/pages/pro_page.dart';
import 'package:shuying/pages/settings_page.dart';
import 'package:shuying/pages/stats_page.dart';
import 'package:shuying/services/pro_store.dart';
import 'package:shuying/store/app_store.dart';
import 'package:shuying/theme/app_theme.dart';

void main() {
  testWidgets('未开放购买时统计和设置不展示Pro入口，已接入渠道保留入口', (tester) async {
    var purchasesEnabled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ProStore.channel, (call) async {
      if (call.method == 'status') return false;
      if (call.method == 'product') {
        return {'purchasesEnabled': purchasesEnabled, 'price': '¥38'};
      }
      fail('不应调用交易接口：${call.method}');
    });
    final pro = ProStore();
    final store = AppStore();
    addTearDown(() {
      pro.dispose();
      store.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ProStore.channel, null);
    });
    for (final page in [const StatsPage(), const SettingsPage()]) {
      purchasesEnabled = false;
      await pro.refresh();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: pro),
          ChangeNotifierProvider.value(value: store),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: page),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pro'), findsNothing);
      purchasesEnabled = true;
      await pro.refresh();
      await tester.pumpAndSettle();
      expect(find.textContaining('Pro'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('未开放购买的渠道保留Pro介绍和预览，不提供交易操作', (tester) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ProStore.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'product') return {'purchasesEnabled': false};
      if (call.method == 'status') return false;
      fail('不应调用交易接口：${call.method}');
    });
    final pro = ProStore();
    addTearDown(() {
      pro.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ProStore.channel, null);
    });
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: pro,
      child: const MaterialApp(home: ProPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('书影温故 Pro'), findsOneWidget);
    expect(find.text('Pro · 功能介绍'), findsOneWidget);
    expect(find.text('预览示例年度回顾'), findsOneWidget);
    expect(find.text('恢复购买'), findsNothing);
    expect(find.text('刷新商店状态'), findsNothing);
    expect(find.text('购买暂不可用'), findsNothing);
    await pro.buy();
    await pro.restore();
    expect(calls, isNot(contains('buy')));
    expect(calls, isNot(contains('restore')));
    expect(pro.isPro, isFalse);
  });
}
