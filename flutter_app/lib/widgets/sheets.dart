import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../domain/books.dart'
    show roundMinutes, roundPages, roundProgress, roundReflection;
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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            child: Wrap(
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
                  Text(' *', style: TextStyle(color: c.accent, fontSize: 12.5)),
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
            Expanded(
                child: Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: c.text))),
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

/// 日期与可选时间分开选择，三端统一使用滚轮选择时分。
class RecordDateTimeField extends StatefulWidget {
  const RecordDateTimeField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.onTimeSelected,
      this.preserveTime = false});
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback? onTimeSelected;
  final bool preserveTime;

  @override
  State<RecordDateTimeField> createState() => _RecordDateTimeFieldState();
}

class _RecordDateTimeFieldState extends State<RecordDateTimeField> {
  late bool _timeSelected;

  @override
  void initState() {
    super.initState();
    _timeSelected = widget.preserveTime;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Field(
          label: widget.label,
          child: PickerRow(
            key: const Key('record-date'),
            text: formatDate(widget.value),
            onTap: () async {
              final date = await pickDayOnly(context, widget.value);
              if (date == null || !mounted) return;
              final value = _timeSelected ? widget.value : DateTime.now();
              widget.onChanged(DateTime(
                  date.year, date.month, date.day, value.hour, value.minute));
            },
          )),
      Field(
          label: '时间',
          hint: _timeSelected ? '点击可修改时间' : '默认使用保存记录时的当前时间，可点此修改',
          child: PickerRow(
            key: const Key('record-time'),
            icon: Icons.schedule_rounded,
            text: formatDateTime(widget.value).substring(11) +
                (!_timeSelected && isSameDay(widget.value, DateTime.now())
                    ? '（当前时间）'
                    : ''),
            onTap: () async {
              final time = await pickWheelTime(context, widget.value);
              if (time == null || !mounted) return;
              setState(() => _timeSelected = true);
              widget.onTimeSelected?.call();
              widget.onChanged(time);
            },
          )),
    ]);
  }
}

Future<DateTime?> pickWheelTime(BuildContext context, DateTime initial) {
  FocusScope.of(context).unfocus();
  var selected = initial;
  final c = AppColors.of(context);
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: SizedBox(
              height: 300,
              child: Column(children: [
                Row(children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  const Expanded(
                      child: Text('选择时间', textAlign: TextAlign.center)),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      child: const Text('确定')),
                ]),
                Expanded(
                    child: CupertinoTheme(
                  data: CupertinoThemeData(
                      brightness: Theme.of(ctx).brightness,
                      primaryColor: c.accent),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: initial,
                    onDateTimeChanged: (time) => selected = DateTime(
                        initial.year,
                        initial.month,
                        initial.day,
                        time.hour,
                        time.minute),
                  ),
                )),
              ])),
        )),
  );
}

Future<DateTime?> pickDayOnly(BuildContext context, DateTime initial) async {
  FocusScope.of(context).unfocus();
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1),
    lastDate: DateTime.now(),
  );
  if (date == null) return null;
  return recordTimestamp(date);
}

/* ------------------------------------------------------------------ */
/* 1. 书籍表单                                                         */
/* ------------------------------------------------------------------ */

