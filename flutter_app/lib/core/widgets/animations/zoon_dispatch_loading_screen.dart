import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pressable_scale.dart';

/// Calm, soft loading screen shown while the order is being prepared.
class ZoonDispatchLoadingScreen extends StatefulWidget {
  final bool isShipping;
  final bool isMotorcycle;
  final VoidCallback? onBack;
  final String? customMessage;

  const ZoonDispatchLoadingScreen({
    super.key,
    this.isShipping = false,
    this.isMotorcycle = false,
    this.onBack,
    this.customMessage,
  });

  @override
  State<ZoonDispatchLoadingScreen> createState() =>
      _ZoonDispatchLoadingScreenState();
}

class _ZoonDispatchLoadingScreenState extends State<ZoonDispatchLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final AnimationController _progressController;
  late final AnimationController _fadeController;

  int _messageIndex = 0;

  List<String> get _messages {
    if (widget.customMessage != null && widget.customMessage!.trim().isNotEmpty) {
      return [widget.customMessage!.trim()];
    }
    if (widget.isShipping) {
      return const [
        'بنجهّز طلب الشحن...',
        'بنوصّل طلبك لأقرب شركات متاحة',
        'لحظة وهتشوف التتبع',
      ];
    }
    if (widget.isMotorcycle) {
      return const [
        'بنأكد طلب الموتوسيكل...',
        'بندوّر على أقرب كابتن قريب منك',
        'لحظة وهيتفتح التتبع',
      ];
    }
    return const [
      'بنأكد طلبك...',
      'بندوّر على أقرب كابتن',
      'لحظة وهيتفتح التتبع',
    ];
  }

  IconData get _heroIcon {
    if (widget.isShipping) return Icons.local_shipping_rounded;
    if (widget.isMotorcycle) return Icons.two_wheeler_rounded;
    return Icons.directions_car_filled_rounded;
  }

  String get _title {
    if (widget.isShipping) return 'جاري تجهيز الشحنة';
    if (widget.isMotorcycle) return 'جاري البحث عن موتوسيكل';
    return 'جاري البحث عن كابتن';
  }

  @override
  void initState() {
    super.initState();

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _messageIndex = (_messageIndex + 1) % _messages.length;
          });
          _fadeController.forward(from: 0);
        }
      });
    _fadeController.forward();
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isShipping
        ? const Color(0xff06B6D4)
        : const Color(0xffF97316);
    final topPadding = MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B0E14),
        body: Stack(
          children: [
            // Soft ambient glow — calm, not flashy
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _breatheController,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(_breatheController.value);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.35),
                        radius: 1.05,
                        colors: [
                          themeColor.withOpacity(0.10 + t * 0.05),
                          const Color(0xff0B0E14),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (widget.onBack != null)
              Positioned(
                top: topPadding + 12,
                right: 16,
                child: PressableScale(
                  onTap: widget.onBack!,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xff121620).withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xff252E3E)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xff94A3B8),
                      size: 20,
                    ),
                  ),
                ),
              ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // Soft breathing icon
                    AnimatedBuilder(
                      animation: _breatheController,
                      builder: (context, child) {
                        final t =
                            Curves.easeInOut.transform(_breatheController.value);
                        final scale = 1.0 + (t * 0.04);
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: themeColor.withOpacity(0.12),
                          border: Border.all(
                            color: themeColor.withOpacity(0.35),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withOpacity(0.18),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _heroIcon,
                          size: 44,
                          color: themeColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),

                    const SizedBox(height: 12),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.12),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _messages[_messageIndex],
                        key: ValueKey<int>(_messageIndex),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xff94A3B8),
                          fontSize: 14.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Soft indeterminate bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        height: 5,
                        width: 180,
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, _) {
                            final v = _progressController.value;
                            // Gentle traveling highlight
                            final start = (math.sin(v * math.pi * 2) + 1) / 2;
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(color: const Color(0xff1E2633)),
                                FractionallySizedBox(
                                  alignment: Alignment(
                                    -1.0 + (start * 2.0),
                                    0,
                                  ),
                                  widthFactor: 0.42,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          themeColor.withOpacity(0.15),
                                          themeColor,
                                          themeColor.withOpacity(0.15),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'مش هتاخد وقت…',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const Spacer(flex: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
