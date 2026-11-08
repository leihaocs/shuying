import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/books.dart' as bl;
import '../models/models.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';
import '../widgets/book_tile.dart';
import '../widgets/library_filters.dart';
import 'book_detail_page.dart';
import 'home_shell.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  int _filter = 0;
  String? _tag;
  int? _minimumRating;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
    final query = _search.text.trim().toLowerCase();
    final filtering =
        query.isNotEmpty || _tag != null || _minimumRating != null;
    final tags = normalizeTags([
      for (final book in all) ...book.tags,
      if (_tag != null) _tag!,
    ]).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final list = all
        .where((b) =>
            (target == null || bl.bookStatus(b) == target) &&
            (_tag == null || b.tags.any((tag) => tag.toLowerCase() == _tag)) &&
            matchesRating(b.rating, _minimumRating) &&
            [b.title, b.author, b.edition, b.note, ...b.tags]
                .any((text) => (text ?? '').toLowerCase().contains(query)))
        .toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Column(children: [
              PageHeader(
                title: '书架',
                subtitle: all.isEmpty
                    ? '还没有书，点右下角加一本'
                    : '共 ${all.length} 本 · ${all.where((b) => bl.activeRound(b) != null).length} 本在读',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  key: const Key('book-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜索书名、作者、版本、标签或备注',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空搜索',
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
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
              LibraryFilters(
                tags: tags,
                tag: _tag,
                minimumRating: _minimumRating,
                ratingLabel: '书籍评分',
                onTagChanged: (value) => setState(() => _tag = value),
                onRatingChanged: (value) =>
                    setState(() => _minimumRating = value),
                onReset: () => setState(() {
                  _tag = null;
                  _minimumRating = null;
                }),
              ),
            ]),
          ),
          SliverPadding(
            padding: list.isEmpty
                ? const EdgeInsets.symmetric(horizontal: 16)
                : const EdgeInsets.fromLTRB(16, 12, 16, 140),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (list.isEmpty)
                  EmptyState(
                    icon: all.isEmpty ? '📚' : '🔍',
                    title: filtering
                        ? '没有找到匹配的书籍'
                        : all.isEmpty
                            ? '书架还是空的'
                            : '这个分类下还没有书',
                    desc: filtering
                        ? '试试其他关键词，或调整分类、标签和评分'
                        : all.isEmpty
                            ? '点右下角的 + 添加第一本书\n只需填写书名，其余可以以后再补'
                            : '换个分类看看，或者添加一本新书',
                  )
                else ...[
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
              ]),
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
