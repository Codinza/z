import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A dynamic searching radar beacon marker for the map during driver search.
/// Displays expanding sonar rings, a spinning radar sweep cone, and pinging blip dots.
class AnimatedSearchingRadarPin extends StatefulWidget {
  final Color color;
  final double size;
  final String label;

  const AnimatedSearchingRadarPin({
    super.key,
    this.color = const Color(0xffF97316),
    this.size = 120,
    this.label = 'جاري البحث عن كابتن...',
  });

  @override
  State<AnimatedSearchingRadarPin> createState() =>
      _AnimatedSearchingRadarPinState();
}

class _AnimatedSearchingRadarPinState extends State<AnimatedSearchingRadarPin>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding Sonar Waves & Radar Sweep
          AnimatedBuilder(
            animation: Listenable.merge([_waveController, _sweepController]),
            builder: (context, _) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _SearchingRadarPainter(
                  waveProgress: _waveController.value,
                  sweepAngle: _sweepController.value * 2 * math.pi,
                  color: widget.color,
                ),
              );
            },
          ),

          // Center Glowing Pin Marker
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xff11141A),
              border: Border.all(color: widget.color, width: 2.4),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchingRadarPainter extends CustomPainter {
  final double waveProgress;
  final double sweepAngle;
  final Color color;

  _SearchingRadarPainter({
    required this.waveProgress,
    required this.sweepAngle,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // 1. Radar Sweep Cone (Semi-transparent rotating fan)
    final sweepRect = Rect.fromCircle(center: center, radius: maxR * 0.95);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.22),
        ],
        transform: GradientRotation(sweepAngle),
      ).createShader(sweepRect)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxR * 0.95, sweepPaint);

    // 2. Three Expanding Sonar Waves
    for (int i = 0; i < 3; i++) {
      final p = (waveProgress + (i / 3.0)) % 1.0;
      final radius = 16.0 + (maxR - 16.0) * p;
      final opacity = math.max(0.0, (1.0 - p) * 0.55);

      final wavePaint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(center, radius, wavePaint);
    }

    // 3. Fixed Radar Range Ring
    final ringPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, maxR * 0.95, ringPaint);

    // 4. Subtle Crosshairs
    final crosshairPaint = Paint()
      ..color = color.withOpacity(0.14)
      ..strokeWidth = 0.8;
    canvas.drawLine(
        Offset(center.dx - maxR * 0.95, center.dy),
        Offset(center.dx + maxR * 0.95, center.dy),
        crosshairPaint);
    canvas.drawLine(
        Offset(center.dx, center.dy - maxR * 0.95),
        Offset(center.dx, center.dy + maxR * 0.95),
        crosshairPaint);
  }

  @override
  bool shouldRepaint(covariant _SearchingRadarPainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress ||
        oldDelegate.sweepAngle != sweepAngle;
  }
}
