import 'dart:math' as math;
import 'package:flutter/material.dart';

enum ZoonVehicleType {
  limousine,
  halfTruck,
  carHauler,
}

/// A luxury vector animated vehicle widget with:
/// - Floating chassis aerodynamic bounce
/// - Animated spinning alloy turbine wheels
/// - High-intensity LED headlights beam projection
/// - Neon chassis underglow
/// - Moving road dashes
class ZoonLuxuryVehicleVisualizer extends StatefulWidget {
  final ZoonVehicleType vehicleType;
  final double height;
  final Color primaryColor;
  final Color underglowColor;
  final String? title;
  final String? subtitle;
  final bool showRoad;

  const ZoonLuxuryVehicleVisualizer({
    super.key,
    this.vehicleType = ZoonVehicleType.limousine,
    this.height = 140,
    this.primaryColor = const Color(0xffF97316),
    this.underglowColor = const Color(0xffF97316),
    this.title,
    this.subtitle,
    this.showRoad = true,
  });

  @override
  State<ZoonLuxuryVehicleVisualizer> createState() =>
      _ZoonLuxuryVehicleVisualizerState();
}

class _ZoonLuxuryVehicleVisualizerState extends State<ZoonLuxuryVehicleVisualizer>
    with TickerProviderStateMixin {
  late final AnimationController _suspensionController;
  late final AnimationController _wheelsController;
  late final AnimationController _roadController;
  late final AnimationController _headlightPulseController;

  @override
  void initState() {
    super.initState();

    // Suspension floating bounce (gentle breathing)
    _suspensionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Wheels rotation speed
    _wheelsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat();

    // Fast moving road dashes
    _roadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat();

    // Subtle headlights beam pulsing
    _headlightPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _suspensionController.dispose();
    _wheelsController.dispose();
    _roadController.dispose();
    _headlightPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xff0D1017),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.primaryColor.withOpacity(0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.underglowColor.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background ambient speed lines / glow
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _headlightPulseController,
                builder: (context, _) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.4, 0.0),
                        radius: 1.1,
                        colors: [
                          widget.underglowColor.withOpacity(
                              0.10 + _headlightPulseController.value * 0.06),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Animated Vehicle & Road Canvas
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _suspensionController,
                  _wheelsController,
                  _roadController,
                  _headlightPulseController,
                ]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _VehicleVisualizerPainter(
                      vehicleType: widget.vehicleType,
                      bounce: math.sin(_suspensionController.value * math.pi) * 3.5,
                      wheelRotation: _wheelsController.value * 2 * math.pi,
                      roadProgress: _roadController.value,
                      beamIntensity: 0.7 + _headlightPulseController.value * 0.3,
                      primaryColor: widget.primaryColor,
                      underglowColor: widget.underglowColor,
                      showRoad: widget.showRoad,
                    ),
                  );
                },
              ),
            ),

            // Text Header Overlay (if provided)
            if (widget.title != null || widget.subtitle != null)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.title != null)
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.primaryColor,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.primaryColor.withOpacity(0.8),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    if (widget.subtitle != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12), width: 0.8),
                        ),
                        child: Text(
                          widget.subtitle!,
                          style: TextStyle(
                            color: widget.primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VehicleVisualizerPainter extends CustomPainter {
  final ZoonVehicleType vehicleType;
  final double bounce;
  final double wheelRotation;
  final double roadProgress;
  final double beamIntensity;
  final Color primaryColor;
  final Color underglowColor;
  final bool showRoad;

  _VehicleVisualizerPainter({
    required this.vehicleType,
    required this.bounce,
    required this.wheelRotation,
    required this.roadProgress,
    required this.beamIntensity,
    required this.primaryColor,
    required this.underglowColor,
    required this.showRoad,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final groundY = h * 0.74;

    // 1. Draw Road and Moving Road Dashes
    if (showRoad) {
      final roadPaint = Paint()
        ..color = const Color(0xff151922)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTRB(0, groundY + 8, w, h), roadPaint);

      final roadLinePaint = Paint()
        ..color = const Color(0xff2A3344)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(0, groundY + 8), Offset(w, groundY + 8), roadLinePaint);

      // Fast moving dashes
      final dashPaint = Paint()
        ..color = primaryColor.withOpacity(0.35)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      const dashLength = 26.0;
      const dashGap = 32.0;
      const totalStep = dashLength + dashGap;
      final offset = (roadProgress * totalStep);

      for (double x = -dashLength + offset; x < w + dashLength; x += totalStep) {
        canvas.drawLine(
          Offset(x, groundY + 22),
          Offset(x + dashLength, groundY + 22),
          dashPaint,
        );
      }
    }

    // 2. Headlights Beam Projection (Forward to Left since RTL/forward drive)
    // Center car position
    final carCenterX = w * 0.46;
    final carY = groundY - 14 - bounce;
    final carLength = math.min(w * 0.65, 230.0);
    final carFrontX = carCenterX - (carLength * 0.52);
    final carRearX = carCenterX + (carLength * 0.48);

    // Front headlight beam projection (shining forward towards the left)
    final beamPath = Path()
      ..moveTo(carFrontX, carY + 8)
      ..lineTo(0, carY - 24)
      ..lineTo(0, groundY + 16)
      ..lineTo(carFrontX - 10, groundY + 6)
      ..close();

    final beamGradient = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [
        const Color(0xff67E8F9).withOpacity(0.40 * beamIntensity),
        const Color(0xff38BDF8).withOpacity(0.15 * beamIntensity),
        Colors.transparent,
      ],
    );

    final beamPaint = Paint()
      ..shader = beamGradient.createShader(Rect.fromLTRB(0, 0, carFrontX, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(beamPath, beamPaint);

    // 3. Neon Chassis Underglow
    final underglowRect = Rect.fromCenter(
      center: Offset(carCenterX, groundY + 4),
      width: carLength * 0.95,
      height: 18,
    );
    final underglowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          underglowColor.withOpacity(0.65),
          underglowColor.withOpacity(0.0),
        ],
        radius: 0.8,
      ).createShader(underglowRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(underglowRect, underglowPaint);

    // 4. Draw Vehicle Silhouette & Details
    switch (vehicleType) {
      case ZoonVehicleType.limousine:
        _drawLimousine(canvas, carCenterX, carY, carLength);
        break;
      case ZoonVehicleType.halfTruck:
        _drawHalfTruck(canvas, carCenterX, carY, carLength);
        break;
      case ZoonVehicleType.carHauler:
        _drawCarHauler(canvas, carCenterX, carY, carLength);
        break;
    }

    // 5. Draw Alloy Turbine Wheels (Front & Rear)
    const wheelRadius = 14.0;
    final frontWheelCenter = Offset(carFrontX + carLength * 0.22, groundY + 4);
    final rearWheelCenter = Offset(carRearX - carLength * 0.20, groundY + 4);

    _drawWheel(canvas, frontWheelCenter, wheelRadius, wheelRotation);
    _drawWheel(canvas, rearWheelCenter, wheelRadius, wheelRotation);
  }

  void _drawLimousine(Canvas canvas, double cx, double cy, double length) {
    final frontX = cx - (length * 0.50);
    final rearX = cx + (length * 0.50);

    // Aerodynamic Luxury Body Path
    final bodyPath = Path()
      // Rear bumper
      ..moveTo(rearX, cy + 12)
      // Rear trunk slope
      ..lineTo(rearX - 16, cy + 4)
      ..lineTo(rearX - 32, cy - 2)
      // Rear windshield slope
      ..lineTo(cx + 20, cy - 24)
      // Luxury long roofline
      ..lineTo(cx - 30, cy - 24)
      // Front windshield slope
      ..lineTo(frontX + 42, cy - 4)
      // Long hood
      ..lineTo(frontX + 12, cy)
      // Front nose & grill
      ..lineTo(frontX, cy + 8)
      // Lower front bumper
      ..lineTo(frontX + 4, cy + 16)
      // Wheel well front
      ..lineTo(frontX + length * 0.12, cy + 16)
      ..arcToPoint(
        Offset(frontX + length * 0.32, cy + 16),
        radius: const Radius.circular(16),
        clockwise: false,
      )
      // Chassis bottom side skirt
      ..lineTo(rearX - length * 0.30, cy + 16)
      // Wheel well rear
      ..arcToPoint(
        Offset(rearX - length * 0.10, cy + 16),
        radius: const Radius.circular(16),
        clockwise: false,
      )
      // Rear lower bumper
      ..lineTo(rearX, cy + 15)
      ..close();

    // Body Gradient (Deep metallic obsidian with sleek highlights)
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xff334155),
          Color(0xff1E293B),
          Color(0xff0F172A),
        ],
      ).createShader(Rect.fromLTRB(frontX, cy - 26, rearX, cy + 18))
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, bodyPaint);

    // Body Outline (Subtle sleek border)
    final outlinePaint = Paint()
      ..color = primaryColor.withOpacity(0.85)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bodyPath, outlinePaint);

    // Chrome Tinted Windows
    final windowPath = Path()
      ..moveTo(cx + 16, cy - 21)
      ..lineTo(rearX - 26, cy - 2)
      ..lineTo(cx + 2, cy - 2)
      ..lineTo(cx + 2, cy - 21)
      ..close();

    final frontWindowPath = Path()
      ..moveTo(cx - 2, cy - 21)
      ..lineTo(cx - 2, cy - 2)
      ..lineTo(frontX + 48, cy - 2)
      ..lineTo(cx - 28, cy - 21)
      ..close();

    final glassPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          const Color(0xff38BDF8).withOpacity(0.65),
          const Color(0xff0284C7).withOpacity(0.35),
        ],
      ).createShader(Rect.fromLTRB(frontX, cy - 22, rearX, cy))
      ..style = PaintingStyle.fill;
    canvas.drawPath(windowPath, glassPaint);
    canvas.drawPath(frontWindowPath, glassPaint);

    // Front Headlight (Ice Blue LED)
    final headlightPaint = Paint()
      ..color = const Color(0xffE0F2FE)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(frontX + 1, cy + 3, 7, 5),
        const Radius.circular(2),
      ),
      headlightPaint,
    );

    // Rear Taillight (Ruby Red LED strip)
    final taillightPaint = Paint()
      ..color = const Color(0xffEF4444)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rearX - 5, cy + 4, 6, 4),
        const Radius.circular(2),
      ),
      taillightPaint,
    );
  }

  void _drawHalfTruck(Canvas canvas, double cx, double cy, double length) {
    final frontX = cx - (length * 0.50);
    final rearX = cx + (length * 0.50);

    // Half truck cabin + cargo bed
    final bodyPath = Path()
      ..moveTo(rearX, cy + 12)
      ..lineTo(rearX, cy - 4) // cargo bed back
      ..lineTo(cx + 6, cy - 4) // cargo bed floor top
      ..lineTo(cx + 6, cy - 22) // cabin rear wall
      ..lineTo(frontX + 50, cy - 22) // cabin roof
      ..lineTo(frontX + 22, cy - 2) // windshield slope
      ..lineTo(frontX, cy + 2) // hood
      ..lineTo(frontX, cy + 16) // front grill
      ..lineTo(frontX + length * 0.12, cy + 16)
      ..arcToPoint(
        Offset(frontX + length * 0.32, cy + 16),
        radius: const Radius.circular(16),
        clockwise: false,
      )
      ..lineTo(rearX - length * 0.30, cy + 16)
      ..arcToPoint(
        Offset(rearX - length * 0.10, cy + 16),
        radius: const Radius.circular(16),
        clockwise: false,
      )
      ..lineTo(rearX, cy + 16)
      ..close();

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff475569), Color(0xff1E293B)],
      ).createShader(Rect.fromLTRB(frontX, cy - 24, rearX, cy + 18))
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, bodyPaint);

    final outlinePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bodyPath, outlinePaint);

    // Cabin Window
    final cabinWindow = Path()
      ..moveTo(cx + 2, cy - 19)
      ..lineTo(cx + 2, cy - 4)
      ..lineTo(frontX + 26, cy - 4)
      ..lineTo(frontX + 46, cy - 19)
      ..close();
    final glassPaint = Paint()
      ..color = const Color(0xff38BDF8).withOpacity(0.55)
      ..style = PaintingStyle.fill;
    canvas.drawPath(cabinWindow, glassPaint);
  }

  void _drawCarHauler(Canvas canvas, double cx, double cy, double length) {
    // Similar to heavy cargo / car transport
    _drawHalfTruck(canvas, cx, cy, length);
  }

  void _drawWheel(
      Canvas canvas, Offset center, double radius, double rotation) {
    // Outer Tire
    final tirePaint = Paint()
      ..color = const Color(0xff090C12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, tirePaint);

    final tireBorderPaint = Paint()
      ..color = const Color(0xff334155)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, tireBorderPaint);

    // Rim Outer Ring
    final rimRadius = radius * 0.72;
    final rimPaint = Paint()
      ..color = const Color(0xff1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, rimRadius, rimPaint);

    // Spinning Alloy Spokes
    final spokePaint = Paint()
      ..color = const Color(0xff94A3B8)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    const numSpokes = 5;
    for (int i = 0; i < numSpokes; i++) {
      final angle = rotation + (i * 2 * math.pi / numSpokes);
      final spokeEnd = Offset(
        center.dx + math.cos(angle) * (rimRadius - 1),
        center.dy + math.sin(angle) * (rimRadius - 1),
      );
      canvas.drawLine(center, spokeEnd, spokePaint);
    }

    // Center Hub with Accent Glow
    final hubPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.2, hubPaint);
  }

  @override
  bool shouldRepaint(covariant _VehicleVisualizerPainter oldDelegate) {
    return oldDelegate.bounce != bounce ||
        oldDelegate.wheelRotation != wheelRotation ||
        oldDelegate.roadProgress != roadProgress ||
        oldDelegate.beamIntensity != beamIntensity;
  }
}
