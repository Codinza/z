import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../driver/driver_main_screen.dart';
import '../driver/driver_auth_screen.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _pollingTimer;
  bool _isChecking = false;
  String _currentStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Start auto-polling every 10 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkStatusSilently();
    });

    // Do an initial check
    _checkStatusSilently();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatusSilently() async {
    if (_isChecking) return;
    try {
      final status = await AuthService.refreshDriverStatus();
      if (!mounted) return;
      if (status == 'approved') {
        _navigateToDriverMain();
      } else if (status != null && status != _currentStatus) {
        setState(() => _currentStatus = status);
      }
    } catch (_) {}
  }

  Future<void> _checkStatusManually() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final status = await AuthService.refreshDriverStatus();
      if (!mounted) return;

      if (status == 'approved') {
        _navigateToDriverMain();
      } else if (status != null) {
        setState(() {
          _currentStatus = status;
          _isChecking = false;
        });
        if (status == 'pending') {
          _showSnackBar('حسابك لا يزال قيد المراجعة', Colors.orange);
        } else if (status == 'rejected') {
          _showSnackBar('تم رفض حسابك. تواصل مع الدعم', Colors.red);
        }
      } else {
        setState(() => _isChecking = false);
        _showSnackBar('تعذر الاتصال بالسيرفر', Colors.grey);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      _showSnackBar('تعذر الاتصال بالسيرفر', Colors.grey);
    }
  }

  void _navigateToDriverMain() {
    _pollingTimer?.cancel();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DriverMainScreen()),
      (_) => false,
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRejected = _currentStatus == 'rejected';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated icon
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = 1.0 + (_pulseController.value * 0.1);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isRejected
                                  ? Colors.red.withOpacity(0.15)
                                  : const Color(0xffF97316).withOpacity(0.15),
                              border: Border.all(
                                color: isRejected
                                    ? Colors.red.withOpacity(0.4)
                                    : const Color(0xffF97316).withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              isRejected
                                  ? Icons.cancel_outlined
                                  : Icons.hourglass_top_rounded,
                              size: 56,
                              color: isRejected
                                  ? Colors.red
                                  : const Color(0xffF97316),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 36),

                    // Title
                    Text(
                      isRejected ? 'تم رفض الطلب' : 'حسابك قيد المراجعة',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Description
                    Text(
                      isRejected
                          ? 'للأسف تم رفض طلب تسجيلك كسائق.\nيرجى التواصل مع فريق الدعم لمزيد من المعلومات.'
                          : 'يتم مراجعة بياناتك والتحقق منها.\nسيتم الموافقة على حسابك كسائق في أقرب وقت ممكن.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.75),
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    if (!isRejected) ...[
                      // Auto-check indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'يتم التحقق تلقائياً...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 40),

                    // Check status button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isChecking ? null : _checkStatusManually,
                        icon: _isChecking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(
                          _isChecking ? 'جاري التحقق...' : 'التحقق من حالة الحساب',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffF97316),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          _pollingTimer?.cancel();
                          await AuthService.logout();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DriverAuthScreen()),
                              (_) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text(
                          'تسجيل الخروج',
                          style: TextStyle(fontSize: 15),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.8),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Zoon branding
                    Text(
                      'Zoon',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.2),
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
