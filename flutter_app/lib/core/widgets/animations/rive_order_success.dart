import 'package:flutter/material.dart';
import 'package:rive/rive.dart' hide LinearGradient;
import 'pressable_scale.dart';

/// Celebratory order confirmation modal using Rive rewards/badge animation.
class ZoonOrderSuccessModal extends StatefulWidget {
  final String title;
  final String message;
  final String? orderId;
  final VoidCallback onTrackOrder;
  final VoidCallback? onDismiss;

  const ZoonOrderSuccessModal({
    super.key,
    required this.title,
    required this.message,
    this.orderId,
    required this.onTrackOrder,
    this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String? orderId,
    required VoidCallback onTrackOrder,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (context, _, __) => ZoonOrderSuccessModal(
        title: title,
        message: message,
        orderId: orderId,
        onTrackOrder: onTrackOrder,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<ZoonOrderSuccessModal> createState() => _ZoonOrderSuccessModalState();
}

class _ZoonOrderSuccessModalState extends State<ZoonOrderSuccessModal> {
  final bool _riveError = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xffF97316).withOpacity(0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffF97316).withOpacity(0.2),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rive rewards / celebration badge
                  SizedBox(
                    height: 140,
                    width: 140,
                    child: _riveError
                        ? Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xff10B981).withOpacity(0.15),
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              size: 72,
                              color: Color(0xff10B981),
                            ),
                          )
                        : const RiveAnimation.asset(
                            'assets/rive/rewards.riv',
                            fit: BoxFit.contain,
                          ),
                  ),

                  const SizedBox(height: 18),

                  // Title
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Message
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.75),
                      height: 1.5,
                    ),
                  ),

                  if (widget.orderId != null && widget.orderId!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Text(
                        'رقم الطلب: #${widget.orderId!.substring(0, widget.orderId!.length > 8 ? 8 : widget.orderId!.length)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xffF97316).withOpacity(0.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 26),

                  // Action: Track Order
                  PressableScale(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onTrackOrder();
                    },
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xffF97316), Color(0xffEA580C)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xffF97316).withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.navigation_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'تتبع الطلب الآن',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Close button
                  PressableScale(
                    onTap: widget.onDismiss ?? () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          'إغلاق',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
