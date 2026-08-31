import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../../features/auth/auth_service.dart';
import '../../features/auth/login_screen.dart';

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
    const Scaffold(body: Center(child: Text('دليل الخدمات (قريباً)', style: TextStyle(fontSize: 20)))),
    const Scaffold(body: Center(child: Text('الأخبار (قريباً)', style: TextStyle(fontSize: 20)))),
    const Scaffold(body: Center(child: Text('المزيد (قريباً)', style: TextStyle(fontSize: 20)))),
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
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'الدليل',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.newspaper),
              label: 'الأخبار',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz),
              label: 'المزيد',
            ),
          ],
        ),
      ),
    );
  }
        ),
      ),
    );
  }
}
