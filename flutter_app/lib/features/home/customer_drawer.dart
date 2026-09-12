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

class CustomerDrawer extends StatefulWidget {
  const CustomerDrawer({super.key});

  @override
  State<CustomerDrawer> createState() => _CustomerDrawerState();
}

class _CustomerDrawerState extends State<CustomerDrawer> {
  bool _isLoading = true;
  Map<String, dynamic> _profileData = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ApiService.getCustomerProfile();
      if (mounted) {
        setState(() {
          _profileData = profile;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Drawer(
        backgroundColor: const Color(0xff0E121A),
        elevation: 16,
        child: SafeArea(
          child: Column(
            children: [
              // ── Drawer Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: const BoxDecoration(
                  color: Color(0xff121620),
                  border: Border(
                    bottom: BorderSide(color: Color(0xff222A38), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Top close action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'حسابي',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Color(0xff94A3B8), size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'إغلاق',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // User Info
                    _isLoading
                        ? const SizedBox(
                            height: 64,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xffF97316),
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xffF97316), Color(0xffEA580C)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xffF97316).withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.person_rounded, size: 30, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _profileData['name'] ?? 'مستخدم زوون',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _profileData['phone'] ?? '',
                                      style: const TextStyle(
                                        color: Color(0xff94A3B8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_profileData['email'] != null &&
                                        _profileData['email'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _profileData['email'],
                                        style: const TextStyle(
                                          color: Color(0xff64748B),
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),

              // ── Drawer Menu List ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.person_outline_rounded,
                      title: 'بيانات شخصية',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PersonalDataScreen(initialProfile: _profileData),
                          ),
                        ).then((val) {
                          if (val == true) _loadProfile();
                        });
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.location_on_outlined,
                      title: 'العناوين المحفوظة',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SavedAddressesScreen()),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.payment_outlined,
                      title: 'طرق الدفع',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PaymentMethodScreen()),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.notifications_none_rounded,
                      title: 'الإشعارات',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.security_outlined,
                      title: 'الأمان',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SecurityScreen()),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.support_agent_rounded,
                      title: 'المساعدة والدعم',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.info_outline_rounded,
                      title: 'عن التطبيق',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutAppScreen()),
                        );
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Divider(color: Color(0xff222A38), height: 1),
                    ),
                    _buildDrawerItem(
                      icon: Icons.logout_rounded,
                      title: 'تسجيل الخروج',
                      textColor: const Color(0xffEF4444),
                      iconColor: const Color(0xffEF4444),
                      onTap: _showLogoutDialog,
                    ),
                  ],
                ),
              ),

              // ── Drawer Footer ──
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xff1C2330), width: 1),
                  ),
                ),
                child: const Text(
                  'زوون Zoon • v1.0.0',
                  style: TextStyle(
                    color: Color(0xff64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color textColor = Colors.white,
    Color iconColor = const Color(0xffF97316),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xffF97316).withOpacity(0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 21),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xff475569),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff161B24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xffEF4444), size: 24),
            SizedBox(width: 10),
            Text(
              'تسجيل الخروج',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
          style: TextStyle(color: Color(0xffCBD5E1), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Color(0xff94A3B8), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.logout();
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
