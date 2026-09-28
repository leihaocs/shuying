import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../domain/books.dart' show roundMinutes, roundPages, roundProgress;
import '../domain/fmt.dart';
import '../models/models.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import 'bits.dart';

/* ------------------------------------------------------------------ */
/* 通用外壳                                                            */
/* ------------------------------------------------------------------ */

Future<T?> _openSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.92,
      ),
      child: _SheetFrame(title: title, subtitle: subtitle, child: child),
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 9),
              decoration: BoxDecoration(
                color: c.surface3,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(fontSize: 12.5, color: c.text3),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// 底部按钮区
class SheetFooter extends StatelessWidget {
  const SheetFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: child,
    );
  }
}

/// 表单主体：可滚动
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* 表单原子组件                                                        */
/* ------------------------------------------------------------------ */

class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.label,
    this.required = false,
    this.optional = false,
    this.error,
    this.hint,
    required this.child,
  });

  final String label;
  final bool required;
  final bool optional;
  final String? error;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.text2,
                  ),
                ),
                if (required)
                  Text(' *',
                      style: TextStyle(color: c.accent, fontSize: 12.5)),
                if (optional)
                  Text(
                    '  选填',
                    style: TextStyle(color: c.text3, fontSize: 11.5),
                  ),
              ],
            ),
          ),
          child,
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error!,
                style: TextStyle(fontSize: 12.5, color: c.danger),
              ),
            ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                hint!,
                style: TextStyle(fontSize: 12, color: c.text3),
              ),
            ),
        ],
      ),
    );
  }
}

/// 数字输入框（带后缀单位）
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    this.hintText,
    this.suffix,
  });

  final TextEditingController controller;
  final String? hintText;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        hintText: hintText,
        suffixText: suffix,
      ),
    );
  }
}

/// 可点击的日期/时间输入行
class PickerRow extends StatelessWidget {
  const PickerRow({
    super.key,
    required this.text,
    required this.onTap,
    this.icon = Icons.event_rounded,
  });

  final String text;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: c.text3),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(fontSize: 15, color: c.text)),
          ],
        ),
      ),
    );
  }
}

/// emoji 选择器
class EmojiPicker extends StatelessWidget {
  const EmojiPicker({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final e in kCovers)
          GestureDetector(
            onTap: () => onChanged(e),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: e == value ? c.accentSoft : c.surface2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: e == value ? c.accent : Colors.transparent,
                ),
              ),
              child: Text(e, style: const TextStyle(fontSize: 19, height: 1.2)),
            ),
          ),
      ],
    );
  }
}

/// 主题色选择器
class ColorPicker extends StatelessWidget {
  const ColorPicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in kAccents)
          GestureDetector(
            onTap: () => onChanged(a),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Color(a),
                shape: BoxShape.circle,
                border: Border.all(
                  color: a == value ? c.text : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ */
/* 日期时间选择                                                        */
/* ------------------------------------------------------------------ */

Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1950),
    lastDate: DateTime.now().add(const Duration(days: 1)),
  );
  if (date == null) return null;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

Future<DateTime?> pickDayOnly(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1950),
    lastDate: DateTime.now().add(const Duration(days: 1)),
  );
  if (date == null) return null;
  return DateTime(date.year, date.month, date.day, 12);
}

/* ------------------------------------------------------------------ */
/* 1. 书籍表单                                                         */
/* ------------------------------------------------------------------ */

Future<bool?> showBookSheet(BuildContext context, {Book? book}) {
  return _openSheet<bool>(
    context,
    title: book == null ? '添加书籍' : '编辑书籍',
    subtitle: '书名与作者必填，其余可以以后再补',
    child: _BookForm(existing: book),
  );
}

class _BookForm extends StatefulWidget {
  const _BookForm({this.existing});

  final Book? existing;

  @override
  State<_BookForm> createState() => _BookFormState();
}

class _BookFormState extends State<_BookForm> {
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _pages;
  late final TextEditingController _note;
  late String _cover;
  late int _accent;
  String? _titleErr;
  String? _authorErr;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _title = TextEditingController(text: b?.title ?? '');
    _author = TextEditingController(text: b?.author ?? '');
    _pages = TextEditingController(text: b?.totalPages?.toString() ?? '');
    _note = TextEditingController(text: b?.note ?? '');
    _cover = b?.cover ?? '📖';
    _accent = b?.accent ?? kAccents.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _pages.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final author = _author.text.trim();
    setState(() {
      _titleErr = title.isEmpty ? '书名不能为空' : null;
      _authorErr = author.isEmpty ? '作者不能为空' : null;
    });
    if (title.isEmpty || author.isEmpty) return;

