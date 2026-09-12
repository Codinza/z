import 'package:flutter/material.dart';
import '../admin/shipping_dashboard_screen.dart';
import '../auth/auth_service.dart';

class CompanyAuthScreen extends StatefulWidget {
  const CompanyAuthScreen({super.key});

  @override
  State<CompanyAuthScreen> createState() => _CompanyAuthScreenState();
}

class _CompanyAuthScreenState extends State<CompanyAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login controllers
  final _loginPhoneController = TextEditingController(text: 'company001');
  final _loginPasswordController = TextEditingController(text: 'company123');

  // Register controllers
  final _companyNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerAddressController = TextEditingController();
  final _registerPasswordController = TextEditingController();

  String _companyType = 'SHIPPING';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _companyNameController.dispose();
    _contactPersonController.dispose();
    _registerPhoneController.dispose();
    _registerEmailController.dispose();
    _registerAddressController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final phone = _loginPhoneController.text.trim();
    final password = _loginPasswordController.text;

    if (phone.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال الهاتف وكلمة المرور');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService.loginCompany(
        phone: phone,
        password: password,
      );

      if (!mounted) return;

      if (res != null && res['accessToken'] != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ShippingDashboardScreen()),
        );
      } else {
        setState(() {
          _errorMessage = res?['error'] ?? 'بيانات الدخول غير صحيحة';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'حدث خطأ أثناء الدخول: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRegister() async {
    final name = _companyNameController.text.trim();
    final person = _contactPersonController.text.trim();
    final phone = _registerPhoneController.text.trim();
    final password = _registerPasswordController.text;

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'يرجى ملء جميع الحقول المطلوبة');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService.registerCompany(
        companyName: name,
        companyType: _companyType,
        contactPerson: person.isEmpty ? 'المسؤول' : person,
        phone: phone,
        password: password,
        email: _registerEmailController.text.trim(),
        address: _registerAddressController.text.trim(),
      );

      if (!mounted) return;

      if (res != null && res['accessToken'] != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ShippingDashboardScreen()),
        );
      } else {
        setState(() {
          _errorMessage = res?['error'] ?? 'فشل تسجيل الشركة، تحقق من البيانات';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'حدث خطأ: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0D9488); // Teal
    const darkBg = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.35),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 42,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'شركات زوون للخدمات',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'بوابة شركات الشحن والليموزين وإدارة الطلبات',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white60),
              ),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'تسجيل الدخول'),
                    Tab(text: 'تسجيل شركة جديدة'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                height: 540,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLoginTab(primaryColor),
                    _buildRegisterTab(primaryColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginTab(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _buildTextField(
          controller: _loginPhoneController,
          label: 'رقم هاتف الشركة أو المسؤول',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _loginPasswordController,
          label: 'كلمة المرور',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primaryColor.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF0D9488), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حساب تجريبي: company001 / كلمة المرور: company123',
                  style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'دخول إلى لوحة الشركة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRegisterTab(Color primaryColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          _buildTextField(
            controller: _companyNameController,
            label: 'اسم الشركة *',
            icon: Icons.business,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _companyType = 'SHIPPING'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _companyType == 'SHIPPING'
                          ? primaryColor.withOpacity(0.25)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _companyType == 'SHIPPING' ? primaryColor : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'شركة شحن طرود',
                        style: TextStyle(
                          color: _companyType == 'SHIPPING' ? Colors.white : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _companyType = 'LIMOUSINE'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _companyType == 'LIMOUSINE'
                          ? primaryColor.withOpacity(0.25)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _companyType == 'LIMOUSINE' ? primaryColor : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'شركة ليموزين',
                        style: TextStyle(
                          color: _companyType == 'LIMOUSINE' ? Colors.white : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _contactPersonController,
            label: 'اسم المسؤول',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _registerPhoneController,
            label: 'رقم هاتف الشركة *',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _registerEmailController,
            label: 'البريد الإلكتروني (اختياري)',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _registerAddressController,
            label: 'العنوان أو المقر الرئيسي',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _registerPasswordController,
            label: 'كلمة المرور *',
            icon: Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'تسجيل شركة جديدة',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF0D9488), size: 20),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
        ),
      ),
    );
  }
}
