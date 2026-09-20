import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Soft floating/swaying mascot for branded screens.
class AnimatedZoonMascot extends StatefulWidget {
  const AnimatedZoonMascot({
    super.key,
    this.size = 168,
    this.showGlow = true,
  });

  final double size;
  final bool showGlow;

  @override
  State<AnimatedZoonMascot> createState() => _AnimatedZoonMascotState();
}

class _AnimatedZoonMascotState extends State<AnimatedZoonMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * math.pi * 2;
        final floatY = math.sin(t) * 8;
        final sway = math.sin(t * 0.85) * 0.035;
        final scale = 1 + (math.sin(t) * 0.018);

        return Transform.translate(
          offset: Offset(0, floatY),
          child: Transform.rotate(
            angle: sway,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.showGlow)
              Container(
                width: widget.size * 0.72,
                height: widget.size * 0.72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffF97316).withOpacity(0.28),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            Image.asset(
              'assets/mascot/zoon_mascot.png',
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ],
        ),
      ),
    );
  }
}
