import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/books.dart' as bl;
import '../domain/fmt.dart';
import '../models/models.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';
import '../widgets/progress_ring.dart';
import '../widgets/sheets.dart';

class BookDetailPage extends StatelessWidget {
  const BookDetailPage({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final book = store.bookById(bookId);
    final c = AppColors.of(context);

    if (book == null) {
      return Scaffold(
        backgroundColor: c.bg,
        // Column is not const in the older HarmonyOS Flutter SDK.
        // ignore: prefer_const_constructors
        body: SafeArea(
          // ignore: prefer_const_constructors
          child: Column(
            children: const [
              NavBar(title: '书籍'),
              Expanded(
                child: EmptyState(icon: '🗑️', title: '这本书已经不在书架上了'),
              ),
            ],
          ),
        ),
      );
    }

    final active = bl.activeRound(book);
    final status = bl.bookStatus(book);
    final pct = bl.roundProgress(book, active);
    final summary = bl.bookSummary(book);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NavBar(
              title: book.title,
              actions: [
                RoundIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: '编辑',
                  onPressed: () => showBookSheet(context, book: book),
                ),
                RoundIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: '删除',
                  onPressed: () async {
                    final ok = await confirmSheet(
                      context,
                      title: '删除《${book.title}》？',
                      message: '这本书记下的 ${summary.totalLogs} 条阅读记录会一起删掉，无法恢复。',
                    );
                    if (!ok || !context.mounted) return;
                    store.removeBook(book.id);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _Hero(book: book, status: status),
                  if (active != null) ...[
                    const SizedBox(height: 18),
                    _ProgressCard(book: book, round: active, percent: pct),
                  ],
                  const SizedBox(height: 16),
                  _Actions(book: book, active: active, status: status),
                  const SizedBox(height: 24),
                  if (active != null) ...[
                    SectionTitle(
                      '第 ${active.index} 轮 · 阅读记录',
                      trailing: Text(
                        '${bl.roundLogCount(active)} 条',
                        style: TextStyle(fontSize: 12, color: c.text3),
                      ),
                    ),
                    if (active.logs.isEmpty)
                      CardBox(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '还没有记录。读完之后点「记录本次阅读」，填页数或时长，顺便估个进度。',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: c.text3,
                            height: 1.7,
                          ),
                        ),
                      )
                    else
                      _LogTimeline(book: book, round: active),
                    const SizedBox(height: 24),
                  ],
                  SectionTitle(
                    '阅读轮次',
                    trailing: Text(
                      '共 ${book.rounds.length} 轮',
                      style: TextStyle(fontSize: 12, color: c.text3),
                    ),
                  ),
                  if (book.rounds.isEmpty)
                    CardBox(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '还没有开始读。点上面的「开始阅读」进入第 1 轮；\n以前读过的，可以用「补记往期阅读」补上时间。',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: c.text3,
                          height: 1.7,
                        ),
                      ),
                    )
                  else ...[
                    for (final r in bl.allRounds(book))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RoundCard(book: book, round: r),
                      ),
                  ],
                  const SizedBox(height: 24),
                  const SectionTitle('书籍信息'),
                  CardBox(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: Column(
                      children: [
                        _InfoRow('作者', book.author),
                        _InfoRow(
                            '总页数',
                            book.totalPages == null
                                ? '—'
                                : '${book.totalPages} 页'),
                        _InfoRow('累计阅读',
                            '${summary.totalPages} 页 · ${formatDuration(summary.totalMinutes)}'),
                        _InfoRow('记录条数', '${summary.totalLogs} 条'),
                        _InfoRow('加入时间', formatDate(book.createdAt)),
                        if (book.note != null)
                          _InfoRow('备注', book.note!, multiline: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* 顶部信息                                                            */
/* ------------------------------------------------------------------ */

class _Hero extends StatelessWidget {
  const _Hero({required this.book, required this.status});

  final Book book;
  final BookStatus status;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookCover(
          cover: book.cover,
          accent: book.accent,
          width: 92,
          height: 124,
          fontSize: 40,
          radius: 12,
          shadow: true,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                book.author,
                style: TextStyle(fontSize: 13.5, color: c.text2),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  BookStatusPill(book),
                  if (book.totalPages != null)
                    Pill(
                      text: '${book.totalPages} 页',
                      background: c.surface2,
                      foreground: c.text2,
                    ),
                  if (book.rounds.length > 1)
                    Pill(
                      text: '读过 ${book.rounds.length} 轮',
                      background: c.surface2,
                      foreground: c.text2,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ */
/* 进度卡片                                                            */
/* ------------------------------------------------------------------ */

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.book,
    required this.round,
    required this.percent,
  });

  final Book book;
  final ReadingRound round;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return CardBox(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ProgressRing(value: percent / 100, size: 104, stroke: 10),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 ${round.index} 轮阅读中',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '始于 ${formatDate(round.startedAt)}',
                  style: TextStyle(fontSize: 12.5, color: c.text3),
                ),
                const SizedBox(height: 10),
                StatGrid(
                  cells: [
                    StatCell(
                      value: '${bl.roundPages(round)}',
                      label: '已读页数',
                    ),
                    StatCell(
                      value: formatDuration(bl.roundMinutes(round)),
                      label: '本轮时长',
                    ),
                    StatCell(
                      value: '${bl.roundLogCount(round)}',
                      label: '记录条数',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* 操作区                                                              */
/* ------------------------------------------------------------------ */

class _Actions extends StatelessWidget {
  const _Actions({
    required this.book,
    required this.active,
    required this.status,
  });

  final Book book;
  final ReadingRound? active;
  final BookStatus status;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();

    return Column(
      children: [
        if (active != null)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppButton(
                  label: '记录本次阅读',
                  kind: BtnKind.primary,
                  icon: Icons.add_rounded,
                  expand: true,
                  onPressed: () async {
                    final ok = await showLogSheet(
                      context,
                      book: book,
                      round: active!,
                    );
                    if (ok == true && context.mounted) {
                      showToast(context, '已记下这一笔');
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: '读完了',
                  kind: BtnKind.soft,
                  expand: true,
                  onPressed: () async {
                    final ok = await confirmSheet(
                      context,
                      title: '读完了第 ${active!.index} 轮？',
                      message: '完成后这本书会变成「已读 ${book.rounds.length} 次」，'
                          '想再读可以随时点「再读一次」。',
                      confirmText: '读完了',
                    );
                    if (!ok || !context.mounted) return;
                    store.finishRound(book.id, active!.id);
                    showToast(context, '恭喜读完第 ${active!.index} 次');
                  },
                ),
              ),
            ],
          )
        else if (status == BookStatus.finished)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppButton(
                  label: '再读一次',
                  kind: BtnKind.primary,
                  icon: Icons.replay_rounded,
                  expand: true,
                  onPressed: () {
                    store.startReading(book.id);
                    showToast(
                      context,
                      '开始第 ${book.rounds.length + 1} 轮阅读',
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: '补记往期',
                  kind: BtnKind.soft,
                  expand: true,
                  onPressed: () => showPastRoundSheet(context, book: book),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppButton(
                  label: '开始阅读',
                  kind: BtnKind.primary,
                  icon: Icons.play_arrow_rounded,
                  expand: true,
                  onPressed: () {
                    store.startReading(book.id);
                    showToast(context, '开始第 1 轮阅读');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: '补记往期',
                  kind: BtnKind.soft,
                  expand: true,
                  onPressed: () => showPastRoundSheet(context, book: book),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ */
/* 阅读记录时间线                                                      */
/* ------------------------------------------------------------------ */

class _LogTimeline extends StatelessWidget {
  const _LogTimeline({required this.book, required this.round});

  final Book book;
  final ReadingRound round;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final logs = bl.sortedLogs(round);

    return Container(
      padding: const EdgeInsets.only(left: 24),
      child: Stack(
        children: [
          Positioned(
            left: 5,
            top: 10,
            bottom: 10,
            child: Container(width: 2, color: c.surface3),
          ),
          Column(
            children: [
              for (final l in logs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -24,
                        top: 10,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.surface,
                            border: Border.all(color: c.accent, width: 2.5),
                          ),
                        ),
                      ),
                      CardBox(
                        padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        relativeDay(l.at),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: c.text,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        formatDateTime(l.at).substring(11),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: c.text3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 2,
                                    children: [
                                      if (l.pages != null)
                                        _How('📄 ${l.pages} 页'),
                                      if (l.minutes != null)
                                        _How('⏱ ${formatDuration(l.minutes)}'),
                                      if (l.progress != null)
                                        _How('📈 进度 ${l.progress}%'),
                                      if (l.pages == null &&
                                          l.minutes == null &&
                                          l.progress == null)
                                        const _How('（仅备注）'),
                                    ],
                                  ),
                                  if (l.note != null) ...[
                                    const SizedBox(height: 7),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.only(top: 7),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: c.border,
                                            width: 1,
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        l.note!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: c.text2,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded,
                                  size: 16, color: c.text3),
                              splashRadius: 18,
                              onPressed: () async {
                                final ok = await confirmSheet(
                                  context,
                                  title: '删除这条记录？',
                                  message: formatDateTime(l.at),
                                  confirmText: '删除',
                                );
                                if (!ok || !context.mounted) return;
                                context.read<AppStore>().removeLog(
                                      book.id,
                                      l.id,
                                    );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _How extends StatelessWidget {
  const _How(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      text,
      style: TextStyle(fontSize: 13, color: c.text2),
    );
  }
}

/* ------------------------------------------------------------------ */
/* 单轮卡片                                                            */
/* ------------------------------------------------------------------ */

class _RoundCard extends StatefulWidget {
  const _RoundCard({required this.book, required this.round});

  final Book book;
  final ReadingRound round;

  @override
  State<_RoundCard> createState() => _RoundCardState();
}

class _RoundCardState extends State<_RoundCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.round.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final r = widget.round;
    final done = !r.isActive;

    return CardBox(
      padding: const EdgeInsets.all(13),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? c.okSoft : c.accentSoft,
                ),
                child: Text(
                  '${r.index}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: done ? c.ok : c.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第 ${r.index} 轮 · ${done ? '已读完' : '进行中'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done
                          ? '${formatDate(r.startedAt)} → ${formatDate(r.finishedAt)}'
                          : '始于 ${formatDate(r.startedAt)}',
                      style: TextStyle(fontSize: 12, color: c.text3),
                    ),
                  ],
                ),
              ),
              if (r.logs.isNotEmpty)
                IconButton(
                  icon: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: c.text3,
                  ),
                  splashRadius: 18,
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: c.text3),
                splashRadius: 18,
                onPressed: () async {
                  final ok = await confirmSheet(
                    context,
                    title: '删除第 ${r.index} 轮记录？',
                    message: r.logs.isEmpty
                        ? '这一轮的起止时间会被移除。'
                        : '这一轮下的 ${r.logs.length} 条记录会一起删掉。',
                  );
                  if (!ok || !context.mounted) return;
                  context.read<AppStore>().removeRound(
                        widget.book.id,
                        r.id,
                      );
                },
              ),
            ],
          ),
          if (r.logs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${bl.roundPages(r)} 页 · ${formatDuration(bl.roundMinutes(r))} · ${bl.roundLogCount(r)} 条记录',
                    style: TextStyle(fontSize: 12.5, color: c.text2),
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              _LogTimeline(book: widget.book, round: r),
            ],
          ],
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* 信息行                                                              */
/* ------------------------------------------------------------------ */

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.multiline = false});

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: c.text3),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: c.text, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
