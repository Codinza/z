import 'package:flutter/material.dart';
import 'animated_counter_text.dart';
import 'shimmer_glow_button.dart';
import 'pressable_scale.dart';

/// A luxury interactive offer card for incoming driver & carrier offers.
/// Features a glowing gradient border, price animation, and shiny CTA.
class AnimatedOfferCard extends StatefulWidget {
  final String driverName;
  final double price;
  final double rating;
  final int totalRatings;
  final String? carDescription;
  final String? driverImage;
  final VoidCallback onAccept;
  final VoidCallback? onReject;
  final bool isSelected;

  const AnimatedOfferCard({
    super.key,
    required this.driverName,
    required this.price,
    this.rating = 5.0,
    this.totalRatings = 0,
    this.carDescription,
    this.driverImage,
    required this.onAccept,
    this.onReject,
    this.isSelected = false,
  });

  @override
  State<AnimatedOfferCard> createState() => _AnimatedOfferCardState();
}

class _AnimatedOfferCardState extends State<AnimatedOfferCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowOpacity = 0.25 + (_pulseController.value * 0.35);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff1A1E29), Color(0xff12151D)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xffF59E0B).withOpacity(glowOpacity),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffF59E0B).withOpacity(glowOpacity * 0.4),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              // Header: Badge + Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Pulsing "عرض جديد" Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xffF59E0B), Color(0xffD97706)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF59E0B).withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded,
                            color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'عرض سعر جديد',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Animated Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AnimatedCounterText(
                        value: widget.price,
                        style: const TextStyle(
                          color: Color(0xff10B981),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'ج.م',
                        style: TextStyle(
                          color: Color(0xff10B981),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Driver Information Row
              Row(
                children: [
                  // Driver Avatar with Verified Ring
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xffF59E0B),
                        width: 2.0,
                      ),
                    ),
                    child: ClipOval(
                      child: widget.driverImage != null &&
                              widget.driverImage!.startsWith('http')
                          ? Image.network(
                              widget.driverImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarFallback(),
                            )
                          : _avatarFallback(),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name & Vehicle info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.driverName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.verified_rounded,
                                color: Color(0xff10B981), size: 16),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xffFBBF24), size: 15),
                            const SizedBox(width: 3),
                            Text(
                              widget.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Color(0xffFBBF24),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.totalRatings > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${widget.totalRatings} تقييم)',
                                style: const TextStyle(
                                  color: Color(0xff94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (widget.carDescription != null &&
                                widget.carDescription!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              const Text('•',
                                  style: TextStyle(color: Color(0xff64748B))),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  widget.carDescription!,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xff94A3B8),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Action Buttons: Accept with ShimmerGlowButton & Optional Dismiss
              Row(
                children: [
                  if (widget.onReject != null) ...[
                    PressableScale(
                      onTap: widget.onReject,
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Center(
                          child: Text(
                            'تجاهل',
                            style: TextStyle(
                              color: Color(0xff94A3B8),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ShimmerGlowButton(
                      onPressed: widget.onAccept,
                      height: 46,
                      borderRadius: 12,
                      gradient: const LinearGradient(
                        colors: [Color(0xff10B981), Color(0xff059669)],
                      ),
                      glowColor: const Color(0xff10B981),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 19),
                          SizedBox(width: 8),
                          Text(
                            'قبول العرض الآن',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatarFallback() => Container(
        color: const Color(0xff1E293B),
        child: const Center(
          child: Icon(Icons.person_rounded, color: Color(0xff94A3B8), size: 26),
        ),
      );
}
