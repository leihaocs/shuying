import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/sheets.dart';
import 'books_page.dart';
import 'movies_page.dart';
import 'stats_page.dart';

class HomeShell extends StatefulWidget {
  /// [initialIndex] 仅用于上架截图（`--dart-define=SHUYING_TAB=n`）直达指定页，
  /// 正常运行恒为 0。
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  static const List<_TabSpec> _tabs = [
    _TabSpec('📚', '书架'),
    _TabSpec('🎬', '电影'),
    _TabSpec('📊', '统计'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: IndexedStack(
        index: _index,
        children: const [BooksPage(), MoviesPage(), StatsPage()],
      ),
      floatingActionButton: _index == 2
          ? null
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: () {
                  if (_index == 0) {
                    showBookSheet(context);
                  } else {
                    showMovieSheet(context);
                  }
                },
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: c.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.55),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _index = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: _index == i ? 1.0 : 0.5,
                          child: Text(
                            _tabs[i].icon,
                            style: const TextStyle(fontSize: 19, height: 1.1),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tabs[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _index == i ? c.accent : c.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.icon, this.label);

  final String icon;
  final String label;
}

/// 各页面共用的标题区
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: c.text3),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 「全部 / 想读 / 在读 …」横向分段筛选
class SegmentedBar extends StatelessWidget {
  const SegmentedBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<SegItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final active = i == index;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? c.text : c.surface,
                border: Border.all(color: active ? c.text : c.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Text(
                    items[i].label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: active ? c.bg : c.text2,
                    ),
                  ),
                  if (items[i].count != null) ...[
                    const SizedBox(width: 4),
                    Opacity(
                      opacity: 0.55,
                      child: Text(
                        '${items[i].count}',
                        style: TextStyle(
                          fontSize: 12,
                          color: active ? c.bg : c.text2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SegItem {
  const SegItem(this.label, [this.count]);

  final String label;
  final int? count;
}
