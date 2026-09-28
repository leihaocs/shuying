import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';

/// 数据备份与恢复：把全部记录导出成 JSON 文本，或粘贴 JSON 文本导入。
///
/// 刻意不引入任何文件选择 / 分享插件（鸿蒙 fork 里没有 share_plus），
/// 用「文本 + 剪贴板」这种三端都能跑的方案：导出后粘到备忘录、微信收藏
/// 或发到电脑保存，换设备时再粘贴回来。
class DataBackupPage extends StatefulWidget {
  const DataBackupPage({super.key});

  @override
  State<DataBackupPage> createState() => _DataBackupPageState();
}

class _DataBackupPageState extends State<DataBackupPage> {
  final TextEditingController _importCtrl = TextEditingController();
  String _exported = '';

  @override
  void dispose() {
    _importCtrl.dispose();
    super.dispose();
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _generate() {
    final json = context.read<AppStore>().exportJson();
    setState(() => _exported = json);
  }

  Future<void> _copy() async {
    if (_exported.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _exported));
    _msg('已复制到剪贴板（${_exported.length} 个字符）');
  }

  void _doImport(bool replace) {
    final text = _importCtrl.text.trim();
    if (text.isEmpty) {
      _msg('请先粘贴备份文本');
      return;
    }
    try {
      final n = context.read<AppStore>().importJson(text, replace: replace);
      final nb = n['books'] ?? 0;
      final nm = n['movies'] ?? 0;
      _msg('导入完成：书籍 $nb 条、电影 $nm 条（${replace ? '覆盖' : '合并'}）');
      _importCtrl.clear();
      setState(() => _exported = '');
    } catch (e) {
      _msg('导入失败：$e');
    }
  }

  Future<void> _confirmReplace() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('覆盖导入？'),
        content: const Text(
          '会先清空这台设备上的全部记录，再用文本里的内容替换。此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('覆盖导入'),
          ),
        ],
      ),
    );
    if (ok == true) _doImport(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final store = context.watch<AppStore>();
    final total = store.books.length + store.movies.length;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          const NavBar(title: '数据备份'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                CardBox(
                  child: Text(
                    '当前共 $total 条记录（书籍 ${store.books.length} · '
                    '电影 ${store.movies.length}）。\n'
                    '记录只存在这台设备上，换手机、重装 App 或换开发者签名都会丢失，'
                    '建议定期导出一份存到备忘录或网盘。',
                    style: TextStyle(fontSize: 13, height: 1.6, color: c.text2),
                  ),
                ),

                /* -------- 导出 -------- */
                const SizedBox(height: 20),
                _sectionTitle(c, '导出'),
                const SizedBox(height: 8),
                CardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _actionButton(
                        c,
                        icon: Icons.file_download_outlined,
                        label: '生成备份文本',
                        onTap: _generate,
                      ),
                      if (_exported.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          height: 180,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: c.surface2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.border),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _exported,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.45,
                                color: c.text2,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _actionButton(
                          c,
                          icon: Icons.copy_rounded,
                          label: '复制到剪贴板',
                          onTap: _copy,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '长按上面的文本也能选中复制。',
                          style: TextStyle(fontSize: 11, color: c.text3),
                        ),
                      ],
                    ],
                  ),
                ),

                /* -------- 导入 -------- */
                const SizedBox(height: 20),
                _sectionTitle(c, '导入'),
                const SizedBox(height: 8),
                CardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _importCtrl,
                        minLines: 4,
                        maxLines: 8,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.text,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: '把之前导出的 JSON 文本粘贴到这里',
                          hintStyle: TextStyle(fontSize: 12, color: c.text3),
                          filled: true,
                          fillColor: c.surface2,
                          contentPadding: const EdgeInsets.all(10),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: c.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: c.border, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _actionButton(
                        c,
                        icon: Icons.merge_type_rounded,
                        label: '合并导入（保留现有记录）',
                        onTap: () => _doImport(false),
                      ),
                      const SizedBox(height: 8),
                      _actionButton(
                        c,
                        icon: Icons.restore_rounded,
                        label: '覆盖导入（清空后写入）',
                        destructive: true,
                        onTap: _confirmReplace,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppColors c, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: c.text3,
        ),
      ),
    );
  }

  Widget _actionButton(
    AppColors c, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? c.danger : c.text;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
