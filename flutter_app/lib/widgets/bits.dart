
import 'package:flutter/material.dart';

import '../domain/books.dart' as bl;
import '../domain/movies.dart' as ml;
import '../models/models.dart';
import '../theme/app_theme.dart';

/* ------------------------------------------------------------------ */
/* 提示                                                                */
/* ------------------------------------------------------------------ */

void showToast(BuildContext context, String message) {
  final c = AppColors.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        duration: const Duration(milliseconds: 1600),
        backgroundColor: c.text,
      ),
    );
}

/* ------------------------------------------------------------------ */
/* 卡片 / 分区                                                         */
/* ------------------------------------------------------------------ */

class CardBox extends StatelessWidget {
  const CardBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: c.isDark
                ? const Color(0x66000000)
                : const Color(0x0D2B2622),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: box,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.text3,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatCell extends StatelessWidget {
  const StatCell({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: c.text,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: c.text3),
          ),
        ],
      ),
    );
  }
}

class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final w = (constraints.maxWidth - gap * (cells.length - 1)) / cells.length;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final cell in cells) SizedBox(width: w, child: cell),
          ],
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.desc,
  });

  final String icon;
  final String title;
  final String? desc;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        children: [
          Opacity(opacity: 0.55, child: Text(icon, style: const TextStyle(fontSize: 44))),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.text2,
            ),
          ),
          if (desc != null) ...[
            const SizedBox(height: 6),
            Text(
              desc!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.text3, height: 1.7),
            ),
          ],
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* 徽标 / 进度条                                                       */
/* ------------------------------------------------------------------ */

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String text;
  final Color background;
  final Color foreground;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        icon == null ? text : '$icon $text',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: foreground,
          height: 1.7,
        ),
      ),
    );
  }
}

class BookStatusPill extends StatelessWidget {
  const BookStatusPill(this.book, {super.key});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Color bg;
    Color fg;
    switch (bl.bookStatus(book)) {
      case BookStatus.want:
        bg = c.infoSoft;
        fg = c.info;
        break;
      case BookStatus.reading:
        bg = c.accentSoft;
        fg = c.accent;
        break;
      case BookStatus.rereading:
        bg = c.warnSoft;
        fg = c.warn;
        break;
      case BookStatus.finished:
        bg = c.okSoft;
        fg = c.ok;
        break;
    }
    return Pill(text: bl.statusLabel(book), background: bg, foreground: fg);
  }
}

class MovieStatusPill extends StatelessWidget {
  const MovieStatusPill(this.movie, {super.key});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final watched = ml.movieStatus(movie) == MovieStatus.watched;
    return Pill(
      text: ml.movieStatusLabel(movie),
      background: watched ? c.okSoft : c.infoSoft,
      foreground: watched ? c.ok : c.info,
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.height = 5});

  /// 0 ~ 1
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: height,
        color: c.surface3,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0).toDouble(),
          child: Container(
            decoration: BoxDecoration(
              gradient: c.accentGradient,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* 按钮                                                                */
/* ------------------------------------------------------------------ */

enum BtnKind { primary, soft, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = BtnKind.soft,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Color bg;
    Color fg;
    switch (kind) {
      case BtnKind.primary:
        bg = c.accent;
        fg = Colors.white;
        break;
      case BtnKind.soft:
        bg = c.surface2;
        fg = c.text;
        break;
      case BtnKind.ghost:
        bg = Colors.transparent;
        fg = c.text2;
        break;
      case BtnKind.danger:
        bg = c.dangerSoft;
        fg = c.danger;
        break;
    }

    final enabled = onPressed != null;
    final child = Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
        border: kind == BtnKind.ghost
            ? Border.all(color: c.border)
            : null,
        gradient: kind == BtnKind.primary ? c.accentGradient : null,
        boxShadow: kind == BtnKind.primary
            ? [
                BoxShadow(
                  color: c.accent.withAlpha(115),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -10,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );

    final btn = Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(13),
          child: child,
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 36,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final btn = InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: size * 0.5, color: c.text2),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/* ------------------------------------------------------------------ */
/* 顶部导航条                                                          */
/* ------------------------------------------------------------------ */

class NavBar extends StatelessWidget {
  const NavBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* 星级                                                                */
/* ------------------------------------------------------------------ */

class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    this.rating,
    this.onChanged,
    this.size = 22,
  });

  final int? rating;
  final ValueChanged<int?>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onChanged == null
                ? null
                : () => onChanged!(rating == i ? null : i),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                (rating ?? 0) >= i
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: size,
                color: (rating ?? 0) >= i
                    ? const Color(0xFFE0A33A)
                    : c.surface3,
              ),
            ),
          ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ */
/* 封面                                                                */
/* ------------------------------------------------------------------ */

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.cover,
    required this.accent,
    this.width = 52,
    this.height,
    this.fontSize = 24,
    this.radius = 9,
    this.shadow = false,
  });

  final String cover;
  final int accent;
  final double width;
  final double? height;
  final double fontSize;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Color(accent),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? [
                const BoxShadow(
                  color: Color(0x552B2622),
                  blurRadius: 26,
                  offset: Offset(0, 10),
                  spreadRadius: -14,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: c.coverGradient,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
          Text(cover, style: TextStyle(fontSize: fontSize)),
        ],
      ),
    );
  }
}
