import 'package:flutter/material.dart';
import '../auth/api_service.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../notifications/notifications_screen.dart';
import '../payment/payment_method_screen.dart';
import '../settings/contact_us_screen.dart';
import '../profile/personal_data_screen.dart';
import '../profile/saved_addresses_screen.dart';
import '../profile/security_screen.dart';
import '../profile/about_app_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _profileData = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      final profile = await ApiService.getCustomerProfile();
      if (!mounted) return;
      setState(() {
        _profileData = profile;
        _errorMessage = '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر تحميل الملف الشخصي، يرجى المحاولة مرة أخرى';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0a0a0a),
        appBar: AppBar(
          backgroundColor: const Color(0xff111315),
          elevation: 0,
          title: const Text('حسابي', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xffF97316)),
              )
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xffF97316), size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadProfile,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF97316)),
                          child: const Text('جرب مرة أخرى', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        // Profile Header
                        Container(
                          color: const Color(0xff111315),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Avatar
                              Container(
                                width: 100,
                                height: 100,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xffF97316),
                                ),
                                child: const Center(
                                  child: Icon(Icons.person, size: 60, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _profileData['name'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _profileData['phone'] ?? '',
                                style: const TextStyle(color: Color(0xff999999), fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _profileData['email'] ?? 'no-email@example.com',
                                style: const TextStyle(color: Color(0xff999999), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Profile Menu Items
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              _buildProfileMenuItem(
                                Icons.person,
                                'بيانات شخصية',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PersonalDataScreen(
                                        initialProfile: _profileData,
                                      ),
                                    ),
                                  ).then((val) {
                                    if (val == true) _loadProfile();
                                  });
                                },
                              ),
                              _buildProfileMenuItem(
                                Icons.location_on,
                                'العناوين المحفوظة',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SavedAddressesScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildProfileMenuItem(
                                Icons.payment,
                                'طرق الدفع',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const PaymentMethodScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildProfileMenuItem(
                                Icons.notifications,
                                'الإشعارات',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const NotificationsScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildProfileMenuItem(
                                Icons.security,
                                'الأمان',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SecurityScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildProfileMenuItem(
                                Icons.help,
                                'المساعدة والدعم',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ContactUsScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildProfileMenuItem(
                                Icons.info,
                                'عن التطبيق',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AboutAppScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildProfileMenuItem(
                                Icons.logout,
                                'تسجيل الخروج',
                                () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xff1A1D21),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      title: const Text(
                                        'تسجيل الخروج',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: const Text(
                                        'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
                                        style: TextStyle(color: Color(0xffCBD5E1)),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text(
                                            'إلغاء',
                                            style: TextStyle(color: Color(0xff94A3B8)),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            await AuthService.logout();
                                            if (context.mounted) {
                                              Navigator.of(context,
                                                      rootNavigator: true)
                                                  .pushAndRemoveUntil(
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const LoginScreen()),
                                                (route) => false,
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xffff4444),
                                          ),
                                          child: const Text(
                                            'تسجيل الخروج',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                isLast: true,
                                textColor: const Color(0xffff4444),
                              ),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildProfileMenuItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isLast = false,
    Color textColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast ? BorderSide.none : const BorderSide(color: Color(0xff2a2a2a), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xffF97316), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.chevron_left, color: Color(0xff666666), size: 20),
          ],
        ),
      ),
    );
  }
}
