import 'package:flutter/material.dart';
import 'driver_dashboard_screen.dart';
import 'driver_archive_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_settings_screen.dart';
import '../../features/auth/auth_service.dart';
import '../../features/auth/login_screen.dart';

class DriverMainScreen extends StatefulWidget {
  const DriverMainScreen({super.key});

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DriverDashboardScreen(),
    const DriverArchiveScreen(),
    const DriverEarningsScreen(),
    const DriverSettingsScreen(),
  ];

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Zoon'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue.shade800,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'الطلبات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'الأرشيف',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet),
              label: 'الأرباح',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}
