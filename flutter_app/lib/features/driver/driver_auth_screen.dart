import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/otp_verification_screen.dart';
import '../auth/pending_approval_screen.dart';
import 'driver_main_screen.dart';

class DriverAuthScreen extends StatefulWidget {
  final bool initialIsRegister;
  const DriverAuthScreen({super.key, this.initialIsRegister = true});

  @override
  State<DriverAuthScreen> createState() => _DriverAuthScreenState();
}

class _DriverAuthScreenState extends State<DriverAuthScreen> {
  late bool _isRegister;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _carModelController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carYearController = TextEditingController();
  final _plateNumberController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _vehicleCategory = 'car'; // car | motorcycle

  @override
  void initState() {
    super.initState();
    _isRegister = widget.initialIsRegister;
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

  Future<void> _submitRegister() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final carModel = _carModelController.text.trim();
    final carColor = _carColorController.text.trim();
    final carYear = _carYearController.text.trim();
    final plateNumber = _plateNumberController.text.trim();

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      _showErrorSnackBar('يرجى إدخال الاسم ورقم الهاتف وكلمة المرور');
      return;
    }

    if (carModel.isEmpty || carColor.isEmpty || carYear.isEmpty || plateNumber.isEmpty) {
      _showErrorSnackBar(
        _vehicleCategory == 'motorcycle'
            ? 'يرجى إدخال بيانات الموتوسيكل كاملة (الموديل، اللون، السنة، اللوحة)'
            : 'يرجى إدخال بيانات السيارة كاملة (الموديل، اللون، السنة، اللوحة)',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.register(
        name: name,
        phone: phone,
        password: password,
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        role: 'driver',
        carModel: carModel,
        carColor: carColor,
        carYear: carYear,
        plateNumber: plateNumber,
        vehicleCategory: _vehicleCategory,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // OTP gate: registration succeeds without tokens until phone is verified.
      if (result != null && result['requiresVerification'] == true) {
        final verifiedPhone =
            (result['phone'] ?? phone).toString();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phone: verifiedPhone,
              maskedPhone: result['maskedPhone']?.toString(),
              role: 'driver',
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
          (_) => false,
        );
        return;
      }

      _showErrorSnackBar(
        result?['error']?.toString() ??
            result?['message']?.toString() ??
            'فشل إنشاء حساب الكابتن',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar('حدث خطأ في الاتصال بالسيرفر');
    }
  }

  Future<void> _submitLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showErrorSnackBar('يرجى إدخال رقم الهاتف وكلمة المرور');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.login(phone: phone, password: password);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result != null && result['requiresVerification'] == true) {
        final verifiedPhone = (result['phone'] ?? phone).toString();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phone: verifiedPhone,
              maskedPhone: result['maskedPhone']?.toString(),
              role: 'driver',
              initialResendAfterSeconds: 0,
              autoRequestCode: true,
              channel: result['channel']?.toString() ?? 'whatsapp',
            ),
          ),
        );
        return;
      }

      if (result != null && result['accessToken'] != null) {
        final role = result['user']?['role'];
        final status = result['driver']?['status'] ?? result['user']?['driverStatus'] ?? 'pending';

        if (role == 'driver') {
          if (status == 'approved') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const DriverMainScreen()),
              (_) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
              (_) => false,
            );
          }
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DriverMainScreen()),
            (_) => false,
          );
        }
        return;
      }

      _showErrorSnackBar(
        result?['error']?.toString() ??
            result?['message']?.toString() ??
            'بيانات الدخول غير صحيحة',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar('حدث خطأ أثناء تسجيل الدخول');
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xffEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0D0F11),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xffF97316),
                          const Color(0xffF97316).withOpacity(0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF97316).withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_taxi,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'كابتن زوون',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _isRegister
                        ? 'انضم لأسطول السائقين وابدأ في استقبال الرحلات'
                        : 'سجل دخولك لمتابعة مشاويرك وأرباحك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xff1A1D21),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRegister = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isRegister ? const Color(0xffF97316) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'تسجيل كابتن جديد',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _isRegister ? Colors.white : Colors.white60,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRegister = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isRegister ? const Color(0xffF97316) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'تسجيل الدخول',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: !_isRegister ? Colors.white : Colors.white60,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_isRegister) ...[
                  _buildSectionTitle('البيانات الشخصية', Icons.person),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _nameController,
                    label: 'الاسم بالكامل',
                    hint: 'مثال: أحمد محمد علي',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    hint: '01xxxxxxxxx',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني (اختياري)',
                    hint: 'driver@example.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'كلمة المرور',
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white60,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('نوع المركبة', Icons.two_wheeler),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildVehicleCategoryChip(
                          value: 'car',
                          label: 'سيارة',
                          icon: Icons.directions_car_filled_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildVehicleCategoryChip(
                          value: 'motorcycle',
                          label: 'موتوسيكل',
                          icon: Icons.two_wheeler_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                    _vehicleCategory == 'motorcycle'
                        ? 'بيانات الموتوسيكل والترخيص'
                        : 'بيانات السيارة والترخيص',
                    _vehicleCategory == 'motorcycle'
                        ? Icons.two_wheeler
                        : Icons.directions_car,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _carModelController,
                    label: _vehicleCategory == 'motorcycle'
                        ? 'نوع وموديل الموتوسيكل'
                        : 'نوع وموديل السيارة',
                    hint: _vehicleCategory == 'motorcycle'
                        ? 'مثال: هوندا شادو / ياماها'
                        : 'مثال: نيسان صني / تويوتا كورولا',
                    icon: _vehicleCategory == 'motorcycle'
                        ? Icons.two_wheeler_outlined
                        : Icons.directions_car_outlined,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _carColorController,
                          label: _vehicleCategory == 'motorcycle'
                              ? 'لون الموتوسيكل'
                              : 'لون السيارة',
                          hint: 'مثال: أسود',
                          icon: Icons.color_lens_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _carYearController,
                          label: 'سنة الصنع',
                          hint: 'مثال: 2022',
                          icon: Icons.calendar_today_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _plateNumberController,
                    label: 'رقم اللوحة المعدنية',
                    hint: 'مثال: س ق د 1234',
                    icon: Icons.badge_outlined,
                  ),
                ] else ...[
                  _buildTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    hint: '01xxxxxxxxx',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'كلمة المرور',
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white60,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isLoading ? null : (_isRegister ? _submitRegister : _submitLogin),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffF97316),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _isRegister ? 'تسجيل حساب كابتن جديد' : 'تسجيل الدخول',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCategoryChip({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _vehicleCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _vehicleCategory = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xffF97316).withOpacity(0.2)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xffF97316) : Colors.white24,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? const Color(0xffF97316) : Colors.white70,
                size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xffF97316)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff16191D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
          prefixIcon: Icon(icon, color: const Color(0xffF97316), size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
