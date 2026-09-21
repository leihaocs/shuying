import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/books.dart' as bl;
import '../models/models.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';
import '../widgets/book_tile.dart';
import 'book_detail_page.dart';
import 'home_shell.dart';
import 'settings_page.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  int _filter = 0;

  static const List<String> _labels = ['全部', '想读', '在读', '再次阅读', '已读'];

  BookStatus? _statusOf(int filter) {
    switch (filter) {
      case 1:
        return BookStatus.want;
      case 2:
        return BookStatus.reading;
      case 3:
        return BookStatus.rereading;
      case 4:
        return BookStatus.finished;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final store = context.watch<AppStore>();

    final all = [...store.books]
      ..sort((a, b) => bl.bookLastTouch(b).compareTo(bl.bookLastTouch(a)));

    final counts = <int, int>{};
    for (var i = 1; i <= 4; i++) {
      final s = _statusOf(i);
      counts[i] = all.where((b) => bl.bookStatus(b) == s).length;
    }

    final target = _statusOf(_filter);
    final list = target == null
        ? all
        : all.where((b) => bl.bookStatus(b) == target).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          PageHeader(
            title: '书架',
            subtitle: all.isEmpty
                ? '还没有书，点右下角加一本'
                : '共 ${all.length} 本 · ${all.where((b) => bl.activeRound(b) != null).length} 本在读',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoundIconButton(
                  icon: store.themeMode == ThemeMode.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  onPressed: store.toggleTheme,
                  tooltip: '切换主题',
                ),
                RoundIconButton(
                  icon: Icons.settings_outlined,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsPage(),
                    ),
                  ),
                  tooltip: '设置 / 关于',
                ),
              ],
            ),
          ),
          SegmentedBar(
            index: _filter,
            onChanged: (i) => setState(() => _filter = i),
            items: [
              SegItem(_labels[0], all.length),
              for (var i = 1; i <= 4; i++)
                SegItem(_labels[i], counts[i] ?? 0),
            ],
          ),
          Expanded(
            child: list.isEmpty
                ? ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      EmptyState(
                        icon: all.isEmpty ? '📚' : '🔍',
                        title: all.isEmpty ? '书架还是空的' : '这个分类下还没有书',
                        desc: all.isEmpty
                            ? '点右下角的 + 添加第一本书\n书名和作者必填，其余可以以后再补'
                            : '换个分类看看，或者添加一本新书',
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                    children: [
                      for (final b in list)
                        BookTile(
                          book: b,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BookDetailPage(bookId: b.id),
                            ),
                          ),
                        ),
                      _footer(c),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _footer(AppColors c) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Center(
          child: Text(
            '数据只保存在这台设备上',
            style: TextStyle(fontSize: 12, color: c.text3),
          ),
        ),
      );
}
