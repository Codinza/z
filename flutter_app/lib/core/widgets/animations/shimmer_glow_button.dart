import 'package:flutter/material.dart';
import 'pressable_scale.dart';

/// A luxury specular shimmer button with continuous gleam sweep,
/// rich gradient, drop shadow, and tactile press scaling.
class ShimmerGlowButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Gradient? gradient;
  final Color glowColor;
  final double height;
  final double borderRadius;
  final bool isEnabled;

  const ShimmerGlowButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient,
    this.glowColor = const Color(0xffF97316),
    this.height = 52,
    this.borderRadius = 16,
    this.isEnabled = true,
  });

  @override
  State<ShimmerGlowButton> createState() => _ShimmerGlowButtonState();
}

class _ShimmerGlowButtonState extends State<ShimmerGlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ??
        const LinearGradient(
          colors: [Color(0xffF97316), Color(0xffEA580C)],
        );

    return PressableScale(
      scaleFactor: widget.isEnabled ? 0.96 : 1.0,
      onTap: widget.isEnabled ? widget.onPressed : null,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          gradient: widget.isEnabled
              ? effectiveGradient
              : const LinearGradient(
                  colors: [Color(0xff334155), Color(0xff1E293B)],
                ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: widget.isEnabled
              ? [
                  BoxShadow(
                    color: widget.glowColor.withOpacity(0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            children: [
              // Center Child Content
              Center(child: widget.child),

              // Moving Shimmer Highlight Beam
              if (widget.isEnabled)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, _) {
                      final shimmerPos = _shimmerController.value;
                      return FractionallySizedBox(
                        alignment: Alignment(
                          -2.5 + (shimmerPos * 5.0),
                          0.0,
                        ),
                        widthFactor: 0.35,
                        child: Transform.rotate(
                          angle: 0.35,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(0.25),
                                  Colors.white.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
