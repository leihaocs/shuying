import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/services/pro_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const product = {'price': '¥38', 'purchasesEnabled': true};

  Future<void> changed(WidgetTester tester, bool entitled) async {
    final reply = Completer<void>();
    tester.binding.channelBuffers.push(
      ProStore.channel.name,
      const StandardMethodCodec()
          .encodeMethodCall(MethodCall('changed', entitled)),
      (_) => reply.complete(),
    );
    await reply.future;
  }

  tearDown(() => messenger.setMockMethodCallHandler(ProStore.channel, null));

  testWidgets('购买无回调可恢复操作，迟到购买仍通过商店状态交付', (tester) async {
    final purchase = Completer<String>();
    var entitled = false;
    messenger.setMockMethodCallHandler(ProStore.channel, (call) async {
      if (call.method == 'product') return product;
      if (call.method == 'status') return entitled;
      if (call.method == 'buy') return purchase.future;
      return null;
    });
    final pro = ProStore();
    addTearDown(pro.dispose);
    await pro.refresh();
    final buying = pro.buy();
    await tester.pump(const Duration(minutes: 2, seconds: 1));
    await buying;
    expect(pro.busy, isFalse);
    expect(pro.isPro, isFalse);
    expect(pro.message, contains('避免重复付款'));

    entitled = true;
    purchase.complete('purchased');
    await tester.pump();
    expect(pro.isPro, isTrue);
    expect(pro.message, 'Pro 已解锁。');
  });

  testWidgets('买后校验无回调不锁死，旧的否定响应不能覆盖已确认购买', (tester) async {
    final staleStatus = Completer<bool>();
    var afterPurchase = false;
    messenger.setMockMethodCallHandler(ProStore.channel, (call) async {
      if (call.method == 'product') return product;
      if (call.method == 'status') {
        return afterPurchase ? staleStatus.future : false;
      }
      if (call.method == 'buy') {
        afterPurchase = true;
        return 'purchased';
      }
      return null;
    });
    final pro = ProStore();
    addTearDown(pro.dispose);
    await pro.refresh();
    final buying = pro.buy();
    await tester.pump();
    await changed(tester, true);
    await tester.pump(const Duration(seconds: 16));
    await buying;
    expect(pro.busy, isFalse);
    expect(pro.isPro, isTrue);
    expect(pro.message, 'Pro 已解锁。');

    staleStatus.complete(false);
    await tester.pump();
    expect(pro.isPro, isTrue);
  });

  testWidgets('恢复超时后仍接受迟到的已验证权益，网络失败不会撤销权益', (tester) async {
    final restore = Completer<bool>();
    var offline = false;
    messenger.setMockMethodCallHandler(ProStore.channel, (call) async {
      if (offline) throw PlatformException(code: 'disconnected');
      if (call.method == 'product') return product;
      if (call.method == 'status') return false;
      if (call.method == 'restore') return restore.future;
      return null;
    });
    final pro = ProStore();
    addTearDown(pro.dispose);
    await pro.refresh();
    final restoring = pro.restore();
    await tester.pump(const Duration(seconds: 16));
    await restoring;
    expect(pro.busy, isFalse);
    expect(pro.isPro, isFalse);
    restore.complete(true);
    await tester.pump();
    expect(pro.isPro, isTrue);

    offline = true;
    await pro.restore();
    expect(pro.busy, isFalse);
    expect(pro.isPro, isTrue);
  });

  testWidgets('撤回同意停止商店调用并忽略旧响应，重新同意恢复查询', (tester) async {
    final consent = ValueNotifier(true);
    final firstStatus = Completer<bool>();
    final calls = <String>[];
    var first = true;
    messenger.setMockMethodCallHandler(ProStore.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'status') {
        if (first) {
          first = false;
          return firstStatus.future;
        }
        return true;
      }
      if (call.method == 'product') return product;
      fail('未同意时不应调用交易接口');
    });
    final pro =
        ProStore(hasConsent: () => consent.value, consentChanges: consent);
    addTearDown(() {
      pro.dispose();
      consent.dispose();
    });
    final initial = pro.refresh();
    await tester.pump();
    consent.value = false;
    await tester.pump();
    expect(pro.busy, isFalse);
    firstStatus.complete(true);
    await initial;
    await pro.refresh();
    await pro.buy();
    await pro.restore();
    pro.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, ['status']);
    expect(pro.isPro, isFalse);

    consent.value = true;
    await tester.pump();
    expect(calls, ['status', 'status', 'product']);
    expect(pro.isPro, isTrue);
    expect(pro.busy, isFalse);
  });

  testWidgets('首次未同意不查询，其他偏好变化不重复连接商店', (tester) async {
    final consent = ValueNotifier(false);
    final calls = <String>[];
    messenger.setMockMethodCallHandler(ProStore.channel, (call) async {
      calls.add(call.method);
      return call.method == 'status' ? false : product;
    });
    final pro =
        ProStore(hasConsent: () => consent.value, consentChanges: consent);
    addTearDown(() {
      pro.dispose();
      consent.dispose();
    });
    await pro.refresh();
    pro.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, isEmpty);
    consent.value = true;
    await tester.pump();
    expect(calls, ['status', 'product']);
    // 同意状态没有变时，应用的其他数据通知不应触发商店查询。
    consent.notifyListeners();
    await tester.pump();
    expect(calls, ['status', 'product']);
  });

  testWidgets('撤回后迟到购买不自动查询，重新同意后再核验交付', (tester) async {
    final consent = ValueNotifier(true);
    final purchase = Completer<String>();
    final calls = <String>[];
    var entitled = false;
    messenger.setMockMethodCallHandler(ProStore.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'product') return product;
      if (call.method == 'status') return entitled;
      if (call.method == 'buy') return purchase.future;
      return null;
    });
    final pro =
        ProStore(hasConsent: () => consent.value, consentChanges: consent);
    addTearDown(() {
      pro.dispose();
      consent.dispose();
    });
    await pro.refresh();
    final buying = pro.buy();
    await tester.pump();
    consent.value = false;
    entitled = true;
    purchase.complete('purchased');
    await buying;
    await tester.pump();
    expect(calls, ['status', 'product', 'buy']);
    expect(pro.busy, isFalse);
    expect(pro.isPro, isFalse);

    consent.value = true;
    await tester.pump();
    expect(calls, ['status', 'product', 'buy', 'status', 'product']);
    expect(pro.isPro, isTrue);
  });
}
