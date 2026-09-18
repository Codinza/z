import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// Professional, smooth Rive-powered loading animation for data fetching and progress states.
class ZoonRiveLoading extends StatefulWidget {
  final double size;
  final String? message;
  final Color? color;
  final bool showCard;

  const ZoonRiveLoading({
    super.key,
    this.size = 80,
    this.message,
    this.color,
    this.showCard = false,
  });

  @override
  State<ZoonRiveLoading> createState() => _ZoonRiveLoadingState();
}

class _ZoonRiveLoadingState extends State<ZoonRiveLoading> {
  final bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.color ?? const Color(0xffF97316);

    Widget animationWidget;
    if (_hasError) {
      // Fallback pulse if rive fails to load
      animationWidget = SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
        ),
      );
    } else {
      animationWidget = SizedBox(
        width: widget.size,
        height: widget.size,
        child: RiveAnimation.asset(
          'assets/rive/liquid_download.riv',
          fit: BoxFit.contain,
          onInit: (_) {},
        ),
      );
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        animationWidget,
        if (widget.message != null && widget.message!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            widget.message!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (widget.showCard) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xff18181b).withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: content,
      );
    }

    return content;
  }
}
