import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'customer_trips_screen.dart';
import 'customer_profile_screen.dart';
import '../../core/widgets/animations/zoon_animations.dart';

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
    const CustomerProfileScreen(),
  ];

  final List<_NavDestination> _destinations = const [
    _NavDestination(
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _NavDestination(
      label: 'رحلاتي',
      icon: Icons.route_outlined,
      activeIcon: Icons.route_rounded,
    ),
    _NavDestination(
      label: 'حسابي',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B0E14),
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xff121620).withOpacity(0.96),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xff252E3E),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xffF97316).withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: List.generate(_destinations.length, (index) {
                final isSelected = _currentIndex == index;
                final dest = _destinations[index];
                return Expanded(
                  child: PressableScale(
                    scaleFactor: 0.94,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _currentIndex = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  const Color(0xffF97316).withOpacity(0.22),
                                  const Color(0xffF97316).withOpacity(0.08),
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xffF97316).withOpacity(0.35),
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.06 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            child: Icon(
                              isSelected ? dest.activeIcon : dest.icon,
                              color: isSelected
                                  ? const Color(0xffF97316)
                                  : const Color(0xff94A3B8),
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dest.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xffF97316)
                                  : const Color(0xff94A3B8),
                              fontSize: 10.5,
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
