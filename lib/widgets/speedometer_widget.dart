import 'dart:math';
import 'package:flutter/material.dart';
import 'package:voltride/core/theme.dart';

class SpeedometerWidget extends StatefulWidget {
  final double speed;
  final double maxSpeed;
  final String unit;

  const SpeedometerWidget({
    super.key,
    required this.speed,
    this.maxSpeed = 100,
    this.unit = 'km/h',
  });

  @override
  State<SpeedometerWidget> createState() => _SpeedometerWidgetState();
}

class _SpeedometerWidgetState extends State<SpeedometerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousSpeed = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(SpeedometerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) {
      _animation = Tween<double>(
        begin: _previousSpeed,
        end: widget.speed,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
      _previousSpeed = widget.speed;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(260, 260),
          painter: _SpeedometerPainter(
            speed: _animation.value,
            maxSpeed: widget.maxSpeed,
            unit: widget.unit,
          ),
        );
      },
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final String unit;

  _SpeedometerPainter({
    required this.speed,
    required this.maxSpeed,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Background arc
    final bgPaint = Paint()
      ..color = VoltRideTheme.surfaceLight.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    const startAngle = 2.3561944; // 135 degrees in radians
    const sweepAngle = 4.712389; // 270 degrees in radians

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Speed arc with gradient
    final speedRatio = (speed / maxSpeed).clamp(0.0, 1.0);
    final speedSweep = sweepAngle * speedRatio;

    if (speedSweep > 0.01) {
      // Determine color based on speed
      Color arcColor;
      if (speedRatio < 0.4) {
        arcColor = VoltRideTheme.electricBlue;
      } else if (speedRatio < 0.7) {
        arcColor = VoltRideTheme.neonGreen;
      } else if (speedRatio < 0.9) {
        arcColor = VoltRideTheme.voltYellow;
      } else {
        arcColor = VoltRideTheme.alertRed;
      }

      final speedPaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        speedSweep,
        false,
        speedPaint,
      );

      // Glow effect
      final glowPaint = Paint()
        ..color = arcColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        speedSweep,
        false,
        glowPaint,
      );
    }

    // Tick marks
    for (int i = 0; i <= 10; i++) {
      final tickAngle = startAngle + (sweepAngle * i / 10);
      final isMainTick = i % 2 == 0;
      final innerRadius = radius - (isMainTick ? 24 : 16);
      final outerRadius = radius - 6;

      final tickStart = Offset(
        center.dx + innerRadius * cos(tickAngle),
        center.dy + innerRadius * sin(tickAngle),
      );
      final tickEnd = Offset(
        center.dx + outerRadius * cos(tickAngle),
        center.dy + outerRadius * sin(tickAngle),
      );

      final tickPaint = Paint()
        ..color = isMainTick
            ? VoltRideTheme.textSecondary
            : VoltRideTheme.textMuted.withOpacity(0.5)
        ..strokeWidth = isMainTick ? 2 : 1
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(tickStart, tickEnd, tickPaint);

      // Speed labels on main ticks
      if (isMainTick) {
        final labelValue = (maxSpeed * i / 10).toInt();
        final textSpan = TextSpan(
          text: '$labelValue',
          style: TextStyle(
            color: VoltRideTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final labelRadius = innerRadius - 14;
        final labelPos = Offset(
          center.dx + labelRadius * cos(tickAngle) - textPainter.width / 2,
          center.dy + labelRadius * sin(tickAngle) - textPainter.height / 2,
        );
        textPainter.paint(canvas, labelPos);
      }
    }

    // Needle
    final needleAngle = startAngle + speedSweep;
    final needleLength = radius - 36;
    final needleEnd = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );

    Color needleColor;
    if (speedRatio < 0.4) {
      needleColor = VoltRideTheme.electricBlue;
    } else if (speedRatio < 0.7) {
      needleColor = VoltRideTheme.neonGreen;
    } else {
      needleColor = VoltRideTheme.alertRed;
    }

    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, needleEnd, needlePaint);

    // Center dot
    canvas.drawCircle(
      center,
      8,
      Paint()..color = needleColor,
    );
    canvas.drawCircle(
      center,
      4,
      Paint()..color = VoltRideTheme.background,
    );

    // Speed text
    final speedText = TextSpan(
      text: speed.toInt().toString(),
      style: const TextStyle(
        color: VoltRideTheme.textPrimary,
        fontSize: 52,
        fontWeight: FontWeight.w700,
        letterSpacing: -2,
      ),
    );
    final speedPainter = TextPainter(
      text: speedText,
      textDirection: TextDirection.ltr,
    );
    speedPainter.layout();
    speedPainter.paint(
      canvas,
      Offset(
        center.dx - speedPainter.width / 2,
        center.dy + 20,
      ),
    );

    // Unit text
    final unitText = TextSpan(
      text: unit,
      style: TextStyle(
        color: VoltRideTheme.textMuted,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 1,
      ),
    );
    final unitPainter = TextPainter(
      text: unitText,
      textDirection: TextDirection.ltr,
    );
    unitPainter.layout();
    unitPainter.paint(
      canvas,
      Offset(
        center.dx - unitPainter.width / 2,
        center.dy + 72,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter oldDelegate) {
    return oldDelegate.speed != speed;
  }
}
