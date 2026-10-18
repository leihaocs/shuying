import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shuying/pages/pro_page.dart';
import 'package:shuying/services/pro_store.dart';

void main() {
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
