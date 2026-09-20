import 'package:flutter/material.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/pending_approval_screen.dart';
import 'features/home/customer_main_screen.dart';
import 'features/driver/driver_main_screen.dart';
import 'features/driver/driver_auth_screen.dart';
import 'features/company/company_auth_screen.dart';
import 'features/admin/shipping_dashboard_screen.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/admin/super_admin_screen.dart';
import 'features/intro/intro_video_screen.dart';
import 'core/widgets/animations/zoon_animations.dart';

const String appType = String.fromEnvironment('APP_TYPE', defaultValue: '');

class RideFlowApp extends StatelessWidget {
  const RideFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    Color seedColor = const Color(0xffF97316);
    String appTitle = 'Zoon';

    if (appType == 'company') {
      seedColor = const Color(0xFF0D9488);
      appTitle = 'Zoon Company';
    } else if (appType == 'driver') {
      seedColor = const Color(0xffF97316);
      appTitle = 'Zoon Driver';
    } else if (appType == 'admin') {
      seedColor = const Color(0xffF97316);
      appTitle = 'Zoon Admin';
    }

    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: seedColor,
          secondary: const Color(0xffF97316),
          surface: const Color(0xff121620),
        ),
        scaffoldBackgroundColor: const Color(0xff0B0E14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff12151A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: seedColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: LogisticsPageTransitionsBuilder(),
            TargetPlatform.iOS: LogisticsPageTransitionsBuilder(),
          },
        ),
        useMaterial3: true,
      ),
      home: const IntroVideoScreen(),
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
      if (appType == 'driver') {
        return const DriverAuthScreen();
      }
      if (appType == 'company') {
        return const CompanyAuthScreen();
      }
      return const LoginScreen();
    }

    if (appType == 'driver') {
      return const DriverGate();
    }
    if (appType == 'company') {
      return const ShippingDashboardScreen();
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
        return const DriverGate();
      case 'company':
        return const ShippingDashboardScreen();
      case 'admin':
        return const AdminDashboardScreen();
      default:
        return const CustomerMainScreen();
    }
  }
}

/// Gate widget that checks driver approval status before allowing access to DriverMainScreen.
/// Shows PendingApprovalScreen for unapproved drivers.
class DriverGate extends StatefulWidget {
  const DriverGate({super.key});

  @override
  State<DriverGate> createState() => _DriverGateState();
}

class _DriverGateState extends State<DriverGate> {
  String? _status;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    // First, quickly show based on cached status
    final cachedStatus = await AuthService.getDriverStatus();
    if (!mounted) return;
    setState(() {
      _status = cachedStatus;
      _isLoading = false;
    });

    // Then verify with backend in the background
    final freshStatus = await AuthService.refreshDriverStatus();
    if (!mounted) return;
    if (freshStatus != null && freshStatus != _status) {
      setState(() {
        _status = freshStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_status == 'approved') {
      return const DriverMainScreen();
    }

    return const PendingApprovalScreen();
  }
}
