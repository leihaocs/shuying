import 'package:flutter/material.dart';

/// 设计令牌，对应原 Web 版 styles.css 里的 CSS 变量。
class AppColors {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.text,
    required this.text2,
    required this.text3,
    required this.border,
    required this.accent,
    required this.accent2,
    required this.accentSoft,
    required this.ok,
    required this.okSoft,
    required this.warn,
    required this.warnSoft,
    required this.info,
    required this.infoSoft,
    required this.danger,
    required this.dangerSoft,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color text;
  final Color text2;
  final Color text3;
  final Color border;
  final Color accent;
  final Color accent2;
  final Color accentSoft;
  final Color ok;
  final Color okSoft;
  final Color warn;
  final Color warnSoft;
  final Color info;
  final Color infoSoft;
  final Color danger;
  final Color dangerSoft;
  final bool isDark;

  static const AppColors light = AppColors(
    bg: Color(0xFFF7F4EF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF2EDE5),
    surface3: Color(0xFFE9E2D8),
    text: Color(0xFF2B2622),
    text2: Color(0xFF6F665C),
    text3: Color(0xFF9C948A),
    border: Color(0xFFE6DED3),
    accent: Color(0xFFB4552D),
    accent2: Color(0xFFD9793F),
    accentSoft: Color(0xFFF8E8DD),
    ok: Color(0xFF3F7D54),
    okSoft: Color(0xFFE3EFE7),
    warn: Color(0xFFB8791F),
    warnSoft: Color(0xFFF8EFDB),
    info: Color(0xFF3A6EA5),
    infoSoft: Color(0xFFE5EDF7),
    danger: Color(0xFFB8402F),
    dangerSoft: Color(0xFFF8E4E0),
    isDark: false,
  );

  static const AppColors dark = AppColors(
    bg: Color(0xFF14130F),
    surface: Color(0xFF1E1C17),
    surface2: Color(0xFF262320),
    surface3: Color(0xFF322E28),
    text: Color(0xFFF2ECE2),
    text2: Color(0xFFB0A698),
    text3: Color(0xFF837A6E),
    border: Color(0xFF322E26),
    accent: Color(0xFFE08A5F),
    accent2: Color(0xFFF0A077),
    accentSoft: Color(0xFF3A2A20),
    ok: Color(0xFF7FBF98),
    okSoft: Color(0xFF22322A),
    warn: Color(0xFFD9A95A),
    warnSoft: Color(0xFF33291A),
    info: Color(0xFF8AB4E0),
    infoSoft: Color(0xFF1E2A38),
    danger: Color(0xFFE08B7D),
    dangerSoft: Color(0xFF3A221E),
    isDark: true,
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// 封面渐变：浅色叠加，模拟书脊高光
  LinearGradient get coverGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0x33FFFFFF), Color(0x44000000)]
            : const [Color(0x52FFFFFF), Color(0x24000000)],
      );

  LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, accent2],
      );
}

/// 书籍封面的可选底色（对应原 Web 版 ACCENTS）
const List<int> kAccents = <int>[
  0xFFB4552D,
  0xFF3F7D54,
  0xFF3A6EA5,
  0xFF8A5A9B,
  0xFFC2872F,
  0xFF2F8A8A,
  0xFFA5453A,
  0xFF5B6BB5,
];

/// 书籍封面的可选 emoji（对应原 Web 版 COVERS）
const List<String> kCovers = <String>[
  '📕', '📗', '📘', '📙', '📖', '📚', '📔', '📓', '🧠', '🌿', '🎯', '🕯️',
];

class AppTheme {
  static ThemeData light() => _build(AppColors.light);
  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors c) {
    final brightness = c.isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(
      primary: c.accent,
      onPrimary: Colors.white,
      secondary: c.accent2,
      error: c.danger,
      surface: c.surface,
      onSurface: c.text,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      colorScheme: scheme,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: c.text,
        displayColor: c.text,
      ),
      dividerColor: c.border,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: c.text,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        hintStyle: TextStyle(color: c.text3, fontSize: 15),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.text,
        contentTextStyle: TextStyle(color: c.bg, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        insetPadding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
      ),
    );
  }
}
