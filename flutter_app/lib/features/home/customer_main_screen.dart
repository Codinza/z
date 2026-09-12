import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'customer_trips_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key});

  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_CustomerMainScreenState>();
    state?.setTab(index);
  }

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  int _currentIndex = 0;

  void setTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentIndex = index);
    }
  }

  late final List<Widget> _screens = [
    const HomeScreen(
      initialService: 'limousine',
      showServiceSelector: true,
    ),
    const CustomerTripsScreen(),
  ];

  final List<_NavDestination> _destinations = const [
    _NavDestination(
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _NavDestination(
      label: 'رحلاتي',
      icon: Icons.directions_car_outlined,
      activeIcon: Icons.directions_car_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0A0A0A),
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(40, 0, 40, 16),
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xff121620),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xff252E3E),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xffF97316).withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: List.generate(_destinations.length, (index) {
                final isSelected = _currentIndex == index;
                final dest = _destinations[index];
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = index),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xffF97316).withOpacity(0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? dest.activeIcon : dest.icon,
                            color: isSelected
                                ? const Color(0xffF97316)
                                : const Color(0xff94A3B8),
                            size: 22,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dest.label,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xffF97316)
                                  : const Color(0xff94A3B8),
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
