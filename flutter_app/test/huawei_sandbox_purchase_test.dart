import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shuying/pages/pro_page.dart';
import 'package:shuying/services/pro_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(ProStore.channel, null));

  test('未配置沙盒时保留预览并明确原因，不能发起购买', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(ProStore.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'status') return false;
      if (call.method == 'product') {
        return {
          'purchasesEnabled': false,
          'sandbox': true,
          'message': '请先配置华为沙盒测试账号。',
        };
      }
      fail('配置未完成时不应调用购买接口');
    });
    final pro = ProStore();
    addTearDown(pro.dispose);
    await pro.refresh();
    expect(pro.sandbox, isTrue);
    expect(pro.price, isNull);
    expect(pro.message, '请先配置华为沙盒测试账号。');
    await pro.buy();
    expect(calls, ['status', 'product']);
  });

  test('已发货沙盒订单不能恢复时不给予永久权益或虚报成功', () async {
    messenger.setMockMethodCallHandler(ProStore.channel, (call) async {
      if (call.method == 'status') return false;
      if (call.method == 'product') {
        return {'purchasesEnabled': true, 'sandbox': true, 'price': '¥28.00'};
      }
      if (call.method == 'restore') {
        throw PlatformException(code: 'sandbox_restore_unavailable');
      }
      return null;
    });
    final pro = ProStore();
    addTearDown(pro.dispose);
    await pro.refresh();
    await pro.restore();
    expect(pro.isPro, isFalse);
    expect(pro.message, contains('清除测试购买历史'));
    expect(pro.busy, isFalse);
  });

  testWidgets('沙盒购买明确显示测试及真实报价，后台撤权去除解锁提示', (tester) async {
    var entitled = false;
    messenger.setMockMethodCallHandler(ProStore.channel, (call) async {
      if (call.method == 'status') return entitled;
      if (call.method == 'product') {
        return {'purchasesEnabled': true, 'sandbox': true, 'price': '¥28.00'};
      }
      if (call.method == 'buy') {
        entitled = true;
        return 'purchased';
      }
      return null;
    });
    final pro = ProStore();
    addTearDown(pro.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<ProStore>.value(
      value: pro,
      child: const MaterialApp(home: ProPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pro · 沙盒测试'), findsOneWidget);
    expect(find.textContaining('不会真实扣款'), findsOneWidget);
    expect(find.text('沙盒购买测试 · ¥28.00'), findsOneWidget);
    await pro.buy();
    await tester.pump();
    expect(pro.isPro, isTrue);
    expect(pro.message, '本次沙盒测试已解锁。');

    entitled = false;
    final reply = Completer<void>();
    tester.binding.channelBuffers.push(
      ProStore.channel.name,
      const StandardMethodCodec()
          .encodeMethodCall(const MethodCall('changed', false)),
      (_) => reply.complete(),
    );
    await reply.future;
    await tester.pump();
    expect(pro.isPro, isFalse);
    expect(pro.message, isNull);
    expect(find.text('本次沙盒测试已解锁。'), findsNothing);
  });
}
