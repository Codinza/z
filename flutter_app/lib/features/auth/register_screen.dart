import 'package:flutter/material.dart';
import 'pending_approval_screen.dart';
import 'auth_service.dart';
import '../home/customer_main_screen.dart';

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
  bool _isLoading = false;
  bool _obscureText = true;

  Future<void> _register() async {
    final missingFields = _selectedRole == 'driver' &&
            (_carModelController.text.trim().isEmpty ||
                _carColorController.text.trim().isEmpty ||
                _carYearController.text.trim().isEmpty ||
                _plateNumberController.text.trim().isEmpty)
        ? 'يرجى إدخال بيانات السيارة كاملة'
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
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result != null && result['accessToken'] != null) {
      if (_selectedRole == 'customer') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CustomerMainScreen()),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                result?['error'] ?? result?['message'] ?? 'فشل إنشاء الحساب')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    InputDecoration fieldDecoration(String label, {Widget? suffixIcon}) =>
        InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(.72)),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white.withOpacity(.06),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white.withOpacity(.28)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xffff9b27), width: 1.5),
          ),
        );

    const textStyle = TextStyle(color: Colors.white);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/zoon_login_background.jpeg', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(.28)),
          SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'إنشاء حساب جديد',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'انضم إلى Zoon وابدأ رحلتك',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withOpacity(.82), fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xff171515).withOpacity(.82),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Colors.white.withOpacity(.2)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(.3),
                              blurRadius: 24,
                              offset: const Offset(0, 12)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _selectedRole = 'customer'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    decoration: BoxDecoration(
                                      color: _selectedRole == 'customer'
                                          ? const Color(0xffff7e5f)
                                              .withOpacity(.25)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _selectedRole == 'customer'
                                            ? const Color(0xffff9b27)
                                            : Colors.white.withOpacity(.35),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Text('عميل',
                                          style: TextStyle(
                                              fontSize: 17,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedRole = 'driver'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    decoration: BoxDecoration(
                                      color: _selectedRole == 'driver'
                                          ? const Color(0xffff7e5f)
                                              .withOpacity(.25)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _selectedRole == 'driver'
                                            ? const Color(0xffff9b27)
                                            : Colors.white.withOpacity(.35),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Text('سائق',
                                          style: TextStyle(
                                              fontSize: 17,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _nameController,
                            style: textStyle,
                            decoration: fieldDecoration('الاسم'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: textStyle,
                            decoration: fieldDecoration('رقم الهاتف'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: textStyle,
                            decoration:
                                fieldDecoration('البريد الإلكتروني (اختياري)'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscureText,
                            style: textStyle,
                            decoration: fieldDecoration(
                              'كلمة المرور',
                              suffixIcon: IconButton(
                                icon: Icon(_obscureText
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                color: const Color(0xffff9b27),
                                onPressed: () => setState(
                                    () => _obscureText = !_obscureText),
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: const SizedBox(height: 0),
                            secondChild: Column(
                              children: [
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _carModelController,
                                  style: textStyle,
                                  decoration: fieldDecoration('موديل السيارة'),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _carColorController,
                                  style: textStyle,
                                  decoration: fieldDecoration('لون السيارة'),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _carYearController,
                                  keyboardType: TextInputType.number,
                                  style: textStyle,
                                  decoration: fieldDecoration('سنة الصنع'),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _plateNumberController,
                                  style: textStyle,
                                  decoration: fieldDecoration('رقم اللوحة'),
                                ),
                              ],
                            ),
                            crossFadeState: _selectedRole == 'driver'
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 300),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              backgroundColor: const Color(0xffff7418),
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor:
                                  const Color(0xffff7418).withOpacity(.5),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('إنشاء الحساب',
                                    style: TextStyle(
                                        fontSize: 17,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('لديك حساب بالفعل؟ سجل دخول',
                                style: TextStyle(
                                    fontSize: 15, color: Colors.white)),
                          ),
                        ],
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
