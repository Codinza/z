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
      carModel: _selectedRole == 'driver' ? _carModelController.text.trim() : null,
      carColor: _selectedRole == 'driver' ? _carColorController.text.trim() : null,
      carYear: _selectedRole == 'driver' ? _carYearController.text.trim() : null,
      plateNumber: _selectedRole == 'driver' ? _plateNumberController.text.trim() : null,
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
        SnackBar(content: Text(result?['error'] ?? result?['message'] ?? 'فشل إنشاء الحساب')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedRole = 'customer'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _selectedRole == 'customer' ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                          border: Border.all(
                            color: _selectedRole == 'customer' ? Colors.blue : Colors.grey,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('عميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedRole = 'driver'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _selectedRole == 'driver' ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                          border: Border.all(
                            color: _selectedRole == 'driver' ? Colors.blue : Colors.grey,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('سائق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'الاسم',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني (اختياري)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(height: 0),
                secondChild: Column(
                  children: [
                    const SizedBox(height: 16),
                    TextField(
                      controller: _carModelController,
                      decoration: InputDecoration(
                        labelText: 'موديل السيارة',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _carColorController,
                      decoration: InputDecoration(
                        labelText: 'لون السيارة',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _carYearController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'سنة الصنع',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _plateNumberController,
                      decoration: InputDecoration(
                        labelText: 'رقم اللوحة',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                crossFadeState: _selectedRole == 'driver' ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.blue,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('إنشاء الحساب', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('لديك حساب بالفعل؟ سجل دخول', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
