import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../store/app_store.dart';
import '../services/backup_files.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';

/// 数据备份与恢复：把全部记录导出成 JSON 文本，或粘贴 JSON 文本导入。
///
/// 三端 JSON 文件迁移，也保留文本复制；仅合并，不提供覆盖导入。
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

  Future<void> _doImport() async {
    final text = _importCtrl.text.trim();
    if (text.isEmpty) {
      _msg('请先粘贴备份文本');
      return;
    }
    try {
      final n = context.read<AppStore>().importJson(text);
      final nb = n['books'] ?? 0;
      final nm = n['movies'] ?? 0;
      if (!await context.read<AppStore>().flush()) {
        throw StateError('合并完成但保存失败，请重试保存并保留原备份');
      }
      if (!mounted) return;
      _msg('合并完成：书籍 $nb 条、电影 $nm 条，现有记录已保留');
      _importCtrl.clear();
      setState(() => _exported = '');
    } catch (e) {
      if (!mounted) return;
      _msg('导入失败：$e');
    }
  }

  Future<void> _saveFile() async {
    try {
      final store = context.read<AppStore>();
      final text = store.exportJson();
      final saved = await BackupFiles.save(text);
      if (mounted && saved) _msg('JSON 文件已导出，可在其他端合并导入');
    } catch (_) {
      if (mounted) _msg('文件导出失败，请重试或复制备份文本');
    }
  }

  Future<void> _openFile() async {
    try {
      final text = await BackupFiles.open();
      if (!mounted || text == null) return;
      _importCtrl.text = text;
      _msg('已读取文件，请点击合并导入');
    } catch (_) {
      if (mounted) _msg('无法读取文件，请选择不超过 20 MB 的 JSON 备份');
    }
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
                    'iOS、安卓与鸿蒙共用 JSON 备份。导入只合并、不清空，'
                    '同 ID 的轮次与记录去重；同名但不同 ID 的条目分别保留。'
                    '卸载前请备份，'
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
                      _actionButton(c,
                          icon: Icons.save_alt,
                          label: '导出 JSON 文件（免费）',
                          onTap: _saveFile),
                      const SizedBox(height: 8),
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
                      _actionButton(c,
                          icon: Icons.folder_open,
                          label: '选择 JSON 文件',
                          onTap: _openFile),
                      const SizedBox(height: 12),
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
                        onTap: _doImport,
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
