import 'package:flutter/material.dart';
import 'driver_dashboard_screen.dart';
import 'driver_archive_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_settings_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff172B3A),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: NavigationBar(
              height: 70,
              backgroundColor: Colors.transparent,
              indicatorColor: const Color(0xffD6A84F),
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox, color: Color(0xff172B3A)), label: 'الطلبات'),
                NavigationDestination(icon: Icon(Icons.history), label: 'الأرشيف'),
                NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'الأرباح'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
