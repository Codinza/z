import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  String _driverName = 'كابتن زوون';
  String _driverId = 'driver_dummy_001';

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
  }

  Future<void> _loadDriverInfo() async {
    final name = await AuthService.getUserName();
    final id = await AuthService.getUserId();
    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _driverName = name;
        if (id != null && id.isNotEmpty) _driverId = id;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xff121620),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xff1E293B)),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xffEF4444), size: 22),
              SizedBox(width: 8),
              Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج من حساب الكابتن؟',
            style: TextStyle(color: Color(0xff94A3B8), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: Color(0xff94A3B8))),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B0E14),
        appBar: AppBar(
          backgroundColor: const Color(0xff121620),
          title: const Text(
            'إعدادات الكابتن',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          children: [
            // Driver Profile Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff1A202C), Color(0xff121620)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xffF97316).withOpacity(0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xff1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xffF97316),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF97316).withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Color(0xffF97316), size: 34),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _driverName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'معرف الكابتن: $_driverId',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xff064E3B).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xff10B981)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 13, color: Color(0xff34D399)),
                              SizedBox(width: 4),
                              Text(
                                'حساب كابتن معتمد',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff34D399),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Settings Options Group
            Container(
              decoration: BoxDecoration(
                color: const Color(0xff121620),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff1E293B)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingTile(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: const Color(0xff38BDF8),
                    title: 'التبديل إلى واجهة العميل',
                    subtitle: 'الانتقال إلى خريطة طلب الرحلات كعميل',
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HomeScreen()),
                      );
                    },
                  ),
                  const Divider(color: Color(0xff1E293B), height: 1),
                  _buildSettingTile(
                    icon: Icons.headset_mic_rounded,
                    iconColor: const Color(0xffF97316),
                    title: 'المساعدة والدعم الفني',
                    subtitle: 'التواصل مع إدارة منصة زوون',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('فريق دعم زوون متاح 24/7 لمساعدتك'),
                          backgroundColor: Color(0xff121620),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Color(0xff1E293B), height: 1),
                  _buildSettingTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xffA855F7),
                    title: 'عن تطبيق زوون',
                    subtitle: 'الإصدار v1.0.0 • جميع الحقوق محفوظة',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Logout Card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xff121620),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff7F1D1D).withOpacity(0.4)),
              ),
              child: _buildSettingTile(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xffEF4444),
                title: 'تسجيل الخروج',
                subtitle: 'الخروج من حساب الكابتن الحالي',
                textColor: const Color(0xffEF4444),
                onTap: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color textColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xff94A3B8),
            fontSize: 12,
          ),
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: Color(0xff64748B),
      ),
      onTap: onTap,
    );
  }
}
