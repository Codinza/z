import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// Animated delivery vehicle widget using Rive (vehicles.riv)
/// Used in order tracking and delivery status banners.
class ZoonDeliveryVehicleAnimation extends StatefulWidget {
  final double height;
  final double? width;
  final String? statusLabel;
  final String? subtitle;
  final bool showBadge;

  const ZoonDeliveryVehicleAnimation({
    super.key,
    this.height = 100,
    this.width,
    this.statusLabel,
    this.subtitle,
    this.showBadge = true,
  });

  @override
  State<ZoonDeliveryVehicleAnimation> createState() =>
      _ZoonDeliveryVehicleAnimationState();
}

class _ZoonDeliveryVehicleAnimationState
    extends State<ZoonDeliveryVehicleAnimation> {
  final bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    Widget vehicleArt;
    if (_hasError) {
      vehicleArt = Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xffF97316).withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Icon(
            Icons.local_shipping_rounded,
            size: 48,
            color: Color(0xffF97316),
          ),
        ),
      );
    } else {
      vehicleArt = SizedBox(
        height: widget.height,
        width: widget.width ?? double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: const RiveAnimation.asset(
            'assets/rive/vehicles.riv',
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    if (widget.statusLabel == null && !widget.showBadge) {
      return vehicleArt;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xff18181b),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffF97316).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          vehicleArt,
          if (widget.statusLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xff10B981),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.statusLabel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