    final store = context.read<AppStore>();
    final input = BookInput(
      title: title,
      author: author,
      totalPages: parseIntOrNull(_pages.text),
      cover: _cover,
      accent: _accent,
      note: _note.text,
    );
    if (widget.existing == null) {
      store.addBook(input);
    } else {
      store.updateBook(widget.existing!.id, input);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SheetBody(
            children: [
              Field(
                label: '书名',
                required: true,
                error: _titleErr,
                child: TextField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: '例如：活着'),
                ),
              ),
              Field(
                label: '作者',
                required: true,
                error: _authorErr,
                child: TextField(
                  controller: _author,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: '例如：余华'),
                ),
              ),
              Field(
                label: '总页数',
                optional: true,
                hint: '填了之后，可以用「读了多少页」自动估算进度',
                child: NumberField(
                  controller: _pages,
                  hintText: '例如：191',
                  suffix: '页',
                ),
              ),
              Field(
                label: '封面',
                optional: true,
                child: EmojiPicker(
                  value: _cover,
                  onChanged: (v) => setState(() => _cover = v),
                ),
              ),
              Field(
                label: '主题色',
                optional: true,
                child: ColorPicker(
                  value: _accent,
                  onChanged: (v) => setState(() => _accent = v),
                ),
              ),
              Field(
                label: '备注',
                optional: true,
                child: TextField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '为什么想读它？',
                  ),
                ),
              ),
            ],
          ),
        ),
        SheetFooter(
          child: AppButton(
            label: widget.existing == null ? '加入书架' : '保存修改',
            kind: BtnKind.primary,
            expand: true,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ */
/* 2. 记录本次阅读                                                     */
/* ------------------------------------------------------------------ */

Future<bool?> showLogSheet(
  BuildContext context, {
  required Book book,
  required ReadingRound round,
}) {
  return _openSheet<bool>(
    context,
    title: '记录本次阅读',
    subtitle: '读了 ${roundPages(round)} 页 · ${formatDuration(roundMinutes(round))}',
    child: _LogForm(book: book, round: round),
  );
}

class _LogForm extends StatefulWidget {
  const _LogForm({required this.book, required this.round});

  final Book book;
  final ReadingRound round;

  @override
  State<_LogForm> createState() => _LogFormState();
}

class _LogFormState extends State<_LogForm> {
  late DateTime _at;
  late final TextEditingController _pages;
  late final TextEditingController _minutes;
  late final TextEditingController _note;
  late bool _useProgress;
  late double _progress;
  String? _emptyErr;

  @override
  void initState() {
    super.initState();
    _at = DateTime.now();
    _pages = TextEditingController();
    _minutes = TextEditingController();
    _note = TextEditingController();
    _useProgress = true;
    // 默认停在当前进度上，方便小幅往前调
    _progress = roundProgress(widget.book, widget.round).toDouble();
  }

  @override
  void dispose() {
    _pages.dispose();
    _minutes.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final pages = parseIntOrNull(_pages.text);
    final minutes = parseIntOrNull(_minutes.text);
    final note = _note.text.trim();

    if (pages == null && minutes == null && note.isEmpty && !_useProgress) {
      setState(() => _emptyErr = '至少填一项：页数、时长，或给个进度');
      return;
    }

    context.read<AppStore>().addLog(
          widget.book.id,
          widget.round.id,
          LogInput(
            at: _at,
            pages: pages,
            minutes: minutes,
            progress: _useProgress ? _progress.round() : null,
            note: note,
          ),
        );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final total = widget.book.totalPages;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SheetBody(
            children: [
              Field(
                label: '阅读时间',
                child: PickerRow(
                  text: formatDateTime(_at),
                  onTap: () async {
                    final picked = await pickDateTime(context, _at);
                    if (picked == null || !mounted) return;
                    setState(() => _at = picked);
                  },
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Field(
                      label: '本次读了多少页',
                      optional: true,
                      child: NumberField(
                        controller: _pages,
                        hintText: '0',
                        suffix: '页',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Field(
                      label: '或 读了多久',
                      optional: true,
                      child: NumberField(
                        controller: _minutes,
                        hintText: '0',
                        suffix: '分钟',
                      ),
                    ),
                  ),
                ],
              ),
              Field(
                label: '估计总进度',
                hint: total == null
                    ? '没填总页数时，只能手动估一个百分比'
                    : '也可以不填，系统会按已读 $total 页来估算',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${_progress.round()}%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: c.accent,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        Switch.adaptive(
                          value: _useProgress,
                          activeTrackColor: c.accent,
                          onChanged: (v) => setState(() => _useProgress = v),
                        ),
                      ],
                    ),
                    Slider(
                      value: _progress,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      activeColor: c.accent,
                      onChanged: _useProgress
                          ? (v) => setState(() => _progress = v)
                          : null,
                    ),
                  ],
                ),
              ),
              Field(
                label: '备注',
                optional: true,
                error: _emptyErr,
                child: TextField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: '今天读到了什么？'),
                ),
              ),
            ],
          ),
        ),
        SheetFooter(
          child: AppButton(
            label: '保存记录',
            kind: BtnKind.primary,
            expand: true,
            icon: Icons.check_rounded,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ */
/* 3. 补记往期阅读                                                     */
/* ------------------------------------------------------------------ */

Future<bool?> showPastRoundSheet(BuildContext context, {required Book book}) {
  return _openSheet<bool>(
    context,
    title: '补记往期阅读',
    subtitle: '记下以前读完的时间，不影响当前进度',
    child: _PastRoundForm(book: book),
  );
}

class _PastRoundForm extends StatefulWidget {
  const _PastRoundForm({required this.book});

  final Book book;

  @override
  State<_PastRoundForm> createState() => _PastRoundFormState();
}

class _PastRoundFormState extends State<_PastRoundForm> {
  late DateTime _started;
  late DateTime _finished;
  late final TextEditingController _pages;
  late final TextEditingController _minutes;
  late final TextEditingController _note;
  String? _rangeErr;

  @override
  void initState() {
    super.initState();
    _finished = DateTime.now();
    _started = DateTime.now().subtract(const Duration(days: 7));
    _pages = TextEditingController();
    _minutes = TextEditingController();
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _pages.dispose();
    _minutes.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (_finished.isBefore(_started)) {
      setState(() => _rangeErr = '完成时间不能早于开始时间');
      return;
    }
    context.read<AppStore>().addPastRound(
          widget.book.id,
          PastRoundInput(
            startedAt: _started,
            finishedAt: _finished,
            pages: parseIntOrNull(_pages.text),
            minutes: parseIntOrNull(_minutes.text),
            note: _note.text,
          ),
        );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SheetBody(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Field(
                      label: '开始日期',
                      child: PickerRow(
                        text: formatDate(_started),
                        onTap: () async {
                          final d = await pickDayOnly(context, _started);
                          if (d == null || !mounted) return;
                          setState(() => _started = d);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Field(
                      label: '完成日期',
                      error: _rangeErr,
                      child: PickerRow(
                        text: formatDate(_finished),
                        onTap: () async {
                          final d = await pickDayOnly(context, _finished);
                          if (d == null || !mounted) return;
                          setState(() => _finished = d);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Field(
                      label: '累计页数',
                      optional: true,
                      child: NumberField(
                        controller: _pages,
                        hintText: '0',
                        suffix: '页',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Field(
                      label: '累计时长',
                      optional: true,
                      child: NumberField(
                        controller: _minutes,
                        hintText: '0',
                        suffix: '分钟',
                      ),
                    ),
                  ),
                ],
              ),
              Field(
                label: '备注',
                optional: true,
                child: TextField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: '当时的感受'),
                ),
              ),
            ],
          ),
        ),
        SheetFooter(
          child: AppButton(
            label: '保存这一轮',
            kind: BtnKind.primary,
            expand: true,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ */
/* 4. 电影表单                                                         */
/* ------------------------------------------------------------------ */

Future<bool?> showMovieSheet(BuildContext context, {Movie? movie}) {
  return _openSheet<bool>(
    context,
    title: movie == null ? '添加电影' : '编辑电影',
    subtitle: '名称与导演必填',
    child: _MovieForm(existing: movie),
  );
}

class _MovieForm extends StatefulWidget {
  const _MovieForm({this.existing});

  final Movie? existing;

  @override
  State<_MovieForm> createState() => _MovieFormState();
}

class _MovieFormState extends State<_MovieForm> {
  late final TextEditingController _title;
  late final TextEditingController _director;
  late final TextEditingController _year;
  late final TextEditingController _note;
  String? _titleErr;
  String? _directorErr;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _title = TextEditingController(text: m?.title ?? '');
    _director = TextEditingController(text: m?.director ?? '');
    _year = TextEditingController(text: m?.year ?? '');
    _note = TextEditingController(text: m?.note ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _director.dispose();
    _year.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final director = _director.text.trim();
    setState(() {
      _titleErr = title.isEmpty ? '名称不能为空' : null;
      _directorErr = director.isEmpty ? '导演不能为空' : null;
    });
    if (title.isEmpty || director.isEmpty) return;

    final store = context.read<AppStore>();
    final input = MovieInput(
      title: title,
      director: director,
      year: _year.text,
      note: _note.text,
    );
    if (widget.existing == null) {
      store.addMovie(input);
    } else {
      store.updateMovie(widget.existing!.id, input);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SheetBody(
            children: [
              Field(
                label: '电影名称',
                required: true,
                error: _titleErr,
                child: TextField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(hintText: '例如：肖申克的救赎'),
                ),
              ),
              Field(
                label: '导演',
                required: true,
                error: _directorErr,
                child: TextField(
                  controller: _director,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(hintText: '例如：弗兰克·德拉邦特'),
                ),
              ),
              Field(
                label: '上映年份',
                optional: true,
                child: TextField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: '例如：1994'),
                ),
              ),
              Field(
                label: '备注',
                optional: true,
                child: TextField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: '想看的原因？'),
                ),
              ),
            ],
          ),
        ),
        SheetFooter(
          child: AppButton(
            label: widget.existing == null ? '加入片单' : '保存修改',
            kind: BtnKind.primary,
            expand: true,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ */
/* 5. 观影记录                                                         */
/* ------------------------------------------------------------------ */

Future<bool?> showWatchSheet(BuildContext context, {required Movie movie}) {
  return _openSheet<bool>(
    context,
    title: movie.watches.isEmpty ? '标记为看过' : '再看一次',
    subtitle: movie.watches.isEmpty
        ? '补上观看时间，就变成已看 1 次'
        : '这将是第 ${movie.watches.length + 1} 次观看',
    child: _WatchForm(movie: movie),
  );
}

class _WatchForm extends StatefulWidget {
  const _WatchForm({required this.movie});

  final Movie movie;

  @override
  State<_WatchForm> createState() => _WatchFormState();
}

class _WatchFormState extends State<_WatchForm> {
  late DateTime _at;
  int? _rating;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _at = DateTime.now();
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<AppStore>().addWatch(
          widget.movie.id,
          at: _at,
          rating: _rating,
          note: _note.text,
        );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SheetBody(
            children: [
              Field(
                label: '观看时间',
                child: PickerRow(
                  text: formatDateTime(_at),
                  onTap: () async {
                    final picked = await pickDateTime(context, _at);
                    if (picked == null || !mounted) return;
                    setState(() => _at = picked);
                  },
                ),
              ),
              Field(
                label: '打分',
                optional: true,
                child: StarRow(
                  rating: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                ),
              ),
              Field(
                label: '备注',
                optional: true,
                child: TextField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: '印象最深的一幕'),
                ),
              ),
            ],
          ),
        ),
        SheetFooter(
          child: AppButton(
            label: '保存',
            kind: BtnKind.primary,
            expand: true,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ */
/* 6. 确认弹窗                                                         */
/* ------------------------------------------------------------------ */

Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确定删除',
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    builder: (ctx) {
      final c = AppColors.of(ctx);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 9),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: c.surface3,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(fontSize: 13.5, color: c.text2, height: 1.6),
                ),
              ],
            ),
          ),
          SheetFooter(
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    kind: BtnKind.ghost,
                    expand: true,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: confirmText,
                    kind: BtnKind.danger,
                    expand: true,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
