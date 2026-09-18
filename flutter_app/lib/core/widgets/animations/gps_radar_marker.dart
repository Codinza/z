import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A high-tech, battery-efficient GPS radar beacon marker for maps.
/// Features a crisp center beacon and subtle expanding concentric sonar rings
/// indicating a live GPS satellite lock.
class GpsRadarMarker extends StatefulWidget {
  final Color color;
  final double size;
  final IconData? icon;

  const GpsRadarMarker({
    super.key,
    this.color = const Color(0xffF97316),
    this.size = 52,
    this.icon,
  });

  @override
  State<GpsRadarMarker> createState() => _GpsRadarMarkerState();
}

class _GpsRadarMarkerState extends State<GpsRadarMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _GpsPulsePainter(
                progress: _controller.value,
                color: widget.color,
              ),
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    border: Border.all(color: Colors.white, width: 2.8),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.55),
                        blurRadius: 10,
                        spreadRadius: 1.5,
                      ),
                    ],
                  ),
                  child: widget.icon != null
                      ? Icon(widget.icon, size: 11, color: Colors.white)
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GpsPulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GpsPulsePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Wave 1
    final r1 = 12.0 + (maxRadius - 12.0) * progress;
    final op1 = math.max(0.0, (1.0 - progress) * 0.45);
    final paint1 = Paint()
      ..color = color.withOpacity(op1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, r1, paint1);

    // Wave 2 (offset by 0.5)
    final p2 = (progress + 0.5) % 1.0;
    final r2 = 12.0 + (maxRadius - 12.0) * p2;
    final op2 = math.max(0.0, (1.0 - p2) * 0.35);
    final paint2 = Paint()
      ..color = color.withOpacity(op2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, r2, paint2);
  }

  @override
  bool shouldRepaint(covariant _GpsPulsePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// An animated pin drop marker for destination and pickup points.
/// Features a snappy spring drop effect and expanding contact shadow upon appearance.
class AnimatedPinDropMarker extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String? label;

  const AnimatedPinDropMarker({
    super.key,
    required this.icon,
    this.color = const Color(0xffEF4444),
    this.size = 46,
    this.label,
  });

  @override
  State<AnimatedPinDropMarker> createState() => _AnimatedPinDropMarkerState();
}

class _AnimatedPinDropMarkerState extends State<AnimatedPinDropMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _dropAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _dropAnimation = Tween<double>(begin: -24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInQuad),
      ),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.15), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _shadowAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SizedBox(
            width: widget.size + 14,
            height: widget.size + 18,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Ground Contact Shadow
                Positioned(
                  bottom: 2,
                  child: Transform.scale(
                    scale: _shadowAnimation.value,
                    child: Container(
                      width: 22,
                      height: 7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Dropping Pin
                Positioned(
                  bottom: 6 - _dropAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: widget.size,
                          height: widget.size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                widget.color,
                                widget.color.withOpacity(0.82),
                              ],
                            ),
                            border: Border.all(color: Colors.white, width: 2.4),
                            boxShadow: [
                              BoxShadow(
                                color: widget.color.withOpacity(0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.icon,
                            color: Colors.white,
                            size: widget.size * 0.52,
                          ),
                        ),
                        // Pointer triangle
                        CustomPaint(
                          size: const Size(12, 6),
                          painter: _PinTrianglePainter(color: widget.color),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PinTrianglePainter extends CustomPainter {
  final Color color;
  _PinTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
