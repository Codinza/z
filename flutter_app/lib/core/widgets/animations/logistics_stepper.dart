import 'package:flutter/material.dart';

/// Modern, professional logistics timeline stepper for trips and shipping operations.
/// Supports both:
/// - Limousine / Trip: طلب جديد → تم القبول → في الطريق → وصل → مكتمل
/// - Cargo / Shipping: طلب جديد → عرض سعر → قبول العميل → استلام → في الطريق → تم التسليم
class LogisticsTimelineStepper extends StatefulWidget {
  final String? currentStatus;
  final bool isShipping;
  final Color primaryColor;

  const LogisticsTimelineStepper({
    super.key,
    required this.currentStatus,
    this.isShipping = false,
    this.primaryColor = const Color(0xffF97316),
  });

  @override
  State<LogisticsTimelineStepper> createState() =>
      _LogisticsTimelineStepperState();
}

class _LogisticsTimelineStepperState extends State<LogisticsTimelineStepper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  static const List<_StepDef> _tripSteps = [
    _StepDef(id: 'NEW', title: 'طلب جديد', icon: Icons.schedule_rounded),
    _StepDef(id: 'ACCEPTED', title: 'تم القبول', icon: Icons.thumb_up_alt_outlined),
    _StepDef(id: 'EN_ROUTE', title: 'في الطريق', icon: Icons.directions_car_rounded),
    _StepDef(id: 'ARRIVED', title: 'وصل الكابتن', icon: Icons.place_rounded),
    _StepDef(id: 'COMPLETED', title: 'مكتملة', icon: Icons.check_circle_rounded),
  ];

  static const List<_StepDef> _shippingSteps = [
    _StepDef(id: 'NEW', title: 'طلب جديد', icon: Icons.post_add_rounded),
    _StepDef(id: 'PRICE_SENT', title: 'عرض سعر', icon: Icons.local_offer_outlined),
    _StepDef(id: 'ACCEPTED', title: 'قبول العرض', icon: Icons.handshake_outlined),
    _StepDef(id: 'PICKED_UP', title: 'تم الاستلام', icon: Icons.inventory_2_outlined),
    _StepDef(id: 'IN_TRANSIT', title: 'في الطريق', icon: Icons.local_shipping_outlined),
    _StepDef(id: 'COMPLETED', title: 'تم التسليم', icon: Icons.done_all_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int _calculateActiveIndex(List<_StepDef> steps) {
    final s = widget.currentStatus?.toUpperCase() ?? 'NEW';

    if (widget.isShipping) {
      if (s == 'COMPLETED' || s == 'DELIVERED') return 5;
      if (s == 'IN_TRANSIT' || s == 'SHIPPED' || s == 'ON_THE_WAY') return 4;
      if (s == 'PICKED_UP' || s == 'LOADED') return 3;
      if (s == 'CUSTOMER_ACCEPTED' ||
          s == 'COMPANY_ACCEPTED' ||
          s == 'ACCEPTED' ||
          s == 'CONFIRMED' ||
          s == 'DRIVER_ACCEPTED') return 2;
      if (s == 'PRICE_SENT' || s == 'OFFER_SENT' || s == 'COMPANY_REVIEWING') {
        return 1;
      }
      return 0;
    } else {
      if (s == 'COMPLETED') return 4;
      if (s == 'ARRIVED') return 3;
      if (s == 'STARTED' ||
          s == 'IN_PROGRESS' ||
          s == 'IN_TRANSIT' ||
          s == 'EN_ROUTE') return 2;
      if (s == 'ACCEPTED' ||
          s == 'DRIVER_ACCEPTED' ||
          s == 'ASSIGNED' ||
          s == 'CONFIRMED') return 1;
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.isShipping ? _shippingSteps : _tripSteps;
    final activeIndex = _calculateActiveIndex(steps);

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xff18181b),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  widget.isShipping
                      ? Icons.local_shipping_rounded
                      : Icons.directions_car_rounded,
                  size: 18,
                  color: widget.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isShipping ? 'مراحل متابعة الشحنة' : 'مسار وحالة الرحلة',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    steps[activeIndex].title,
                    style: TextStyle(
                      color: widget.primaryColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Stepper Row
            Row(
              children: List.generate(steps.length * 2 - 1, (index) {
                if (index.isOdd) {
                  // Connecting Line
                  final stepBefore = index ~/ 2;
                  final isDone = stepBefore < activeIndex;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 3,
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xff10B981)
                            : Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: isDone
                            ? [
                                BoxShadow(
                                  color:
                                      const Color(0xff10B981).withOpacity(0.4),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }

                // Step Node
                final stepIndex = index ~/ 2;
                final isPassed = stepIndex < activeIndex;
                final isCurrent = stepIndex == activeIndex;
                final step = steps[stepIndex];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStepNode(step, isPassed, isCurrent),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 52,
                      child: Text(
                        step.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent
                              ? widget.primaryColor
                              : isPassed
                                  ? const Color(0xff10B981)
                                  : Colors.white.withOpacity(0.45),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepNode(_StepDef step, bool isPassed, bool isCurrent) {
    if (isPassed) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xff10B981),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xff10B981).withOpacity(0.4),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
    }

    if (isCurrent) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = _pulseController.value;
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.primaryColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: widget.primaryColor.withOpacity(0.3 + 0.3 * pulse),
                  blurRadius: 10 + 6 * pulse,
                  spreadRadius: 1.5 * pulse,
                ),
              ],
            ),
            child: Icon(step.icon, color: Colors.white, size: 16),
          );
        },
      );
    }

    // Upcoming Step
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Icon(step.icon, color: Colors.white.withOpacity(0.35), size: 13),
    );
  }
}

class _StepDef {
  final String id;
  final String title;
  final IconData icon;

  const _StepDef({
    required this.id,
    required this.title,
    required this.icon,
  });
}
