import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'otp_verification_screen.dart';
import '../../core/widgets/animations/zoon_animations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _carModelController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carYearController = TextEditingController();
  final _plateNumberController = TextEditingController();
  String _selectedRole = 'customer';
  String _vehicleCategory = 'car';
  bool _isLoading = false;
  bool _obscureText = true;

  Future<void> _register() async {
    final missingFields = _selectedRole == 'driver' &&
            (_carModelController.text.trim().isEmpty ||
                _carColorController.text.trim().isEmpty ||
                _carYearController.text.trim().isEmpty ||
                _plateNumberController.text.trim().isEmpty)
        ? (_vehicleCategory == 'motorcycle'
            ? 'يرجى إدخال بيانات الموتوسيكل كاملة'
            : 'يرجى إدخال بيانات السيارة كاملة')
        : _nameController.text.trim().isEmpty ||
                _phoneController.text.trim().isEmpty ||
                _passwordController.text.trim().isEmpty
            ? 'يرجى إدخال الاسم ورقم الهاتف وكلمة المرور'
            : null;
    if (missingFields != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(missingFields)),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.register(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text.trim(),
      email: _emailController.text.trim(),
      role: _selectedRole,
      carModel:
          _selectedRole == 'driver' ? _carModelController.text.trim() : null,
      carColor:
          _selectedRole == 'driver' ? _carColorController.text.trim() : null,
      carYear:
          _selectedRole == 'driver' ? _carYearController.text.trim() : null,
      plateNumber:
          _selectedRole == 'driver' ? _plateNumberController.text.trim() : null,
      vehicleCategory: _selectedRole == 'driver' ? _vehicleCategory : null,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result != null && result['requiresVerification'] == true) {
      final phone =
          (result['phone'] ?? _phoneController.text.trim()).toString();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phone: phone,
            maskedPhone: result['maskedPhone']?.toString(),
            role: _selectedRole,
            initialDevCode: result['devCode']?.toString(),
            initialResendAfterSeconds:
                (result['resendAfterSeconds'] as num?)?.toInt() ?? 60,
            channel: result['channel']?.toString() ?? 'whatsapp',
          ),
        ),
      );
      return;
    }

    if (result != null && result['accessToken'] != null) {
      await navigateAfterSuccessfulAuth(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result?['error'] ?? result?['message'] ?? 'فشل إنشاء الحساب',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
    _carYearController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xff94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xffF97316)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xff0F141D),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xff252E3E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xffF97316), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _roleChip({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _selectedRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xffF97316).withOpacity(0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xffF97316)
                  : const Color(0xff252E3E),
              width: selected ? 1.6 : 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? const Color(0xffF97316)
                    : const Color(0xff94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xff94A3B8),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vehicleChip({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _vehicleCategory == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vehicleCategory = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xffF97316).withOpacity(0.18)
                : const Color(0xff0F141D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xffF97316)
                  : const Color(0xff252E3E),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? const Color(0xffF97316)
                    : const Color(0xff94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xff94A3B8),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(color: Colors.white);

    return Scaffold(
      backgroundColor: const Color(0xff0B0E14),
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/zoon_login_background.jpeg',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xff0B0E14).withOpacity(0.35),
                  const Color(0xff0B0E14).withOpacity(0.92),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xff121620).withOpacity(0.95),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xff252E3E),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xffF97316).withOpacity(0.1),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'إنشاء حساب جديد',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'انضم إلى Zoon وابدأ رحلتك',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xff94A3B8),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    _roleChip(
                                      value: 'customer',
                                      label: 'عميل',
                                      icon: Icons.person_outline_rounded,
                                    ),
                                    const SizedBox(width: 10),
                                    _roleChip(
                                      value: 'driver',
                                      label: 'سائق',
                                      icon: Icons.local_taxi_outlined,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: _nameController,
                                  style: textStyle,
                                  decoration: _fieldDecoration(
                                    label: 'الاسم',
                                    icon: Icons.badge_outlined,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: textStyle,
                                  decoration: _fieldDecoration(
                                    label: 'رقم الهاتف',
                                    icon: Icons.phone_outlined,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: textStyle,
                                  decoration: _fieldDecoration(
                                    label: 'البريد الإلكتروني (اختياري)',
                                    icon: Icons.email_outlined,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscureText,
                                  style: textStyle,
                                  decoration: _fieldDecoration(
                                    label: 'كلمة المرور',
                                    icon: Icons.lock_outline,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscureText
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: const Color(0xff94A3B8),
                                      ),
                                      onPressed: () => setState(
                                        () => _obscureText = !_obscureText,
                                      ),
                                    ),
                                  ),
                                ),
                                AnimatedCrossFade(
                                  firstChild: const SizedBox.shrink(),
                                  secondChild: Column(
                                    children: [
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          _vehicleChip(
                                            value: 'car',
                                            label: 'سيارة',
                                            icon: Icons.directions_car_rounded,
                                          ),
                                          const SizedBox(width: 10),
                                          _vehicleChip(
                                            value: 'motorcycle',
                                            label: 'موتوسيكل',
                                            icon: Icons.two_wheeler_rounded,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      TextField(
                                        controller: _carModelController,
                                        style: textStyle,
                                        decoration: _fieldDecoration(
                                          label: _vehicleCategory ==
                                                  'motorcycle'
                                              ? 'موديل الموتوسيكل'
                                              : 'موديل السيارة',
                                          icon: Icons.directions_car_outlined,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      TextField(
                                        controller: _carColorController,
                                        style: textStyle,
                                        decoration: _fieldDecoration(
                                          label: _vehicleCategory ==
                                                  'motorcycle'
                                              ? 'لون الموتوسيكل'
                                              : 'لون السيارة',
                                          icon: Icons.palette_outlined,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      TextField(
                                        controller: _carYearController,
                                        keyboardType: TextInputType.number,
                                        style: textStyle,
                                        decoration: _fieldDecoration(
                                          label: 'سنة الصنع',
                                          icon: Icons.calendar_today_outlined,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      TextField(
                                        controller: _plateNumberController,
                                        style: textStyle,
                                        decoration: _fieldDecoration(
                                          label: 'رقم اللوحة',
                                          icon: Icons.pin_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                  crossFadeState: _selectedRole == 'driver'
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  duration: const Duration(milliseconds: 280),
                                ),
                                const SizedBox(height: 24),
                                ShimmerGlowButton(
                                  isEnabled: !_isLoading,
                                  height: 52,
                                  borderRadius: 14,
                                  onPressed: _isLoading ? null : _register,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.4,
                                          ),
                                        )
                                      : const Text(
                                          'إنشاء الحساب',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          PressableScale(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'لديك حساب بالفعل؟ سجّل دخول',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
