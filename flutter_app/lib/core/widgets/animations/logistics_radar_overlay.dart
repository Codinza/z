import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A professional, high-tech transportation search radar widget.
/// Used when searching for nearby cars, limousines, or drivers (Customer side),
/// and on the waiting screen (Driver side).
class LogisticsSearchRadar extends StatefulWidget {
  final double size;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color primaryColor;
  final VoidCallback? onCancel;

  const LogisticsSearchRadar({
    super.key,
    this.size = 220,
    this.title = 'جاري البحث عن كابتن متاح...',
    this.subtitle = 'يتم فحص محيط 10 كم وتوجيه طلبك لأقرب سيارة',
    this.icon = Icons.directions_car_rounded,
    this.primaryColor = const Color(0xffF97316),
    this.onCancel,
  });

  @override
  State<LogisticsSearchRadar> createState() => _LogisticsSearchRadarState();
}

class _LogisticsSearchRadarState extends State<LogisticsSearchRadar>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Radar Graphic
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Concentric Radar Rings & Pulses
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size(widget.size, widget.size),
                          painter: _RadarWavesPainter(
                            progress: _pulseController.value,
                            color: widget.primaryColor,
                          ),
                        );
                      },
                    ),

                    // Rotating Radar Sweep Beam
                    AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size(widget.size, widget.size),
                          painter: _RadarScanBeamPainter(
                            angle: _scanController.value * 2 * math.pi,
                            color: widget.primaryColor,
                          ),
                        );
                      },
                    ),

                    // Center High-Tech Beacon
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.primaryColor,
                            widget.primaryColor.withOpacity(0.85),
                          ],
                        ),
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: widget.primaryColor.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),

              if (widget.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.65),
                    height: 1.45,
                  ),
                ),
              ],

              if (widget.onCancel != null) ...[
                const SizedBox(height: 20),
                TextButton(
                  onPressed: widget.onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xffEF4444),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                  ),
                  child: const Text(
                    'إلغاء البحث',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarWavesPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarWavesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 4;

    // Static Grid Circles (Subtle)
    final gridPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, maxRadius * 0.35, gridPaint);
    canvas.drawCircle(center, maxRadius * 0.68, gridPaint);
    canvas.drawCircle(center, maxRadius, gridPaint);

    // Crosshairs
    final crossPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx, 4), Offset(center.dx, size.height - 4), crossPaint);
    canvas.drawLine(Offset(4, center.dy), Offset(size.width - 4, center.dy), crossPaint);

    // Expanding Sonar Wave 1
    final r1 = 34.0 + (maxRadius - 34.0) * progress;
    final op1 = math.max(0.0, (1.0 - progress) * 0.45);
    final wave1 = Paint()
      ..color = color.withOpacity(op1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, r1, wave1);

    // Expanding Sonar Wave 2 (offset)
    final p2 = (progress + 0.5) % 1.0;
    final r2 = 34.0 + (maxRadius - 34.0) * p2;
    final op2 = math.max(0.0, (1.0 - p2) * 0.35);
    final wave2 = Paint()
      ..color = color.withOpacity(op2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, r2, wave2);
  }

  @override
  bool shouldRepaint(covariant _RadarWavesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _RadarScanBeamPainter extends CustomPainter {
  final double angle;
  final Color color;

  _RadarScanBeamPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: math.pi * 0.38,
      colors: [
        color.withOpacity(0.0),
        color.withOpacity(0.24),
      ],
      transform: GradientRotation(angle - math.pi * 0.38),
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RadarScanBeamPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.color != color;
  }
}
