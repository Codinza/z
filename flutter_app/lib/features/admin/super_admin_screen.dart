import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';
import 'shipping_dashboard_screen.dart';
import '../home/customer_main_screen.dart';
import '../driver/driver_main_screen.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  int _currentIndex = 2; // Default to Captain (الكابتن)

  final List<Widget> _screens = const [
    AdminDashboardScreen(),
    CustomerMainScreen(),
    DriverMainScreen(),
    ShippingDashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0E14),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xff0B0E14),
          border: Border(
            top: BorderSide(color: Color(0xff1E293B), width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: const Color(0xff0B0E14),
          elevation: 0,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xffF97316),
          unselectedItemColor: const Color(0xff64748B),
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings_rounded),
              label: 'الأدمن',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'العميل',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_taxi_outlined),
              activeIcon: Icon(Icons.local_taxi_rounded),
              label: 'الكابتن',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_outlined),
              activeIcon: Icon(Icons.local_shipping_rounded),
              label: 'الشحن',
            ),
          ],
        ),
      ),
    );
  }
}
