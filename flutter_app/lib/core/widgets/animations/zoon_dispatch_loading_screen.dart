import 'package:flutter/material.dart';
import 'pressable_scale.dart';

/// Minimal loading screen while an order is being prepared.
class ZoonDispatchLoadingScreen extends StatefulWidget {
  final bool isShipping;
  final bool isMotorcycle;
  final VoidCallback? onBack;
  final String? customMessage;

  const ZoonDispatchLoadingScreen({
    super.key,
    this.isShipping = false,
    this.isMotorcycle = false,
    this.onBack,
    this.customMessage,
  });

  @override
  State<ZoonDispatchLoadingScreen> createState() =>
      _ZoonDispatchLoadingScreenState();
}

class _ZoonDispatchLoadingScreenState extends State<ZoonDispatchLoadingScreen> {
  String get _message {
    if (widget.customMessage != null &&
        widget.customMessage!.trim().isNotEmpty) {
      return widget.customMessage!.trim();
    }
    if (widget.isShipping) return 'جاري إرسال طلب الشحن...';
    if (widget.isMotorcycle) return 'جاري البحث عن موتوسيكل...';
    return 'جاري البحث عن كابتن...';
  }

  Color get _accent =>
      widget.isShipping ? const Color(0xff06B6D4) : const Color(0xffF97316);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B0E14),
        body: Stack(
          children: [
            if (widget.onBack != null)
              Positioned(
                top: topPadding + 12,
                right: 16,
                child: PressableScale(
                  onTap: widget.onBack!,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xff64748B),
                    size: 26,
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: _accent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xffCBD5E1),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
