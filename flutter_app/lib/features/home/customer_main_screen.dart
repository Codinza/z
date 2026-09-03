import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'customer_profile_screen.dart';
import 'customer_balance_screen.dart';
import 'customer_trips_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    const HomeScreen(
      initialService: 'shipping',
      showServiceSelector: true,
    ),
    const CustomerTripsScreen(),
    const CustomerBalanceScreen(),
    const CustomerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff111315),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: NavigationBar(
              height: 68,
              backgroundColor: Colors.transparent,
              indicatorColor: const Color(0xffF97316),
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: Colors.white), label: 'الرئيسية'),
                NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car, color: Colors.white), label: 'رحلاتي'),
                NavigationDestination(icon: Icon(Icons.wallet_outlined), selectedIcon: Icon(Icons.wallet, color: Colors.white), label: 'الرصيد'),
                NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person, color: Colors.white), label: 'حسابي'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
