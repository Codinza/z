import 'package:flutter/material.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/home/customer_main_screen.dart';
import 'features/driver/driver_main_screen.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/admin/super_admin_screen.dart';

class RideFlowApp extends StatelessWidget {
  const RideFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zoon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffF97316),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xffF97316),
          secondary: const Color(0xff111315),
          surface: const Color(0xffF6F7F8),
        ),
        scaffoldBackgroundColor: const Color(0xffF6F7F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff111315),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xffF97316),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    
    setState(() {
      _isAuthenticated = isLoggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthenticated) {
      return const LoginScreen();
    }

    return const MainNavigation();
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await AuthService.getUserRole();
    if (!mounted) return;
    setState(() {
      _userRole = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    switch (_userRole) {
      case 'super_admin':
        return const SuperAdminScreen();
      case 'customer':
        return const CustomerMainScreen();
      case 'driver':
        return const DriverMainScreen();
      case 'admin':
        return const AdminDashboardScreen();
      default:
        return const CustomerMainScreen();
    }
  }
}
