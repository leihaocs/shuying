import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/services/pro_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = ProStore.channel;
  var entitled = false;
  var outcome = 'cancelled';
  var unavailable = false;
  var noProduct = false;
  late ProStore pro;
  setUp(() {
    entitled = false; outcome = 'cancelled'; unavailable = false; noProduct = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (unavailable) throw PlatformException(code: 'offline');
        switch (call.method) {
          case 'status': return entitled;
          case 'product': return noProduct ? null : {'id': 'pro', 'price': '¥38'};
          case 'buy': if (outcome == 'purchased') entitled = true; return outcome;
          case 'restore': return entitled;
        }
        return null;
      });
    pro = ProStore();
  });
  tearDown(() {
    pro.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
  test('真实报价，取消与待支付不能解锁', () async {
    await pro.refresh(); expect(pro.price, '¥38'); expect(pro.isPro, isFalse);
    await pro.buy(); expect(pro.isPro, isFalse);
    outcome = 'pending'; await pro.buy(); expect(pro.isPro, isFalse);
    outcome = 'purchased'; await pro.buy(); expect(pro.isPro, isTrue);
  });
  test('恢复与退款状态从商店读取，不靠本地标记', () async {
    entitled = true; await pro.restore(); expect(pro.isPro, isTrue);
    entitled = false; await pro.refresh(); expect(pro.isPro, isFalse);
  });
  test('服务不可用或商品未配置不能显示伪造价格或解锁', () async {
    unavailable = true; await pro.refresh(); expect(pro.price, isNull);
    expect(pro.isPro, isFalse); expect(pro.busy, isFalse);
    unavailable = false; noProduct = true; await pro.refresh(); expect(pro.price, isNull);
    await pro.buy(); expect(pro.isPro, isFalse);
  });
}
