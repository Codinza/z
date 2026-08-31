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
    CustomerServiceSelectionScreen(
      onServiceSelected: _openService,
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

  void _openService(String service) {
    setState(() {
      _screens[0] = HomeScreen(
        initialService: service,
        showServiceSelector: false,
      );
      _currentIndex = 0;
    });
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
}

class CustomerServiceSelectionScreen extends StatelessWidget {
  final ValueChanged<String> onServiceSelected;

  const CustomerServiceSelectionScreen({super.key, required this.onServiceSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أهلاً بيك',
                        style: TextStyle(
                          color: Colors.blueGrey.shade600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'ماذا تريد اليوم؟',
                        style: TextStyle(
                          color: Color(0xff17233c),
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueGrey.withOpacity(0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Color(0xff2364aa),
                      size: 27,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'اختار الخدمة المناسبة وابدأ طلبك بسهولة',
                style: TextStyle(
                  color: Colors.blueGrey.shade600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 30),
              _ServiceOption(
                icon: Icons.inventory_2_outlined,
                title: 'شحن',
                subtitle: 'إرسال شحنتك من عنوان إلى عنوان بأمان',
                label: 'ابدأ طلب شحن',
                color: const Color(0xff16866b),
                onTap: () => onServiceSelected('shipping'),
              ),
              const SizedBox(height: 18),
              _ServiceOption(
                icon: Icons.directions_car_outlined,
                title: 'ليموزين',
                subtitle: 'اطلب سيارة مريحة توصلك لوجهتك',
                label: 'اطلب ليموزين',
                color: const Color(0xff2364aa),
                onTap: () => onServiceSelected('limousine'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ServiceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 18, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.16)!],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: Colors.white, size: 31),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 28),
              ],
            ),
            const SizedBox(height: 25),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
