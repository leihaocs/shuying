import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/home_shell.dart';
import 'pages/privacy_consent_gate.dart';
import 'store/app_store.dart';
import 'theme/app_theme.dart';

/// 上架截图模式：`flutter run --dart-define=SHUYING_SCREENSHOT=true --dart-define=SHUYING_TAB=n`
/// 会在加载完示例数据后自动同意隐私政策，并直接停在第 n 个 Tab。
/// 默认关闭，对正常启动没有任何影响。
const bool kScreenshotMode =
    bool.fromEnvironment('SHUYING_SCREENSHOT', defaultValue: false);
const int kScreenshotTab =
    int.fromEnvironment('SHUYING_TAB', defaultValue: 0);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider<AppStore>(
      create: (_) {
        final store = AppStore();
        final Future<void> loading = store.load();
        if (kScreenshotMode) {
          loading.then((_) => store.acceptPrivacy());
        }
        return store;
      },
      child: const ShuYingApp(),
    ),
  );
}

class ShuYingApp extends StatelessWidget {
  const ShuYingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppStore, ThemeMode>((s) => s.themeMode);

    return MaterialApp(
      title: '书影温故',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const _AppEntry(),
    );
  }
}

/// 应用启动入口：根据 store 加载状态决定先呈现：
///   - splash           : 本地偏好还没读完（首启动瞬间）
///   - 同意页           : 还没同意隐私政策
///   - HomeShell        : 进入主界面
///
/// 状态变化由 AppStore.notifyListeners() 驱动；该 widget 自身不缓存任何状态，
/// 切回「未同意」会自然回流到同意页。
class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    if (!store.ready) {
      return const _SplashScreen();
    }
    if (!store.privacyConsent) {
      return const PrivacyConsentGate();
    }
    return const HomeShell(initialIndex: kScreenshotTab);
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📖', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              '书影温故',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: c.text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(c.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}