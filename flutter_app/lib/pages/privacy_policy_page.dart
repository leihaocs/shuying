import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../store/app_store.dart';
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
  static const String version = AppStore.privacyVersion;

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
                '书影温故不会把阅读和观影记录上传到开发者服务器。书籍、电影、评分和备注保存在这台设备的应用私有 JSON 文件中。',
              ),
              _P(
                '开发者也无法远程读取你的数据，因为我们根本没有你的数据。',
              ),
            ],
          ),

          const _Section(
            title: '2. 本地记录与购买服务',
            children: [
              _P(
                '阅读与观影记录在本机处理，不会自动上传到开发者服务器。购买、恢复购买与查询商品时，应用会连接对应商店的购买服务；购买信息由商店按其隐私政策处理。',
              ),
              _P(
                '当前不提供云同步。导出的 JSON 备份包含你的书影记录、评分与备注，请只交给你信任的设备或文件服务。',
              ),
            ],
          ),

          const _Section(
            title: '3. 基础依赖与第三方服务',
            children: [
              _P(
                '书影温故使用 Flutter、provider、shared_preferences 等基础组件，安卓 Google Play 版本使用 Play Billing，iOS 使用系统 StoreKit。我们不接入广告、行为分析或推送 SDK。'
                '应用商店要求的「应用内隐私声明」中所列项，'
                '涉及「设备信息 / 标识符 / 位置 / 通讯录 / 相机 / 麦克风」等，书影温故均不收集。',
              ),
              _P(
                '开发者不将你的书影记录出售或共享给第三方。使用系统文件选择器时，你选择的文件服务可能处理备份；该行为由你主动发起，请参考该服务的隐私政策。',
              ),
            ],
          ),

          const _Section(
            title: '4. 你的数据存在哪里',
            children: [
              _P(
                '阅读 / 观影记录保存在应用沙盒内的本地 JSON 文件中，主题和同意标记等偏好通过 shared_preferences 保存，'
                '与系统其他 App 完全隔离，操作系统权限会阻止其他 App 读取。',
              ),
              _P(
                '卸载可能删除本机数据。当前支持 JSON 文件与文本导出，以及跨端合并导入。请在卸载或更换设备前备份；有完整备份时可重新导入。系统备份行为以设备设置为准。',
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
                '当前版本不申请相机、麦克风、位置、通讯录或通知等运行时权限。文件导入导出使用系统选择器，只访问你选择的文件。应用不读取'
                '设备标识符用于广告追踪。'
                '购买服务需要网络及对应商店账号。',
              ),
              _P(
                '若未来版本引入需要新增权限的功能，'
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
                '本政策可能随版本更新而修订。版本号会标注在页面顶部，政策版本变化后会重新显示同意页，请你确认。',
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
