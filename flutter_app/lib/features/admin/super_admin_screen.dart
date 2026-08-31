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
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AdminDashboardScreen(),
    CustomerMainScreen(),
    DriverMainScreen(),
    ShippingDashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFff6b35),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings),
              label: 'الأدمن',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'العميل',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car),
              label: 'السائق',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping),
              label: 'الشحن',
            ),
          ],
        ),
      ),
    );
  }
}
