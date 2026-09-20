import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../../core/config/app_config.dart';
import '../../core/services/notification_service.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import 'admin_service.dart';
import 'tabs/overview_tab.dart';
import 'tabs/drivers_management_tab.dart';
import 'tabs/finances_tab.dart';
import 'tabs/customers_tab.dart';
import 'tabs/support_tab.dart';
import 'tabs/companies_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  socket_io.Socket? _socket;
  bool _isSocketConnected = false;

  // Stats
  int _onlineDriversCount = 0;
  List<String> _onlineDriversList = [];
  int _registeredUsers = 0;
  int _registeredDrivers = 0;
  int _totalTrips = 0;
  int _pendingTrips = 0;
  int _activeTrips = 0;
  int _completedTrips = 0;
  int _cancelledTrips = 0;
  int _customersWhoOrdered = 0;
  List<Map<String, dynamic>> _driverEarnings = [];
  List<Map<String, dynamic>> _customerOrders = [];

  // Tab Badge Counters
  int _pendingDriversCount = 0;
  int _pendingTopUpsCount = 0;
  int _openTicketsCount = 0;
  int _pendingCompaniesCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchAllData();
    _initSocket();

    // Auto-refresh stats every 6 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _fetchAllData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

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

  void _initSocket() {
    _socket = socket_io.io(AppConfig.backendBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    _socket!.connect();

    _socket!.onConnect((_) {
      if (mounted) setState(() => _isSocketConnected = true);
    });

    _socket!.onDisconnect((_) {
      if (mounted) setState(() => _isSocketConnected = false);
    });

    // Listen for new limousine trips
    _socket!.on('trip_request', (data) {
      if (mounted) _fetchAllData();
      NotificationService().showNotification(
        title: 'طلب مشوار جديد 🚖',
        body: 'تم استلام طلب رحلة جديد في النظام',
      );
    });

    // Listen for trip status changes
    _socket!.on('trip_status_changed', (data) {
      if (mounted) _fetchAllData();
      if (data is! Map) return;
      final status = data['status']?.toString();
      if (status == 'accepted') {
        NotificationService().showNotification(
          title: 'مشوار قيد التنفيذ 🚖',
          body: 'قبل أحد السائقين طلب الرحلة وهو في طريقه للعميل',
        );
      } else if (status == 'completed') {
        NotificationService().showNotification(
          title: 'اكتمل المشوار بنجاح 🏁✅',
          body: 'تم إنهاء الرحلة وتسجيل الأرباح',
        );
      }
    });

    // Listen for shipping order status changes
    _socket!.on('order_status_changed', (data) {
      if (mounted) _fetchAllData();
      if (data is! Map) return;
      final status = data['status']?.toString();
      if (status == 'NEW_SHIPPING_ORDER') {
        NotificationService().showNotification(
          title: 'طلب شحن جديد 📦',
          body: 'تم إنشاء طلب شحن بضائع جديد في النظام',
        );
      }
    });
  }

  Future<void> _fetchAllData() async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final statsRes = await dio.get('/api/admin/stats');

      if (statsRes.statusCode == 200) {
        final data = statsRes.data;
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = null;
            _onlineDriversCount = data['onlineDriversCount'] ?? 0;
            _onlineDriversList =
                List<String>.from(data['onlineDriversList'] ?? []);
            _registeredUsers = data['registeredUsers'] ?? 0;
            _registeredDrivers = data['registeredDrivers'] ?? 0;
            _totalTrips = data['totalTrips'] ?? 0;
            _pendingTrips = data['pendingTrips'] ?? 0;
            _activeTrips = data['activeTrips'] ?? 0;
            _completedTrips = data['completedTrips'] ?? 0;
            _cancelledTrips = data['cancelledTrips'] ?? 0;
            _customersWhoOrdered = data['customersWhoOrdered'] ?? 0;
            _driverEarnings = List<Map<String, dynamic>>.from(
              (data['driverEarnings'] ?? [])
                  .map((e) => Map<String, dynamic>.from(e)),
            );
            _customerOrders = List<Map<String, dynamic>>.from(
              (data['customerOrders'] ?? [])
                  .map((e) => Map<String, dynamic>.from(e)),
            );
          });
        }
      }

      // Fetch badge counters asynchronously
      final results = await Future.wait([
        AdminService.getPendingDrivers().catchError((_) => null),
        AdminService.getDriverTopUps().catchError((_) => <Map<String, dynamic>>[]),
        AdminService.getSupportTickets().catchError((_) => <String, dynamic>{}),
        AdminService.getAllCompanies(status: 'pending')
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (mounted) {
        setState(() {
          final pendingDriversMap = results[0] as Map<String, dynamic>?;
          final List pendingList = pendingDriversMap?['drivers'] ?? [];
          _pendingDriversCount = pendingList.length;

          final topUpsList = results[1] as List<Map<String, dynamic>>;
          _pendingTopUpsCount = topUpsList.length;

          final supportMap = results[2] as Map<String, dynamic>;
          final stats = supportMap['stats'] as Map<String, dynamic>? ?? {};
          _openTicketsCount = stats['open'] ?? 0;

          final pendingCompanies = results[3] as List<Map<String, dynamic>>;
          _pendingCompaniesCount = pendingCompanies.length;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'فشل الاتصال بالنظام: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B0E14),
        appBar: AppBar(
          backgroundColor: const Color(0xff12151A),
          elevation: 0,
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xffF97316).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings,
                    color: Color(0xffF97316), size: 22),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'لوحة تحكم الإدارة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'نظام إدارة الرحلات والكباتن والدعم',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Live Socket Indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isSocketConnected
                      ? const Color(0xff22C55E)
                      : Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isSocketConnected
                              ? const Color(0xff22C55E)
                              : Colors.redAccent)
                          .withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _fetchAllData,
              tooltip: 'تحديث البيانات',
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: _logout,
              tooltip: 'تسجيل الخروج',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: const Color(0xffF97316),
            indicatorWeight: 3,
            labelColor: const Color(0xffF97316),
            unselectedLabelColor: Colors.white60,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            tabs: [
              const Tab(
                icon: Icon(Icons.dashboard_outlined, size: 18),
                text: 'نظرة عامة',
              ),
              Tab(
                icon: _buildBadgeIcon(
                  Icons.local_taxi_outlined,
                  _pendingDriversCount,
                ),
                text: 'السائقين',
              ),
              Tab(
                icon: _buildBadgeIcon(
                  Icons.account_balance_wallet_outlined,
                  _pendingTopUpsCount,
                ),
                text: 'المالية',
              ),
              const Tab(
                icon: Icon(Icons.people_alt_outlined, size: 18),
                text: 'العملاء',
              ),
              Tab(
                icon: _buildBadgeIcon(
                  Icons.business_outlined,
                  _pendingCompaniesCount,
                  badgeColor: const Color(0xffF59E0B),
                ),
                text: 'الشركات',
              ),
              Tab(
                icon: _buildBadgeIcon(
                  Icons.headset_mic_outlined,
                  _openTicketsCount,
                  badgeColor: const Color(0xffEF4444),
                ),
                text: 'الدعم الفني',
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xffF97316)))
            : _error != null && _totalTrips == 0 && _onlineDriversCount == 0
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off_outlined,
                            size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(_error!,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white70),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchAllData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xffF97316),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // 1. Overview Tab
                      OverviewTab(
                        onlineDriversCount: _onlineDriversCount,
                        onlineDriversList: _onlineDriversList,
                        registeredUsers: _registeredUsers,
                        registeredDrivers: _registeredDrivers,
                        totalTrips: _totalTrips,
                        pendingTrips: _pendingTrips,
                        activeTrips: _activeTrips,
                        completedTrips: _completedTrips,
                        cancelledTrips: _cancelledTrips,
                        customersWhoOrdered: _customersWhoOrdered,
                        driverEarnings: _driverEarnings,
                        customerOrders: _customerOrders,
                        onRefresh: _fetchAllData,
                        onNavigateToTab: (index) =>
                            _tabController.animateTo(index),
                      ),

                      // 2. Drivers Management Tab
                      DriversManagementTab(
                        onDataChanged: _fetchAllData,
                      ),

                      // 3. Finances & Top-Ups Tab
                      FinancesTab(
                        onDataChanged: _fetchAllData,
                      ),

                      // 4. Customers Directory Tab
                      const CustomersTab(),

                      // 5. Companies Management Tab
                      CompaniesTab(
                        onDataChanged: _fetchAllData,
                      ),

                      // 6. Support & Helpdesk Tab
                      SupportTab(
                        onDataChanged: _fetchAllData,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildBadgeIcon(IconData icon, int count, {Color? badgeColor}) {
    if (count <= 0) {
      return Icon(icon, size: 18);
    }
    return Badge(
      label: Text('$count',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      backgroundColor: badgeColor ?? const Color(0xffF97316),
      child: Icon(icon, size: 18),
    );
  }
}
