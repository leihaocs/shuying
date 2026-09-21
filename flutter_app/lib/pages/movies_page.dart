import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/movies.dart' as ml;
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';
import '../widgets/movie_tile.dart';
import 'home_shell.dart';
import 'movie_detail_page.dart';

class MoviesPage extends StatefulWidget {
  const MoviesPage({super.key});

  @override
  State<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends State<MoviesPage> {
  int _filter = 0; // 0 全部 1 想看 2 已看

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final store = context.watch<AppStore>();

    final all = [...store.movies]
      ..sort((a, b) => ml.movieLastTouch(b).compareTo(ml.movieLastTouch(a)));

    final want = all.where((m) => m.watches.isEmpty).toList();
    final watched = all.where((m) => m.watches.isNotEmpty).toList();
    final list = _filter == 0 ? all : (_filter == 1 ? want : watched);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          PageHeader(
            title: '电影',
            subtitle: all.isEmpty
                ? '还没有片子，点右下角加一部'
                : '共 ${all.length} 部 · 已看 ${watched.length} 部',
          ),
          SegmentedBar(
            index: _filter,
            onChanged: (i) => setState(() => _filter = i),
            items: [
              SegItem('全部', all.length),
              SegItem('想看', want.length),
              SegItem('已看', watched.length),
            ],
          ),
          Expanded(
            child: list.isEmpty
                ? ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      EmptyState(
                        icon: all.isEmpty ? '🎬' : '🔍',
                        title: all.isEmpty ? '片单还是空的' : '这里还没有电影',
                        desc: all.isEmpty
                            ? '点右下角的 + 添加第一部电影\n名称和导演必填'
                            : '换个分类看看，或者添加一部新电影',
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                    children: [
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
                  ),
          ),
        ],
      ),
    );
  }
}
