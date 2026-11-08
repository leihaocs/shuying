import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/backup_files.dart';
import '../widgets/bits.dart';

/// 三端共用的离线帮助；在线页通过系统浏览器打开。
class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  static const githubUrl = 'https://leihaocs.github.io/shuying/support.html';
  static const domesticUrl = 'https://bookmovie-revisit.cn/support.html';
  static const email = '380174722@qq.com';

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  late final Future<String> _url = _readSupportUrl();

  Future<String> _readSupportUrl() async {
    try {
      final url = await BackupFiles.channel.invokeMethod<String>('supportUrl');
      if (url != SupportPage.githubUrl && url != SupportPage.domesticUrl) {
        throw const FormatException('支持地址无效');
      }
      return url!;
    } on MissingPluginException {
      // 旧原生桥接只会打开 GitHub，与其原有行为保持一致。
      return SupportPage.githubUrl;
    }
  }

  Future<void> _open(BuildContext context, String url) async {
    try {
      if (await BackupFiles.channel
              .invokeMethod<bool>('openSupport', {'url': url}) ==
          true) {
        return;
      }
    } catch (_) {
      // 浏览器不可用时仍可复制地址和阅读本地帮助。
    }
    if (context.mounted) showToast(context, '无法打开浏览器，请复制支持网址后访问。');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('帮助与支持')),
      body: SafeArea(
          top: false,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('联系我们',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SelectableText(SupportPage.email),
            TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                      const ClipboardData(text: SupportPage.email));
                  if (context.mounted) showToast(context, '已复制联系邮箱');
                },
                child: const Text('复制联系邮箱')),
            const Text(
                '反馈时请说明手机型号、系统与应用版本、安装渠道、操作步骤及错误提示。截图请遮挡个人信息，不要发送密码、验证码或密钥。'),
            const SizedBox(height: 20),
            const Text('本地数据与换机',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text(
                '记录保存在当前应用的本机私有存储中，不会自动上传到开发者服务器，我们无法远程找回。卸载、清除数据或换机前，请先备份。'),
            const SizedBox(height: 8),
            const Text(
                '打开“设置 → 导出 / 导入记录”，导出 JSON 文件并保存在应用之外。将文件传到新设备，在同一入口导入。三端使用相同备份格式，但不会自动云同步。'),
            const SizedBox(height: 8),
            const Text(
                '导入采用合并方式，不是清空覆盖；同名但不同标识的条目可能保留为两条。删除不随备份传播，旧备份可能恢复已删除记录。导入前建议备份当前数据。'),
            const SizedBox(height: 8),
            const Text(
                '安卓与鸿蒙即使安装在同一手机，也分别保存数据，需要通过导出和合并导入转移。撤回隐私同意不会清空记录；外部备份需自行删除。'),
            const SizedBox(height: 20),
            const Text('Pro 与购买支持',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text(
                '购买仅以当前渠道实际开放能力为准。已支持购买的渠道可使用原商店账号恢复；JSON 备份不迁移购买权益，也不保证不同商店互通。订单与退款请使用购买渠道官方支持入口。'),
            const SizedBox(height: 20),
            FutureBuilder<String>(
                future: _url,
                builder: (context, snapshot) {
                  final url = snapshot.data;
                  if (url == null) {
                    return Text(snapshot.hasError
                        ? '在线支持暂不可用，请通过上方邮箱联系我们。'
                        : '正在加载在线支持…');
                  }
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                            onPressed: () => _open(context, url),
                            child: const Text('打开在线支持页')),
                        SelectableText(url),
                        TextButton(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: url));
                              if (context.mounted) {
                                showToast(context, '已复制支持网址');
                              }
                            },
                            child: const Text('复制支持网址')),
                      ]);
                }),
          ])),
    );
  }
}
