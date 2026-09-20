import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pressable_scale.dart';
import 'zoon_luxury_vehicle_visualizer.dart';

/// Luxury animated loading and dispatch screen displayed when preparing a trip or shipment route.
class ZoonDispatchLoadingScreen extends StatefulWidget {
  final bool isShipping;
  final VoidCallback? onBack;
  final String? customMessage;

  const ZoonDispatchLoadingScreen({
    super.key,
    this.isShipping = false,
    this.onBack,
    this.customMessage,
  });

  @override
  State<ZoonDispatchLoadingScreen> createState() =>
      _ZoonDispatchLoadingScreenState();
}

class _ZoonDispatchLoadingScreenState extends State<ZoonDispatchLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _progressController;
  late final AnimationController _textCycleController;

  int _currentStepIndex = 1; // 0 = Created, 1 = Route, 2 = Radar

  final List<String> _tripLoadingSteps = [
    'تم استلام وتأكيد بيانات الطلب بنجاح',
    'جاري فحص المسار ورسم أسرع طريق على الخريطة...',
    'جاري تفعيل رادار كباتن زوون VIP في منطقتك...',
  ];

  final List<String> _shippingLoadingSteps = [
    'تم تسجيل بيانات الشحنة والمستلم بنجاح',
    'جاري تجهيز وثيقة النقل وحساب المسار الملاحي...',
    'جاري الاتصال بشركات الشحن والكباتن المعتمدين...',
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _textCycleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) {
            setState(() {
              _currentStepIndex = (_currentStepIndex + 1) % 3;
            });
            _textCycleController.forward(from: 0.0);
          }
        }
      });
    _textCycleController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _textCycleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isShipping
        ? const Color(0xff06B6D4)
        : const Color(0xffF97316);
    const accentGold = Color(0xffFBBF24);
    final steps =
        widget.isShipping ? _shippingLoadingSteps : _tripLoadingSteps;
    final topPadding = MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff090B10),
        body: Stack(
          children: [
            // ── Background Ambient Radial Glow ──
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final pulse = _pulseController.value;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.2),
                        radius: 1.2,
                        colors: [
                          themeColor.withOpacity(0.12 + pulse * 0.06),
                          const Color(0xff0D111A).withOpacity(0.7),
                          const Color(0xff080A0F),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Background High-Tech Telemetry Rings ──
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _RadarTelemetryPainter(
                      progress: _pulseController.value,
                      color: themeColor,
                    ),
                  );
                },
              ),
            ),

            // ── Floating Back Button (if provided) ──
            if (widget.onBack != null)
              Positioned(
                top: topPadding + 12,
                right: 18,
                child: PressableScale(
                  onTap: widget.onBack!,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xff161922).withOpacity(0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.16),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Floating Header Brand Pill ──
            Positioned(
              top: topPadding + 14,
              left: 18,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xff161922).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: themeColor.withOpacity(0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: themeColor,
                        boxShadow: [
                          BoxShadow(
                            color: themeColor,
                            blurRadius: 6,
                            spreadRadius: 1.5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      widget.isShipping
                          ? 'شبكة زوون للشحن 📦'
                          : 'رادار زوون VIP 🚗',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Center Content Area ──
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // 1. Luxury Vehicle Animation Canvas
                    ZoonLuxuryVehicleVisualizer(
                      vehicleType: widget.isShipping
                          ? ZoonVehicleType.carHauler
                          : ZoonVehicleType.limousine,
                      height: 175,
                      primaryColor: themeColor,
                      underglowColor: themeColor,
                      title: widget.isShipping
                          ? 'نظام الشحن واللوجستيات'
                          : 'أسطول الليموزين والنقل VIP',
                      subtitle: 'مزامنة ملاحية حية',
                    ),

                    const SizedBox(height: 32),

                    // 2. Animated Status Title
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        widget.customMessage ?? steps[_currentStepIndex],
                        key: ValueKey<int>(_currentStepIndex),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          height: 1.45,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtitle explanation
                    Text(
                      widget.isShipping
                          ? 'يتم تجهيز بيانات الشحن وتوزيع المسار على سيارات النقل والشحن'
                          : 'يتم الآن ربط خط السير وحساب المسافة بدقة والاتصال بأقرب كابتن',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 3. Step Dispatch Dots & Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStepIndicator(
                          index: 0,
                          title: 'تأكيد الطلب',
                          icon: Icons.check_circle_rounded,
                          isDone: true,
                          isActive: _currentStepIndex == 0,
                          color: const Color(0xff22C55E),
                        ),
                        _buildStepDivider(isDone: _currentStepIndex >= 1),
                        _buildStepIndicator(
                          index: 1,
                          title: 'حساب المسار',
                          icon: Icons.alt_route_rounded,
                          isDone: _currentStepIndex > 1,
                          isActive: _currentStepIndex == 1,
                          color: themeColor,
                        ),
                        _buildStepDivider(isDone: _currentStepIndex >= 2),
                        _buildStepIndicator(
                          index: 2,
                          title: 'تنبيه الكباتن',
                          icon: Icons.radar_rounded,
                          isDone: false,
                          isActive: _currentStepIndex == 2,
                          color: accentGold,
                        ),
                      ],
                    ),

                    const SizedBox(height: 34),

                    // 4. Glowing Shimmer Progress Bar
                    Container(
                      width: double.infinity,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, _) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerRight,
                              widthFactor: 0.25 +
                                  0.75 *
                                      math.sin(
                                          _progressController.value * math.pi),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      themeColor.withOpacity(0.6),
                                      themeColor,
                                      accentGold,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: themeColor.withOpacity(0.8),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator({
    required int index,
    required String title,
    required IconData icon,
    required bool isDone,
    required bool isActive,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? color.withOpacity(0.2)
                : isDone
                    ? const Color(0xff22C55E).withOpacity(0.18)
                    : Colors.white.withOpacity(0.06),
            border: Border.all(
              color: isActive
                  ? color
                  : isDone
                      ? const Color(0xff22C55E)
                      : Colors.white.withOpacity(0.16),
              width: isActive ? 1.8 : 1.2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.45),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 19,
            color: isActive
                ? color
                : isDone
                    ? const Color(0xff22C55E)
                    : Colors.white.withOpacity(0.35),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : isDone
                    ? Colors.white.withOpacity(0.8)
                    : Colors.white.withOpacity(0.4),
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider({required bool isDone}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
        decoration: BoxDecoration(
          color: isDone
              ? const Color(0xff22C55E).withOpacity(0.7)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

/// Custom painter that renders expanding concentric radar pulse circles for satellite telemetry.
class _RadarTelemetryPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarTelemetryPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final maxRadius = size.width * 0.72;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + (i * 0.33)) % 1.0;
      final radius = ringProgress * maxRadius;
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.22;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarTelemetryPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
