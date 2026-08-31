import 'package:flutter/material.dart';
import 'dart:async';
import '../../features/auth/auth_service.dart';
import '../../features/auth/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

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

  @override
  void initState() {
    super.initState();
    _fetchStats();
    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.get('/api/admin/stats');

      if (response.statusCode == 200) {
        final data = response.data;
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = null;
            _onlineDriversCount = data['onlineDriversCount'] ?? 0;
            _onlineDriversList = List<String>.from(data['onlineDriversList'] ?? []);
            _registeredUsers = data['registeredUsers'] ?? 0;
            _registeredDrivers = data['registeredDrivers'] ?? 0;
            _totalTrips = data['totalTrips'] ?? 0;
            _pendingTrips = data['pendingTrips'] ?? 0;
            _activeTrips = data['activeTrips'] ?? 0;
            _completedTrips = data['completedTrips'] ?? 0;
            _cancelledTrips = data['cancelledTrips'] ?? 0;
            _customersWhoOrdered = data['customersWhoOrdered'] ?? 0;
            _driverEarnings = List<Map<String, dynamic>>.from(
              (data['driverEarnings'] ?? []).map((e) => Map<String, dynamic>.from(e)),
            );
            _customerOrders = List<Map<String, dynamic>>.from(
              (data['customerOrders'] ?? []).map((e) => Map<String, dynamic>.from(e)),
            );
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'خطأ ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'فشل الاتصال: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة تحكم الإدارة'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchStats,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _fetchStats, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchStats,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSectionTitle('نظرة عامة'),
                        const SizedBox(height: 12),
                        _buildOverviewCards(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('إحصائيات الرحلات'),
                        const SizedBox(height: 12),
                        _buildTripStatsCards(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('أرباح السائقين'),
                        const SizedBox(height: 12),
                        _buildDriverEarningsTable(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('طلبات العملاء'),
                        const SizedBox(height: 12),
                        _buildCustomerOrdersTable(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('السائقين المتصلين الآن'),
                        const SizedBox(height: 12),
                        _buildOnlineDriversList(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.deepPurple.shade800,
      ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('سائقين متصلين', '$_onlineDriversCount', Icons.wifi, Colors.green),
        _buildStatCard('عملاء مسجلين', '$_registeredUsers', Icons.people, Colors.blue),
        _buildStatCard('سائقين مسجلين', '$_registeredDrivers', Icons.local_taxi, Colors.orange),
        _buildStatCard('عملاء طلبوا رحلات', '$_customersWhoOrdered', Icons.shopping_cart, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildTripStatsCards() {
    return Row(
      children: [
        _buildMiniStat('إجمالي', _totalTrips, Colors.indigo),
        const SizedBox(width: 8),
        _buildMiniStat('معلقة', _pendingTrips, Colors.amber),
        const SizedBox(width: 8),
        _buildMiniStat('نشطة', _activeTrips, Colors.blue),
        const SizedBox(width: 8),
        _buildMiniStat('مكتملة', _completedTrips, Colors.green),
        const SizedBox(width: 8),
        _buildMiniStat('ملغية', _cancelledTrips, Colors.red),
      ],
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverEarningsTable() {
    if (_driverEarnings.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('لا توجد أرباح بعد (لم تكتمل أي رحلة)', style: TextStyle(color: Colors.grey.shade600))),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(1)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.deepPurple.shade50),
              children: const [
                Padding(padding: EdgeInsets.all(10), child: Text('السائق', style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(10), child: Text('الأرباح (ج.م)', style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(10), child: Text('الرحلات', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            ..._driverEarnings.map((e) => TableRow(children: [
                  Padding(padding: const EdgeInsets.all(10), child: Text(e['driverName'] ?? e['driverId'])),
                  Padding(padding: const EdgeInsets.all(10), child: Text('${(e['totalEarnings'] as num).toStringAsFixed(2)} ج.م')),
                  Padding(padding: const EdgeInsets.all(10), child: Text('${e['completedTrips']}')),
                ])),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerOrdersTable() {
    if (_customerOrders.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('لا توجد طلبات بعد', style: TextStyle(color: Colors.grey.shade600))),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1.5)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.deepPurple.shade50),
              children: const [
                Padding(padding: EdgeInsets.all(10), child: Text('العميل', style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(10), child: Text('الطلبات', style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(10), child: Text('المصروف (ج.م)', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            ..._customerOrders.map((c) => TableRow(children: [
                  Padding(padding: const EdgeInsets.all(10), child: Text(c['userName'] ?? c['userId'])),
                  Padding(padding: const EdgeInsets.all(10), child: Text('${c['totalOrders']}')),
                  Padding(padding: const EdgeInsets.all(10), child: Text('${(c['totalSpent'] as num).toStringAsFixed(2)} ج.م')),
                ])),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineDriversList() {
    if (_onlineDriversList.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text('لا يوجد سائقين متصلين حالياً', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _onlineDriversList.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final driverId = _onlineDriversList[index];
          return ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.person, color: Colors.white)),
            title: Text(driverId),
            subtitle: const Text('متصل الآن', style: TextStyle(color: Colors.green)),
            trailing: Container(
              width: 12, height: 12,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            ),
          );
        },
      ),
    );
  }
}
