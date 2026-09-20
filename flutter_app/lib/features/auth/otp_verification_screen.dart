import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';
import 'pending_approval_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/super_admin_screen.dart';
import '../driver/driver_main_screen.dart';
import '../home/customer_main_screen.dart';

/// Shared post-auth routing used by login, register, and OTP screens.
Future<void> navigateAfterSuccessfulAuth(BuildContext context) async {
  final role = await AuthService.getUserRole();
  final status = await AuthService.getDriverStatus();
  if (!context.mounted) return;

  Widget destination;
  if (role == 'customer') {
    destination = const CustomerMainScreen();
  } else if (role == 'driver') {
    destination = status == 'approved'
        ? const DriverMainScreen()
        : const PendingApprovalScreen();
  } else if (role == 'super_admin') {
    destination = const SuperAdminScreen();
  } else if (role == 'admin') {
    destination = const AdminDashboardScreen();
  } else {
    destination = const CustomerMainScreen();
  }

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => destination),
    (_) => false,
  );
}

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phone,
    this.maskedPhone,
    this.role = 'customer',
    this.initialDevCode,
    this.initialResendAfterSeconds = 60,
    this.autoRequestCode = false,
  });

  final String phone;
  final String? maskedPhone;
  final String role;
  final String? initialDevCode;
  final int initialResendAfterSeconds;
  final bool autoRequestCode;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _otpLength = 6;

  final List<TextEditingController> _digitControllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_otpLength, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  String? _error;
  String? _devCode;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _devCode = widget.initialDevCode;
    _startCooldown(widget.initialResendAfterSeconds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNodes.first.requestFocus();
      if (widget.autoRequestCode) {
        _resend(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds < 0 ? 0 : seconds);
    if (_secondsLeft <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String get _code => _digitControllers.map((c) => c.text).join();

  String get _displayPhone =>
      widget.maskedPhone?.isNotEmpty == true ? widget.maskedPhone! : widget.phone;

  void _onDigitChanged(int index, String value) {
    setState(() => _error = null);

    if (value.length > 1) {
      // Paste of a full code into one box.
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _otpLength; i++) {
        _digitControllers[i].text = i < digits.length ? digits[i] : '';
      }
      final focusIndex = digits.length.clamp(0, _otpLength) - 1;
      if (focusIndex >= 0) {
        _focusNodes[focusIndex.clamp(0, _otpLength - 1)].requestFocus();
      }
      if (digits.length >= _otpLength) {
        _verify();
      }
      return;
    }

    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    if (_code.length == _otpLength) {
      _verify();
    }
  }

  Future<void> _verify() async {
    final code = _code;
    if (code.length != _otpLength) {
      setState(() => _error = 'أدخل الكود المكوّن من 6 أرقام');
      return;
    }
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    final result = await AuthService.verifyPhone(phone: widget.phone, code: code);
    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (result != null && result['accessToken'] != null) {
      await navigateAfterSuccessfulAuth(context);
      return;
    }

    setState(() {
      _error = result?['error']?.toString() ?? 'الكود غير صحيح';
      if (result?['expired'] == true) {
        for (final c in _digitControllers) {
          c.clear();
        }
        _focusNodes.first.requestFocus();
      }
    });
  }

  Future<void> _resend({bool silent = false}) async {
    if (_secondsLeft > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _error = null;
    });

    final result = await AuthService.resendVerificationCode(phone: widget.phone);
    if (!mounted) return;

    setState(() => _isResending = false);

    if (result == null) {
      setState(() => _error = 'فشل إرسال الكود. حاول مرة أخرى.');
      return;
    }

    if (result['error'] != null) {
      final retry = (result['retryAfterSeconds'] as num?)?.toInt();
      if (retry != null) {
        _startCooldown(retry);
      }
      setState(() => _error = result['error'].toString());
      return;
    }

    final cooldown = (result['resendAfterSeconds'] as num?)?.toInt() ?? 60;
    _startCooldown(cooldown);
    setState(() {
      _devCode = result['devCode']?.toString();
      for (final c in _digitControllers) {
        c.clear();
      }
    });
    _focusNodes.first.requestFocus();

    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال كود جديد')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/zoon_login_background.jpeg', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(.32)),
          SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xff171515).withOpacity(.86),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: Colors.white.withOpacity(.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'تأكيد رقم الموبايل',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'أدخل الكود المرسل إلى\n$_displayPhone',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.82),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                              if (kDebugMode && _devCode != null && _devCode!.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffff9b27).withOpacity(.18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xffff9b27).withOpacity(.5),
                                    ),
                                  ),
                                  child: Text(
                                    'وضع التطوير — الكود: $_devCode',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xffff9b27),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(_otpLength, (index) {
                                  return SizedBox(
                                    width: 46,
                                    height: 56,
                                    child: TextField(
                                      controller: _digitControllers[index],
                                      focusNode: _focusNodes[index],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: index == 0 ? _otpLength : 1,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: InputDecoration(
                                        counterText: '',
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(.08),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.white.withOpacity(.28),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: Color(0xffff9b27),
                                            width: 1.6,
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        if (value.isEmpty && index > 0) {
                                          _focusNodes[index - 1].requestFocus();
                                        }
                                        _onDigitChanged(index, value);
                                      },
                                    ),
                                  );
                                }),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xffff6b6b),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              ElevatedButton(
                                onPressed: _isVerifying ? null : _verify,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: const Color(0xffff7418),
                                  foregroundColor: Colors.white,
                                ),
                                child: _isVerifying
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'تأكيد',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed:
                                    (_secondsLeft > 0 || _isResending) ? null : _resend,
                                child: _isResending
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white70,
                                        ),
                                      )
                                    : Text(
                                        _secondsLeft > 0
                                            ? 'إعادة الإرسال بعد $_secondsLeft ث'
                                            : 'إعادة إرسال الكود',
                                        style: TextStyle(
                                          color: _secondsLeft > 0
                                              ? Colors.white54
                                              : Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
