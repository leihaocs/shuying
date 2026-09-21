import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';
import '../widgets/sheets.dart';
import 'privacy_policy_page.dart';

/// 首次启动 / 隐私政策未同意时显示的全屏同意页。
///
/// 用户必须点击「同意并继续」才能进入主界面；
/// 点击「不同意」会再次确认，确认后退出应用（Android 由系统接管退出，iOS
/// 由于系统限制无法程序退出，需提示用户手动关闭）。
class PrivacyConsentGate extends StatelessWidget {
  const PrivacyConsentGate({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 头部
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Text('🔒', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '欢迎使用书影',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '请阅读并同意隐私政策后再开始使用',
                          style: TextStyle(fontSize: 12.5, color: c.text3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 政策正文（复用同一个组件，去掉顶部返回按钮）
            const Expanded(
              child: PrivacyPolicyPage(showAppBar: false),
            ),

            // 底部按钮区
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Column(
                children: [
                  AppButton(
                    label: '同意并继续',
                    kind: BtnKind.primary,
                    expand: true,
                    icon: Icons.check_rounded,
                    onPressed: () =>
                        context.read<AppStore>().acceptPrivacy(),
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: '不同意，退出应用',
                    kind: BtnKind.ghost,
                    expand: true,
                    onPressed: () => _confirmExit(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final c = AppColors.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 9),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: c.surface3,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '退出书影？',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '你可以稍后再次打开书影，届时仍会看到这份隐私政策。'
                    'iOS 用户请手动从主屏幕上划关闭 App。',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: c.text2,
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
            SheetFooter(
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: '再想想',
                      kind: BtnKind.ghost,
                      expand: true,
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: '退出',
                      kind: BtnKind.danger,
                      expand: true,
                      onPressed: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Android: 系统级退出；iOS: 无效果，由上面的提示文案兜底
      await SystemNavigator.pop(animated: true);
    }
  }
}