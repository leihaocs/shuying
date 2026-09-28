import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';
import '../widgets/sheets.dart';
import 'privacy_policy_page.dart';

/* ------------------------------------------------------------------ */
/* 版本信息                                                            */
/* ------------------------------------------------------------------ */

/// 已缓存的版本 Future，避免每次 rebuild 都重新发起异步调用。
Future<String>? _versionFuture;

/// 读取 App 真实版本号，显示为「版本名 (构建号)」，如 `1.0.0 (1)`。
///
/// 数据来源是 `pubspec.yaml` 的 `version` —— Flutter 打包时会把它写进
/// 各平台的 versionName / CFBundleShortVersionString / versionCode。
/// 因此**改版本只需改 pubspec.yaml 一行**，本页不会再显示过期的写死值。
///
/// 个别平台（如尚未提供 ohos 实现的鸿蒙）取不到包信息时返回 `—`，
/// 不打断页面渲染。
Future<String> _appVersion() {
  _versionFuture ??= _readVersion();
  return _versionFuture!;
}

Future<String> _readVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (_) {
    return '—';
  }
}

/// 「设置 / 关于」页。
///
/// 提供：
///   - 主题切换（与 Books 页面顶部那颗按钮等价，便于在 App 内也能切换）
///   - 隐私政策入口（跳转应用内 [PrivacyPolicyPage]）
///   - 撤回隐私政策同意（用于重新触发首次启动引导）
///   - 清空所有数据
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final store = context.watch<AppStore>();

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          const NavBar(title: '设置'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                const _SectionHeader('外观'),
                CardBox(
                  child: _TapRow(
                    icon: store.themeMode == ThemeMode.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    title: '主题模式',
                    trailing: Text(
                      store.themeMode == ThemeMode.dark ? '深色' : '浅色',
                      style: TextStyle(fontSize: 13, color: c.text3),
                    ),
                    onTap: store.toggleTheme,
                  ),
                ),
                const SizedBox(height: 18),

                const _SectionHeader('隐私'),
                CardBox(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _TapRow(
                        icon: Icons.description_outlined,
                        title: '隐私政策',
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: c.text3,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PrivacyPolicyPage(),
                          ),
                        ),
                      ),
                      _Divider(),
                      _TapRow(
                        icon: Icons.undo_rounded,
                        title: '撤回隐私政策同意',
                        destructive: true,
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: c.text3,
                        ),
                        onTap: () => _confirmResetConsent(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                const _SectionHeader('数据'),
                CardBox(
                  padding: EdgeInsets.zero,
                  child: _TapRow(
                    icon: Icons.delete_outline_rounded,
                    title: '清空所有数据',
                    destructive: true,
                    trailing: Icon(Icons.chevron_right_rounded, color: c.text3),
                    onTap: () => _confirmClearAll(context),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '提示：所有数据仅保存在这台设备上，'
                    '「撤回同意」或「清空数据」后无法恢复，请谨慎操作。',
                    style: TextStyle(fontSize: 11.5, color: c.text3, height: 1.6),
                  ),
                ),

                const SizedBox(height: 24),
                const _SectionHeader('关于'),
                CardBox(
                  child: Column(
                    children: [
                      const _InfoRow(label: '应用名称', value: '书影温故'),
                      const SizedBox(height: 8),
                      const _InfoRow(label: '英文名称', value: 'Reel & Read'),
                      const SizedBox(height: 8),
                      FutureBuilder<String>(
                        future: _appVersion(),
                        builder: (context, snap) => _InfoRow(
                          label: '版本',
                          value: snap.data ?? '—',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _InfoRow(
                        label: '隐私政策版本',
                        value: PrivacyPolicyPage.version,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '— Made with care —',
                    style: TextStyle(fontSize: 11.5, color: c.text3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmResetConsent(BuildContext context) async {
    final ok = await confirmSheet(
      context,
      title: '撤回隐私政策同意？',
      message:
          '撤回后下次启动书影温故会再次显示隐私政策，需要你重新同意才能继续使用。'
          '本操作不会清空你的阅读 / 观影记录。',
      confirmText: '撤回同意',
    );
    if (ok && context.mounted) {
      context.read<AppStore>().resetPrivacyConsent();
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await confirmSheet(
      context,
      title: '清空所有数据？',
      message:
          '会永久删除这台设备上的所有书籍、电影、阅读 / 观影记录，且无法找回。',
      confirmText: '永久删除',
    );
    if (ok && context.mounted) {
      context.read<AppStore>().clearAll();
      if (context.mounted) {
        showToast(context, '已清空所有数据');
      }
    }
  }
}

/* ------------------------------------------------------------------ */
/* 通用小块                                                            */
/* ------------------------------------------------------------------ */

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c.text3,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = destructive ? c.danger : c.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 45),
      child: Divider(height: 1, color: c.border),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: c.text3),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: c.text,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}