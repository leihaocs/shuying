/// 格式化与解析工具（对应原 Web 版的 lib/utils.ts）。
library;

String _pad(int n) => n < 10 ? '0$n' : '$n';

/// ISO -> 「2026-09-21」
String formatDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
}

/// ISO -> 「2026-09-21 21:30」
String formatDateTime(DateTime? d) {
  if (d == null) return '—';
  return '${formatDate(d)} ${_pad(d.hour)}:${_pad(d.minute)}';
}

/// ISO -> 「今天 / 昨天 / 前天 / N天前 / 2026-09-21」
String relativeDay(DateTime? d) {
  if (d == null) return '—';
  final now = DateTime.now();
  final a = DateTime(d.year, d.month, d.day);
  final b = DateTime(now.year, now.month, now.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff == 2) return '前天';
  if (diff > 0 && diff < 7) return '$diff天前';
  return formatDate(d);
}

/// 分钟 -> 「1小时20分」
String formatDuration(int? minutes) {
  if (minutes == null || minutes <= 0) return '—';
  final h = minutes ~/ 60;
  final m = (minutes % 60).round();
  if (h > 0 && m > 0) return '$h小时$m分';
  if (h > 0) return '$h小时';
  return '$m分钟';
}

/// 统计卡片用的紧凑写法：「2h」或「35m」
String compactDuration(int minutes) =>
    minutes >= 60 ? '${(minutes / 60).round()}h' : '${minutes}m';

int clampInt(num v, int min, int max) =>
    v < min ? min : (v > max ? max : v.round());

double clampDouble(num v, double min, double max) =>
    v < min ? min : (v > max ? max : v.toDouble());

/// 文本 -> 正整数，非法或 <= 0 返回 null
int? parseIntOrNull(String raw) {
  final n = int.tryParse(raw.trim());
  return (n != null && n > 0) ? n : null;
}

/// 同一天判断（本地时区）
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 用于分组的日期键
String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// 造一个当天某时刻的本地时间
DateTime atDayAgo(int days, [int hour = 21, int minute = 30]) {
  final d = DateTime.now();
  final day = DateTime(d.year, d.month, d.day).subtract(Duration(days: days));
  return DateTime(day.year, day.month, day.day, hour, minute);
}
