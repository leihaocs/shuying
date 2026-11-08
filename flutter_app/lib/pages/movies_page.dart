import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/movies.dart' as ml;
import '../models/models.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';
import '../widgets/movie_tile.dart';
import '../widgets/library_filters.dart';
import 'home_shell.dart';
import 'movie_detail_page.dart';

class MoviesPage extends StatefulWidget {
  const MoviesPage({super.key});

  @override
  State<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends State<MoviesPage> {
  int _filter = 0; // 全部、想看、已看、多次观看。
  String? _tag;
  int? _minimumRating;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final store = context.watch<AppStore>();

    final all = [...store.movies]
      ..sort((a, b) => ml.movieLastTouch(b).compareTo(ml.movieLastTouch(a)));

    final want =
        all.where((m) => ml.movieStatus(m) == MovieStatus.want).toList();
    final watched =
        all.where((m) => ml.movieStatus(m) == MovieStatus.watched).toList();
    final rewatched =
        all.where((m) => ml.movieStatus(m) == MovieStatus.rewatched).toList();
    final query = _search.text.trim().toLowerCase();
    final filtering =
        query.isNotEmpty || _tag != null || _minimumRating != null;
    final tags = normalizeTags([
      for (final movie in all) ...movie.tags,
      if (_tag != null) _tag!,
    ]).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final list = [all, want, watched, rewatched][_filter]
        .where((m) =>
            (_tag == null || m.tags.any((tag) => tag.toLowerCase() == _tag)) &&
            matchesRating(ml.lastWatch(m)?.rating, _minimumRating) &&
            [m.title, m.director, m.year?.toString() ?? '', m.note, ...m.tags]
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
                title: '电影',
                subtitle: all.isEmpty
                    ? '还没有片子，点右下角加一部'
                    : '共 ${all.length} 部 · 看过 ${watched.length + rewatched.length} 部',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  key: const Key('movie-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜索片名、导演、年份、标签或备注',
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
                  SegItem('全部', all.length),
                  SegItem('想看', want.length),
                  SegItem('已看', watched.length),
                  SegItem('多次观看', rewatched.length),
                ],
              ),
              LibraryFilters(
                tags: tags,
                tag: _tag,
                minimumRating: _minimumRating,
                ratingLabel: '最近观影评分',
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
                    icon: all.isEmpty ? '🎬' : '🔍',
                    title: filtering
                        ? '没有找到匹配的电影'
                        : all.isEmpty
                            ? '片单还是空的'
                            : '这里还没有电影',
                    desc: filtering
                        ? '试试其他关键词，或调整分类、标签和评分'
                        : all.isEmpty
                            ? '点右下角的 + 添加第一部电影\n只需填写名称，导演选填'
                            : '换个分类看看，或者添加一部新电影',
                  )
                else ...[
                  for (final m in list)
                    MovieTile(
                      movie: m,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MovieDetailPage(movieId: m.id),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 8),
                    child: Center(
                      child: Text(
                        '同一部电影可以反复标记「已看」',
                        style: TextStyle(fontSize: 12, color: c.text3),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
