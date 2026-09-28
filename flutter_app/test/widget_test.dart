import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuying/main.dart';
import 'package:shuying/store/app_store.dart';

/// 首次启动冒烟测试：
///   1. 空数据启动 -> 显示隐私同意门
///   2. 点击「同意并继续」-> 进入主界面（底部 Tab「书架 / 电影 / 统计」）
void main() {
  testWidgets('首启动显示隐私同意页，同意后进入书架', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      ChangeNotifierProvider<AppStore>(
        create: (_) => AppStore()..load(),
        child: const ShuYingApp(),
      ),
    );

    // 等待 AppStore.load() 完成并渲染出同意门
    await tester.pumpAndSettle();

    expect(find.text('请阅读并同意隐私政策后再开始使用'), findsOneWidget);
    expect(find.text('同意并继续'), findsOneWidget);

    await tester.tap(find.text('同意并继续'));
    await tester.pumpAndSettle();

    // 主界面：底部三个 Tab（「书架」在页面标题与 Tab 里各出现一次）
    expect(find.text('书架'), findsWidgets);
    expect(find.text('电影'), findsWidgets);
    expect(find.text('统计'), findsWidgets);
  });
}