Future<bool?> showBookSheet(BuildContext context, {Book? book}) {
  return _openSheet<bool>(
    context,
    title: book == null ? '添加书籍' : '编辑书籍',
    subtitle: '只需填写书名，其余可以以后再补',
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
  late final TextEditingController _edition;
  late final TextEditingController _pages;
  late final TextEditingController _note;
  late String _cover;
  late int _accent;
  int? _rating;
  String? _titleErr;
  BookStatus _initialStatus = BookStatus.want;
  final _readPages = TextEditingController();
  final _readMinutes = TextEditingController();
  String? _statusErr;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _title = TextEditingController(text: b?.title ?? '');
    _author = TextEditingController(text: b?.author ?? '');
    _edition = TextEditingController(text: b?.edition ?? '');
    _pages = TextEditingController(text: b?.totalPages?.toString() ?? '');
    _note = TextEditingController(text: b?.note ?? '');
    _cover = b?.cover ?? '📖';
    _accent = b?.accent ?? kAccents.first;
    _rating = b?.rating;
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _edition.dispose();
    _pages.dispose();
    _note.dispose();
    _readPages.dispose();
    _readMinutes.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final author = _author.text.trim();
    setState(() {
      _titleErr = title.isEmpty ? '书名不能为空' : null;
      _statusErr = null;
    });
    if (title.isEmpty) return;

    final store = context.read<AppStore>();
    final input = BookInput(
      title: title,
      author: author,
      edition: _edition.text,
      totalPages: parseIntOrNull(_pages.text),
      cover: _cover,
      accent: _accent,
      rating: _rating,
      note: _note.text,
    );
    if (widget.existing == null) {
      try {
        store.addBook(input,
            initialStatus: _initialStatus,
            readPages: _initialStatus == BookStatus.reading
                ? parseIntOrNull(_readPages.text)
                : null,
            readMinutes: _initialStatus == BookStatus.reading
                ? parseIntOrNull(_readMinutes.text)
                : null);
      } on ArgumentError catch (error) {
        setState(() => _statusErr = error.message?.toString() ?? '请检查阅读信息');
        return;
      }
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
                optional: true,
                child: TextField(
                  controller: _author,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: '例如：余华'),
                ),
              ),
              Field(
                label: '出版社 / 版本',
                optional: true,
                child: TextField(
                  controller: _edition,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(hintText: '例如：人民文学出版社 · 第3版'),
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
                label: '评分（10分制）',
                optional: true,
                child: RatingPicker(
                    rating: _rating,
                    onChanged: (v) => setState(() => _rating = v)),
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
              if (widget.existing == null) ...[
                Field(
                    key: const Key('book-initial-status'),
                    label: '阅读状态',
                    error: _statusErr,
                    child: Wrap(spacing: 8, children: [
                      for (final status in [
                        BookStatus.want,
                        BookStatus.finished,
                        BookStatus.reading
                      ])
                        ChoiceChip(
                            label: Text(status == BookStatus.want
                                ? '想读'
                                : status == BookStatus.finished
                                    ? '读过'
                                    : '在读'),
                            selected: _initialStatus == status,
                            onSelected: (_) =>
                                setState(() => _initialStatus = status)),
                    ])),
                if (_initialStatus == BookStatus.reading) ...[
                  Field(
                      label: '已读页数',
                      optional: true,
                      child: NumberField(
                          key: const Key('book-initial-pages'),
                          controller: _readPages,
                          hintText: '例如：30',
                          suffix: '页')),
                  Field(
                      label: '已读时长',
                      optional: true,
                      child: NumberField(
                          key: const Key('book-initial-minutes'),
                          controller: _readMinutes,
                          hintText: '例如：60',
                          suffix: '分钟')),
                ],
              ],
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
  ReadingLog? log,
}) {
  if (!round.isActive && log == null) {
    return showPastRoundSheet(context, book: book, round: round);
  }
  return _openSheet<bool>(
    context,
    title: log == null ? '记录本次阅读' : '修改阅读记录',
    subtitle: round.isActive
        ? '本轮累计 ${roundPages(round)} 页 · ${formatDuration(roundMinutes(round))}；下方填写单次阅读量'
        : '已读完的轮次：可改日期、页数与时长，进度不再调整',
    child: _LogForm(book: book, round: round, existing: log),
  );
}

class _LogForm extends StatefulWidget {
  const _LogForm({required this.book, required this.round, this.existing});

  final Book book;
  final ReadingRound round;
  final ReadingLog? existing;

  @override
  State<_LogForm> createState() => _LogFormState();
}

class _LogFormState extends State<_LogForm> {
  late DateTime _at;
  bool _explicitTime = false;
  late final TextEditingController _pages;
  late final TextEditingController _minutes;
  late final TextEditingController _note;
  late bool _useProgress;
  late double _progress;
  String? _emptyErr;

  @override
  void initState() {
    super.initState();
    final log = widget.existing;
    _at = log?.at ?? DateTime.now();
    _explicitTime = log != null;
    _pages = TextEditingController(text: log?.pages?.toString() ?? '');
    _minutes = TextEditingController(text: log?.minutes?.toString() ?? '');
    _note = TextEditingController(text: log?.note ?? '');
    _useProgress =
        log != null ? log.progress != null : (widget.book.totalPages ?? 0) <= 0;
    // 默认停在当前进度上，方便小幅往前调
    _progress =
        (log?.progress ?? roundProgress(widget.book, widget.round)).toDouble();
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
    final active = widget.round.isActive;

    final empty = pages == null &&
        minutes == null &&
        note.isEmpty &&
        (!active ||
            !_useProgress ||
            _progress.round() == roundProgress(widget.book, widget.round));
    if (widget.existing == null && empty) {
      setState(() => _emptyErr = '至少填一项：页数、时长，或给个进度');
      return;
    }

    final input = LogInput(
      at: recordTimestamp(_at, explicitTime: _explicitTime),
      pages: pages,
      minutes: minutes,
      // 已读完的轮次不改进度，沿用这条记录原来的进度。
      progress: active
          ? (_useProgress ? _progress.round() : null)
          : widget.existing?.progress,
      note: note,
    );
    final store = context.read<AppStore>();
    try {
      if (widget.existing == null) {
        store.addLog(widget.book.id, widget.round.id, input);
      } else {
        store.updateLog(
            widget.book.id, widget.round.id, widget.existing!.id, input);
      }
    } on ArgumentError catch (error) {
      setState(() => _emptyErr = '${error.message}');
      return;
    } on StateError catch (error) {
      setState(() => _emptyErr = error.message);
      return;
    }
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
              RecordDateTimeField(
                  label: '阅读日期',
                  value: _at,
                  preserveTime: widget.existing != null,
                  onTimeSelected: () => _explicitTime = true,
                  onChanged: (value) => setState(() => _at = value)),
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
                      label: '本次阅读时长',
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
              // 进度只属于正在读的这一轮；已读完的轮次不再改进度。
              if (widget.round.isActive)
                Field(
                  label: '本次结束后的累计进度',
                  hint: (total ?? 0) <= 0
                      ? '没填总页数时，只能手动估一个百分比'
                      : '可不填，系统按本次页数和全书 $total 页估算；进度不能小于上一笔',
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

Future<bool?> showPastRoundSheet(BuildContext context,
    {required Book book, ReadingRound? round}) {
  return _openSheet<bool>(context,
      title: round == null ? '补记往期阅读' : '修改阅读记录',
      subtitle: round?.isActive == true
          ? '修正本轮累计页数、时长，不改动单次记录和进度'
          : '修改起止时间、页数、时长和感想，历史进度保持不变',
      child: _PastRoundForm(book: book, existing: round));
}

class _PastRoundForm extends StatefulWidget {
  const _PastRoundForm({required this.book, this.existing});
  final Book book;
  final ReadingRound? existing;
  @override
  State<_PastRoundForm> createState() => _PastRoundFormState();
}

class _PastRoundFormState extends State<_PastRoundForm> {
  late DateTime _started;
  late DateTime _finished;
  late bool _startedExplicit;
  late bool _finishedExplicit;
  late final TextEditingController _note;
  late final TextEditingController _pages;
  late final TextEditingController _minutes;
  String? _rangeErr;

  bool get _active => widget.existing?.isActive == true;

  @override
  void initState() {
    super.initState();
    final round = widget.existing;
    _finished = round?.finishedAt ?? DateTime.now();
    _started = round?.startedAt ?? _finished.subtract(const Duration(days: 7));
    _startedExplicit = _finishedExplicit = round != null;
    _note = TextEditingController(
        text: round == null ? '' : roundReflection(round));
    _pages = TextEditingController(
        text: round == null ? '' : roundPages(round).toString());
    _minutes = TextEditingController(
        text: round == null ? '' : roundMinutes(round).toString());
  }

  @override
  void dispose() {
    _note.dispose();
    _pages.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _submit() {
    final now = DateTime.now();
    final start =
        recordTimestamp(_started, explicitTime: _startedExplicit, now: now);
    final finish =
        recordTimestamp(_finished, explicitTime: _finishedExplicit, now: now);
    if (!_active && finish.isBefore(start)) {
      setState(() => _rangeErr = '完成时间不能早于开始时间');
      return;
    }
    if (_active && widget.existing!.logs.any((log) => log.at.isBefore(start))) {
      setState(() => _rangeErr = '开始时间不能晚于本轮最早阅读记录');
      return;
    }
    final store = context.read<AppStore>();
    final pages = _pages.text.trim().isEmpty ? null : int.tryParse(_pages.text);
    final minutes =
        _minutes.text.trim().isEmpty ? null : int.tryParse(_minutes.text);
    if ((_pages.text.trim().isNotEmpty && pages == null) ||
        (_minutes.text.trim().isNotEmpty && minutes == null) ||
        (pages ?? 0) < 0 ||
        (minutes ?? 0) < 0) {
      setState(() => _rangeErr = '累计页数和时长请填写非负整数');
      return;
    }
    try {
      if (widget.existing == null) {
        store.addPastRound(
            widget.book.id,
            PastRoundInput(
                startedAt: start,
                finishedAt: finish,
                note: _note.text,
                pages: pages,
                minutes: minutes));
      } else {
        store.updateRound(widget.book.id, widget.existing!.id,
            startedAt: start,
            finishedAt: _active ? null : finish,
            note: _note.text,
            pages: pages == roundPages(widget.existing!) ? kUnset : pages,
            minutes:
                minutes == roundMinutes(widget.existing!) ? kUnset : minutes);
      }
    } on ArgumentError catch (error) {
      setState(() => _rangeErr = '${error.message}');
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
          child: SheetBody(children: [
        RecordDateTimeField(
            key: const Key('round-start'),
            label: '开始日期',
            value: _started,
            preserveTime: widget.existing != null,
            onTimeSelected: () => _startedExplicit = true,
            onChanged: (value) => setState(() {
                  _started = value;
                  _rangeErr = null;
                })),
        if (!_active)
          RecordDateTimeField(
              key: const Key('round-finish'),
              label: '完成日期',
              value: _finished,
              preserveTime: widget.existing != null,
              onTimeSelected: () => _finishedExplicit = true,
              onChanged: (value) => setState(() {
                    _finished = value;
                    _rangeErr = null;
                  })),
        if (_rangeErr != null)
          Text(_rangeErr!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const Text('以下是本轮累计数据，不是单次阅读量。可纠正为更大或更小的数值；留空恢复按明细汇总，进度保持不变。'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: Field(
                  label: '本轮累计页数',
                  optional: true,
                  child: NumberField(
                      key: const Key('round-total-pages'),
                      controller: _pages,
                      hintText: '未填写',
                      suffix: '页'))),
          const SizedBox(width: 10),
          Expanded(
              child: Field(
                  label: '本轮累计时长',
                  optional: true,
                  child: NumberField(
                      key: const Key('round-total-minutes'),
                      controller: _minutes,
                      hintText: '未填写',
                      suffix: '分钟'))),
        ]),
        Field(
            label: '感想 / 心得',
            optional: true,
            child: TextField(
                controller: _note,
                maxLines: 4,
                decoration: const InputDecoration(hintText: '记下这次阅读的感受与收获'))),
      ])),
      SheetFooter(
          child: AppButton(
              label: widget.existing == null ? '保存这一轮' : '保存修改',
              kind: BtnKind.primary,
              expand: true,
              onPressed: _submit)),
    ]);
  }
}

/* ------------------------------------------------------------------ */
/* 4. 电影表单                                                         */
/* ------------------------------------------------------------------ */

Future<bool?> showMovieSheet(BuildContext context, {Movie? movie}) {
  return _openSheet<bool>(
    context,
    title: movie == null ? '添加电影' : '编辑电影',
    subtitle: '只需填写电影名称，其余可以以后再补',
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
    });
    if (title.isEmpty) return;

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
                  decoration: const InputDecoration(hintText: '例如：肖申克的救赎'),
                ),
              ),
              Field(
                label: '导演',
                optional: true,
                child: TextField(
                  controller: _director,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: '例如：弗兰克·德拉邦特'),
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

Future<bool?> showWatchSheet(BuildContext context,
    {required Movie movie, bool past = false, WatchRecord? watch}) {
  return _openSheet<bool>(
    context,
    title: watch != null
        ? '修改观影记录'
        : past
            ? '补记往期观影'
            : movie.watches.isEmpty
                ? '标记为看过'
                : '再看一次',
    subtitle: watch != null ? '改完时间会重新排序' : '可选择任意过去日期，观看次数按时间自动排序',
    child: _WatchForm(movie: movie, existing: watch),
  );
}

class _WatchForm extends StatefulWidget {
  const _WatchForm({required this.movie, this.existing});

  final Movie movie;
  final WatchRecord? existing;

  @override
  State<_WatchForm> createState() => _WatchFormState();
}

class _WatchFormState extends State<_WatchForm> {
  late DateTime _at;
  bool _explicitTime = false;
  int? _rating;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final watch = widget.existing;
    _at = watch?.at ?? DateTime.now();
    _explicitTime = watch != null;
    _rating = watch?.rating;
    _note = TextEditingController(text: watch?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final store = context.read<AppStore>();
    final at = recordTimestamp(_at, explicitTime: _explicitTime);
    final existing = widget.existing;
    if (existing == null) {
      store.addWatch(
        widget.movie.id,
        at: at,
        rating: _rating,
        note: _note.text,
      );
    } else {
      store.updateWatch(
        widget.movie.id,
        existing.id,
        at: at,
        rating: _rating,
        note: _note.text,
      );
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
              RecordDateTimeField(
                  label: '观看日期',
                  value: _at,
                  preserveTime: widget.existing != null,
                  onTimeSelected: () => _explicitTime = true,
                  onChanged: (value) => setState(() => _at = value)),
              Field(
                label: '评分（10分制）',
                optional: true,
                child: RatingPicker(
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
