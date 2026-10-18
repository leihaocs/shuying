import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/pages/support_page.dart';

void main() {
  testWidgets('支持页提供离线帮助，浏览器打开失败时给出复制指引', (tester) async {
    const channel = MethodChannel('com.bookmovie.revisit/backup');
    var opened = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'openSupport');
      opened = true;
      throw PlatformException(code: 'support');
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const MaterialApp(home: SupportPage()));
    expect(find.text(SupportPage.email), findsOneWidget);
    expect(find.textContaining('记录保存在当前应用'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('打开在线支持页'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('打开在线支持页'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(find.text('无法打开浏览器，请复制支持网址后访问。'), findsOneWidget);
  });
}
