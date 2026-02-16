import 'dart:math' as math;

import 'package:flutter/material.dart';

class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.totalDuration,
    required this.remainingDuration,
    this.size = 240,
    this.strokeWidth = 24,
    this.centerText,
    this.progressColor,
    this.trackColor,
    this.centerTextStyle,
    this.progressGradient,
    this.extraTotalDuration,
    this.extraRemainingDuration,
    this.extraStrokeWidth,
    this.extraColor,
    this.extraTrackColor,
  });

  final Duration totalDuration;
  final Duration remainingDuration;
  final double size;
  final double strokeWidth;
  final String? centerText;
  final Color? progressColor;
  final Color? trackColor;
  final TextStyle? centerTextStyle;
  final Gradient? progressGradient;
  final Duration? extraTotalDuration;
  final Duration? extraRemainingDuration;
  final double? extraStrokeWidth;
  final Color? extraColor;
  final Color? extraTrackColor;

  @override
  Widget build(BuildContext context) {
    final totalMs = totalDuration.inMilliseconds;
    final remainingMs = remainingDuration.inMilliseconds.clamp(0, totalMs);
    final progress = totalMs == 0 ? 0.0 : remainingMs / totalMs;
    final hasExtra =
        extraTotalDuration != null && extraRemainingDuration != null;
    final extraTotalMs = hasExtra ? extraTotalDuration!.inMilliseconds : 0;
    final extraRemainingMs = hasExtra
        ? extraRemainingDuration!.inMilliseconds.clamp(0, extraTotalMs)
        : 0;
    final extraProgress = extraTotalMs == 0
        ? 0.0
        : extraRemainingMs / extraTotalMs;
    final resolvedExtraStrokeWidth = extraStrokeWidth ?? (strokeWidth * 0.45);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<Offset>(
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        tween: Tween<Offset>(end: Offset(progress, extraProgress)),
        builder: (context, animatedValues, child) {
          return CustomPaint(
            painter: _TimerRingPainter(
              progress: animatedValues.dx,
              strokeWidth: strokeWidth,
              trackColor:
                  trackColor ??
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              progressColor:
                  progressColor ?? Theme.of(context).colorScheme.primary,
              progressGradient: progressGradient,
              extraProgress: animatedValues.dy,
              extraStrokeWidth: resolvedExtraStrokeWidth,
              extraColor: extraColor,
              extraTrackColor: extraTrackColor,
            ),
            child: Center(
              child: Text(
                centerText ?? _formatDuration(remainingDuration),
                style:
                    centerTextStyle ??
                    Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class _TimerRingPainter extends CustomPainter {
  const _TimerRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
    required this.progressGradient,
    required this.extraProgress,
    required this.extraStrokeWidth,
    required this.extraColor,
    required this.extraTrackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;
  final Gradient? progressGradient;
  final double extraProgress;
  final double extraStrokeWidth;
  final Color? extraColor;
  final Color? extraTrackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = math.min(size.width, size.height) / 2;
    final hasExtra = extraColor != null;
    final strokeMax = hasExtra
        ? math.max(strokeWidth, extraStrokeWidth)
        : strokeWidth;
    final radius = maxRadius - (strokeMax / 2);
    final mainRect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    if (progressGradient != null) {
      progressPaint.shader = progressGradient!.createShader(mainRect);
    }

    canvas.drawCircle(center, radius, trackPaint);

    final clampedProgress = progress.clamp(0.0, 1.0);
    final sweepAngle = 2 * math.pi * clampedProgress;
    canvas.drawArc(mainRect, -math.pi / 2, sweepAngle, false, progressPaint);

    if (hasExtra) {
      final extraTrackPaint = Paint()
        ..color = extraTrackColor ?? extraColor!.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = extraStrokeWidth
        ..strokeCap = StrokeCap.round;
      final extraPaint = Paint()
        ..color = extraColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = extraStrokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, radius, extraTrackPaint);

      final clampedExtra = extraProgress.clamp(0.0, 1.0);
      final extraSweep = 2 * math.pi * clampedExtra;
      canvas.drawArc(mainRect, -math.pi / 2, extraSweep, false, extraPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.progressGradient != progressGradient ||
        oldDelegate.extraProgress != extraProgress ||
        oldDelegate.extraStrokeWidth != extraStrokeWidth ||
        oldDelegate.extraColor != extraColor ||
        oldDelegate.extraTrackColor != extraTrackColor;
  }
}
