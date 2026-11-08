import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/pages/support_page.dart';

void main() {
  const channel = MethodChannel('com.bookmovie.revisit/backup');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final entry in {
    '国内安卓 direct': SupportPage.domesticUrl,
    'Google Play': SupportPage.githubUrl,
    'iOS': SupportPage.githubUrl,
    'HarmonyOS': SupportPage.domesticUrl,
  }.entries) {
    testWidgets('${entry.key} 读取本地渠道配置后展示、复制和实际打开同一网址', (tester) async {
      var reads = 0;
      String? copied;
      String? opened;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'supportUrl') {
          reads++;
          return entry.value;
        }
        expect(call.method, 'openSupport');
        opened = (call.arguments as Map)['url'] as String;
        return true;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      await tester.pumpWidget(const MaterialApp(home: SupportPage()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('复制支持网址'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      await tester.tap(find.text('复制支持网址'));
      await tester.pumpAndSettle();
      expect(copied, entry.value);
      await tester.ensureVisible(find.text('打开在线支持页'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开在线支持页'));
      await tester.pumpAndSettle();
      expect(opened, entry.value);
      expect(reads, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('支持页提供离线帮助，浏览器打开失败时给出复制指引', (tester) async {
    var opened = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'supportUrl') return SupportPage.domesticUrl;
      expect(call.method, 'openSupport');
      expect(call.arguments, {'url': SupportPage.domesticUrl});
      opened = true;
      throw PlatformException(code: 'support');
    });
    await tester.pumpWidget(const MaterialApp(home: SupportPage()));
    await tester.pumpAndSettle();
    expect(find.text(SupportPage.email), findsOneWidget);
    expect(find.textContaining('记录保存在当前应用'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('打开在线支持页'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('打开在线支持页'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(find.text('无法打开浏览器，请复制支持网址后访问。'), findsOneWidget);
    expect(find.text(SupportPage.domesticUrl), findsOneWidget);
  });

  testWidgets('旧原生桥接不认识配置方法时按原有 GitHub 地址回退', (tester) async {
    var opened = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'supportUrl') throw MissingPluginException();
      expect(call.method, 'openSupport');
      expect(call.arguments, {'url': SupportPage.githubUrl});
      opened = true;
      return true;
    });
    await tester.pumpWidget(const MaterialApp(home: SupportPage()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('打开在线支持页'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(SupportPage.githubUrl), findsOneWidget);
    await tester.tap(find.text('打开在线支持页'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });

  for (final invalid in [
    'http://bookmovie-revisit.cn/support.html',
    'https://bookmovie-revisit.cn.evil.example/support.html',
    'https://leihaocs.github.io/another/support.html',
  ]) {
    testWidgets('不展示或打开未许可的配置地址：$invalid', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'supportUrl');
        return invalid;
      });
      await tester.pumpWidget(const MaterialApp(home: SupportPage()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('在线支持暂不可用，请通过上方邮箱联系我们。'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(invalid), findsNothing);
      expect(find.text('打开在线支持页'), findsNothing);
      expect(find.text('复制支持网址'), findsNothing);
      expect(find.textContaining('记录保存在当前应用'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('配置读取失败仍保留离线帮助和邮箱', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    await tester.pumpWidget(const MaterialApp(home: SupportPage()));
    await tester.pumpAndSettle();
    expect(find.text(SupportPage.email), findsOneWidget);
    expect(find.textContaining('记录保存在当前应用'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('在线支持暂不可用，请通过上方邮箱联系我们。'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
}
