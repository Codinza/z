import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pressable_scale.dart';

/// Professional, high-urgency dispatch alert banner for drivers and logistics companies
/// when a new order or trip request is dispatched.
class DispatchAlertBanner extends StatefulWidget {
  final String title;
  final String pickupAddress;
  final String dropoffAddress;
  final num fare;
  final String? serviceType;
  final Duration timeout;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const DispatchAlertBanner({
    super.key,
    required this.title,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.fare,
    this.serviceType,
    this.timeout = const Duration(seconds: 30),
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<DispatchAlertBanner> createState() => _DispatchAlertBannerState();
}

class _DispatchAlertBannerState extends State<DispatchAlertBanner>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _countdownController;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _countdownController = AnimationController(
      vsync: this,
      duration: widget.timeout,
    )..forward();

    _countdownController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onReject();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isShipping = widget.serviceType == 'SHIPPING';

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff18181b),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xffF97316).withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffF97316).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: Animated Badge & Countdown
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulse = _pulseController.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xffF97316)
                            .withOpacity(0.15 + 0.15 * pulse),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xffF97316)
                              .withOpacity(0.3 + 0.3 * pulse),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isShipping
                                ? Icons.local_shipping_rounded
                                : Icons.directions_car_rounded,
                            size: 14,
                            color: const Color(0xffF97316),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isShipping ? 'طلب شحن جديد' : 'طلب مشوار جديد',
                            style: const TextStyle(
                              color: Color(0xffF97316),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Spacer(),
                // Countdown Ring
                SizedBox(
                  width: 28,
                  height: 28,
                  child: AnimatedBuilder(
                    animation: _countdownController,
                    builder: (context, _) {
                      return CircularProgressIndicator(
                        value: 1.0 - _countdownController.value,
                        strokeWidth: 3.0,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xffF97316),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Fare & Title
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${widget.fare.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff10B981),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Route Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.circle,
                          size: 10, color: Color(0xff10B981)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.pickupAddress,
                          style: const TextStyle(
                              fontSize: 12.5, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 11, color: Color(0xffEF4444)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.dropoffAddress,
                          style: const TextStyle(
                              fontSize: 12.5, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons: Accept & Reject
            Row(
              children: [
                // Reject Button
                Expanded(
                  flex: 1,
                  child: PressableScale(
                    scaleFactor: 0.96,
                    onTap: widget.onReject,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'تجاهل',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Accept Button
                Expanded(
                  flex: 2,
                  child: PressableScale(
                    scaleFactor: 0.96,
                    onTap: widget.onAccept,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff10B981), Color(0xff059669)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff10B981).withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_offer_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'تقديم عرض للعميل',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
