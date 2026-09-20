import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An animated luxury vehicle marker for FlutterMap with:
/// - Directional heading rotation
/// - Headlights beam projection on the map surface
/// - Pulsing status aura ring
/// - Driver name badge
class AnimatedGlidingVehicleMarker extends StatefulWidget {
  final String driverName;
  final double heading; // in degrees (0 = North)
  final bool isShipping;
  final Color themeColor;

  const AnimatedGlidingVehicleMarker({
    super.key,
    required this.driverName,
    this.heading = 0.0,
    this.isShipping = false,
    this.themeColor = const Color(0xff22C55E),
  });

  @override
  State<AnimatedGlidingVehicleMarker> createState() =>
      _AnimatedGlidingVehicleMarkerState();
}

class _AnimatedGlidingVehicleMarkerState
    extends State<AnimatedGlidingVehicleMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Driver Name Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xff0F131A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.themeColor, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isShipping
                    ? Icons.local_shipping_rounded
                    : Icons.directions_car_rounded,
                color: widget.themeColor,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                widget.driverName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),

        // Rotatable Vehicle with Headlights & Pulsing Aura
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final pulseVal = _pulseController.value;
            final headingRad = (widget.heading * math.pi / 180.0);

            return Transform.rotate(
              angle: headingRad,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Forward Headlight Beam Projection
                  Positioned(
                    top: -24,
                    child: CustomPaint(
                      size: const Size(40, 28),
                      painter: _HeadlightBeamPainter(
                        color: const Color(0xff67E8F9),
                        intensity: 0.7 + pulseVal * 0.3,
                      ),
                    ),
                  ),

                  // Ambient Pulsing Glow Circle
                  Container(
                    width: 48 + (pulseVal * 6),
                    height: 48 + (pulseVal * 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.themeColor.withOpacity(0.18 * (1.0 - pulseVal)),
                    ),
                  ),

                  // Vehicle Body Disc
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xff121620),
                      border: Border.all(
                        color: widget.themeColor,
                        width: 2.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.themeColor.withOpacity(0.55),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        widget.isShipping
                            ? Icons.local_shipping_rounded
                            : Icons.navigation_rounded,
                        color: widget.themeColor,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HeadlightBeamPainter extends CustomPainter {
  final Color color;
  final double intensity;

  _HeadlightBeamPainter({required this.color, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dual conical beams shining upward (forward)
    final beamPath = Path()
      ..moveTo(w * 0.35, h)
      ..lineTo(0, 0)
      ..lineTo(w * 0.45, 0)
      ..close();

    final beamPath2 = Path()
      ..moveTo(w * 0.65, h)
      ..lineTo(w * 0.55, 0)
      ..lineTo(w, 0)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withOpacity(0.55 * intensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(beamPath, paint);
    canvas.drawPath(beamPath2, paint);
  }

  @override
  bool shouldRepaint(covariant _HeadlightBeamPainter oldDelegate) {
    return oldDelegate.intensity != intensity || oldDelegate.color != color;
  }
}
