import 'package:flutter/material.dart';

/// A sleek, high-performance page transition builder for transportation and logistics apps.
/// Features a subtle horizontal slide accompanied by an opacity fade (240ms),
/// preventing jarring transitions and maintaining 60fps responsiveness.
class LogisticsPageTransitionsBuilder extends PageTransitionsBuilder {
  const LogisticsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const beginOffset = Offset(0.06, 0.0);
    const endOffset = Offset.zero;
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: endOffset,
    ).animate(curve);

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(curve);

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: child,
      ),
    );
  }
}
