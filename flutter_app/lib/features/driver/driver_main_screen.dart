import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'driver_background_service.dart';
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
  void initState() {
    super.initState();
    _startDriverBackgroundService();
  }

  Future<void> _startDriverBackgroundService() async {
    final driverId = await AuthService.getUserId();
    if (driverId != null && driverId.isNotEmpty) {
      DriverBackgroundService().startService(driverId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B0E14),
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff121620),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xff1E293B),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xffF97316).withOpacity(0.06),
                  blurRadius: 15,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xffF97316),
                        );
                      }
                      return const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xff94A3B8),
                      );
                    },
                  ),
                ),
                child: NavigationBar(
                  height: 68,
                  backgroundColor: Colors.transparent,
                  indicatorColor: const Color(0xffF97316).withOpacity(0.18),
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) => setState(() => _currentIndex = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.radar_outlined, color: Color(0xff94A3B8)),
                      selectedIcon: Icon(Icons.radar_rounded, color: Color(0xffF97316)),
                      label: 'الطلبات',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_rounded, color: Color(0xff94A3B8)),
                      selectedIcon: Icon(Icons.history_rounded, color: Color(0xffF97316)),
                      label: 'الأرشيف',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined, color: Color(0xff94A3B8)),
                      selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: Color(0xffF97316)),
                      label: 'الأرباح',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined, color: Color(0xff94A3B8)),
                      selectedIcon: Icon(Icons.settings_rounded, color: Color(0xffF97316)),
                      label: 'الإعدادات',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
