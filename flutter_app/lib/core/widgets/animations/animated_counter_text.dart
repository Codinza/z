import 'package:flutter/material.dart';

/// Smooth, high-performance counting number widget for prices, dashboard counters, and revenues.
class AnimatedCounterText extends StatelessWidget {
  final num value;
  final String? prefix;
  final String? suffix;
  final TextStyle? style;
  final Duration duration;
  final int fractionDigits;

  const AnimatedCounterText({
    super.key,
    required this.value,
    this.prefix,
    this.suffix,
    this.style,
    this.duration = const Duration(milliseconds: 650),
    this.fractionDigits = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        final formatted = fractionDigits == 0
            ? val.toInt().toString()
            : val.toStringAsFixed(fractionDigits);

        return Text(
          '${prefix ?? ''}$formatted${suffix != null ? ' $suffix' : ''}',
          style: style,
        );
      },
    );
  }
}
