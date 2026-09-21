import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 进度环：带描边的渐变圆弧 + 中心百分比。
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 108,
    this.stroke = 10,
  });

  /// 0 ~ 1
  final double value;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pct = (value.clamp(0.0, 1.0) * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                value: v,
                stroke: stroke,
                track: c.surface3,
                from: c.accent,
                to: c.accent2,
              ),
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: size * 0.2,
              fontWeight: FontWeight.w700,
              color: c.text,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.track,
    required this.from,
    required this.to,
  });

  final double value;
  final double stroke;
  final Color track;
  final Color from;
  final Color to;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, radius, bg);

    if (value <= 0) return;

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [from, to],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.stroke != stroke || old.track != track;
}
