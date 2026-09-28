import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/bits.dart';

/// 隐私政策正文。
///
/// [showAppBar] 控制是否带顶部导航栏：
///   - true  : 在「设置」里以普通页面形式展示，可返回
///   - false : 在「首次启动同意页」中作为全屏内容展示，无返回按钮
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  /// 当前文本生效版本号，与设置页/应用市场审核版本对齐。
  static const String version = '2026-09-21';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final body = _PrivacyPolicyBody();

    if (!showAppBar) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(child: body),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          const NavBar(title: '隐私政策'),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _PrivacyPolicyBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部卡片
          CardBox(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🔒', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      '书影温故 · 隐私政策',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '生效日期：${PrivacyPolicyPage.version}',
                  style: TextStyle(fontSize: 12, color: c.text3),
                ),
                const SizedBox(height: 10),
                Text(
                  '我们非常重视你的隐私。这份政策用通俗的语言告诉你：书影温故会采集什么、不采集什么、你的数据存在哪里、以及你能怎么做。',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: c.text2,
                    height: 1.75,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          const _Section(
            title: '1. 我们不采集你的数据',
            children: [
              _P(
                '书影温故不会上传你的任何数据到服务器。整本书的阅读记录、电影观影记录、评分、备注，全部只保存在你这台设备的本地数据库中。',
              ),
              _P(
                '开发者也无法远程读取你的数据，因为我们根本没有你的数据。',
              ),
            ],
          ),

          const _Section(
            title: '2. 我们不申请网络权限',
            children: [
              _P(
                '书影温故默认不连接互联网。Android / iOS / 鸿蒙三端的安装包都不包含任何网络请求，也不会在后台悄悄访问网络。',
              ),
              _P(
                '如果未来加入云同步等联网功能，我们会在更新前再次提示并征求你的同意。',
              ),
            ],
          ),

          const _Section(
            title: '3. 我们不接入第三方 SDK',
            children: [
              _P(
                '书影温故不嵌入统计 SDK、推送 SDK、广告 SDK 或任何第三方组件。'
                '应用商店要求的「应用内隐私声明」中所列项，'
                '涉及「设备信息 / 标识符 / 位置 / 通讯录 / 相机 / 麦克风」等，书影温故均不收集。',
              ),
              _P(
                '因此不会出现「第三方共享」「个性化广告」「自动化决策」等情形。',
              ),
            ],
          ),

          const _Section(
            title: '4. 你的数据存在哪里',
            children: [
              _P(
                '所有阅读 / 观影记录保存在设备本地的 SharedPreferences / Keychain / 沙盒目录中，'
                '与系统其他 App 完全隔离，操作系统权限会阻止其他 App 读取。',
              ),
              _P(
                '卸载 App = 永久删除全部数据，且不可恢复。建议你在更换设备前手动导出（当前版本尚未提供导出功能，我们会在后续版本加入）。',
              ),
            ],
          ),

          const _Section(
            title: '5. 你能做的事',
            children: [
              _P(
                '查看与修改：你随时可以在书影温故的「设置」页面访问本政策。',
              ),
              _P(
                '清空数据：你可以在「设置 → 清空所有数据」中删除全部本地记录。',
              ),
              _P(
                '撤回同意：你可以在「设置 → 撤回隐私政策同意」中清除同意记录，下次启动 App 时将再次显示本政策。',
              ),
            ],
          ),

          const _Section(
            title: '6. 权限说明',
            children: [
              _P(
                '当前版本不申请任何系统权限：不申请网络、通知、存储、相机、麦克风、'
                '位置、通讯录、日历等权限，也不读取设备标识符。'
                '所有功能都可在零权限状态下正常使用。',
              ),
              _P(
                '若未来版本引入通知提醒、数据备份等功能需要新增权限，'
                '我们会在更新说明中告知，并由你在系统弹窗中自行决定是否授权。',
              ),
            ],
          ),

          const _Section(
            title: '7. 儿童隐私',
            children: [
              _P(
                '书影温故不针对 14 岁以下儿童设计，也不会主动收集儿童信息。若你为孩子代为使用，请协助其阅读并理解本政策。',
              ),
            ],
          ),

          const _Section(
            title: '8. 政策更新',
            children: [
              _P(
                '本政策可能随版本更新而修订。版本号会标注在页面顶部，更新生效后会再次弹出首次启动同意页，请你重新确认。',
              ),
            ],
          ),

          const _Section(
            title: '9. 联系我们',
            children: [
              _P('如果你对隐私政策有任何疑问或反馈，欢迎联系我们：'),
              _Bullet('邮箱：380174722@qq.com'),
            ],
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              '— 书影温故团队',
              style: TextStyle(fontSize: 12, color: c.text3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: c.text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _P extends StatelessWidget {
  // ignore: unused_element_parameter
  const _P(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          color: c.text2,
          height: 1.75,
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  // ignore: unused_element_parameter
  const _Bullet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: c.text2,
                height: 1.75,
              ),
            ),
          ),
        ],
      ),
    );
  }
}