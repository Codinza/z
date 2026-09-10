import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../../features/auth/auth_service.dart';
import '../../features/auth/login_screen.dart';
import '../../core/config/app_config.dart';
import '../../core/services/notification_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  socket_io.Socket? _socket;

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
    _initSocket();
    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

  void _initSocket() {
    _socket = socket_io.io(AppConfig.backendBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    _socket!.connect();

    // Listen for new limousine trips
    _socket!.on('trip_request', (data) {
      if (mounted) {
        _fetchStats();
      }
      NotificationService().showNotification(
        title: 'طلب مشوار جديد 🚖',
        body: 'تم استلام طلب رحلة ليموزين جديد في النظام',
      );
    });

    // Listen for trip status changes
    _socket!.on('trip_status_changed', (data) {
      if (mounted) {
        _fetchStats();
      }
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
      } else if (status == 'cancelled') {
        NotificationService().showNotification(
          title: 'تم إلغاء مشوار ⚠️',
          body: 'تم إلغاء طلب الرحلة في النظام',
        );
      }
    });

    // Listen for shipping order status changes
    _socket!.on('order_status_changed', (data) {
      if (mounted) {
        _fetchStats();
      }
      if (data is! Map) return;
      final status = data['status']?.toString();
      final orderId = data['orderId']?.toString();

      if (status == 'NEW_SHIPPING_ORDER') {
        NotificationService().showNotification(
          title: 'طلب شحن جديد 📦',
          body: 'تم إنشاء طلب شحن بضائع جديد في النظام',
        );
      } else if (status == 'CUSTOMER_APPROVED' || status == 'CONFIRMED') {
        NotificationService().showNotification(
          title: 'تم تأكيد طلب شحن 🚚',
          body: 'وافق العميل على عرض السعر وتم تأكيد الشحنة',
        );
      } else if (status == 'COMPLETED') {
        NotificationService().showNotification(
          title: 'تم إكمال شحنة 📦✅',
          body: 'تم تسليم الشحنة وإكمال الطلب بنجاح',
        );
      } else if (status == 'CANCELLED') {
        NotificationService().showNotification(
          title: 'تم إلغاء طلب شحن ⚠️',
          body: 'تم إلغاء طلب الشحن ${orderId ?? ''}',
        );
      }
    });
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
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _fetchStats,
                            child: const Text('إعادة المحاولة')),
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
                        const SizedBox(height: 16),
                        _buildDriverManagementBanner(),
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
      childAspectRatio: 1.35,
      children: [
        _buildStatCard(
            'سائقين متصلين', '$_onlineDriversCount', Icons.wifi, Colors.green),
        _buildStatCard(
            'عملاء مسجلين', '$_registeredUsers', Icons.people, Colors.blue),
        _buildStatCard('سائقين مسجلين', '$_registeredDrivers', Icons.local_taxi,
            Colors.orange),
        _buildStatCard('عملاء طلبوا رحلات', '$_customersWhoOrdered',
            Icons.shopping_cart, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.85), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white, size: 26),
                Text(value,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
            Text('$count',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
                textAlign: TextAlign.center),
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
          child: Center(
              child: Text('لا توجد أرباح بعد (لم تكتمل أي رحلة)',
                  style: TextStyle(color: Colors.grey.shade600))),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          border: TableBorder.all(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8)),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1)
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.deepPurple.shade50),
              children: const [
                Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('السائق',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('الأرباح (ج.م)',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('الرحلات',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            ..._driverEarnings.map((e) => TableRow(children: [
                  Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(e['driverName'] ?? e['driverId'])),
                  Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                          '${(e['totalEarnings'] as num).toStringAsFixed(2)} ج.م')),
                  Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text('${e['completedTrips']}')),
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
          child: Center(
              child: Text('لا توجد طلبات بعد',
                  style: TextStyle(color: Colors.grey.shade600))),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          border: TableBorder.all(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8)),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1.5)
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.deepPurple.shade50),
              children: const [
                Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('العميل',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('الطلبات',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('المصروف (ج.م)',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            ..._customerOrders.map((c) => TableRow(children: [
                  Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(c['userName'] ?? c['userId'])),
                  Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text('${c['totalOrders']}')),
                  Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                          '${(c['totalSpent'] as num).toStringAsFixed(2)} ج.م')),
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
                Text('لا يوجد سائقين متصلين حالياً',
                    style: TextStyle(color: Colors.grey.shade600)),
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
            leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.person, color: Colors.white)),
            title: Text(driverId),
            subtitle:
                const Text('متصل الآن', style: TextStyle(color: Colors.green)),
            trailing: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                  color: Colors.green, shape: BoxShape.circle),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDriverManagementBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff1A1D21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF97316).withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xffF97316).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_taxi,
                    color: Color(0xffF97316), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة واعتماد السائقين',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'مراجعة طلبات الانضمام واعتماد الكباتن أو تسجيل سائق جديد',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showPendingDriversDialog,
                  icon: const Icon(Icons.pending_actions, size: 18),
                  label: const Text('السائقين المعلقين'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showAddDriverDialog,
                  icon: const Icon(Icons.person_add,
                      size: 18, color: Color(0xffF97316)),
                  label: const Text('إضافة سائق جديد',
                      style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xffF97316)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showTopUpRequestsDialog,
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              label: const Text('طلبات شحن المحافظ',
                  style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTopUpRequestsDialog() async {
    showDialog(
      context: context,
      builder: (dialogContext) => FutureBuilder(
        future: AuthService.getAuthenticatedDio()
            .then((dio) => dio.get('/api/admin/driver-top-ups')),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(
                content: SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator())));
          }
          final requests = List<Map<String, dynamic>>.from(
              snapshot.data?.data['requests'] ?? const []);
          return AlertDialog(
            title: const Text('طلبات شحن المحافظ'),
            content: SizedBox(
              width: 500,
              child: requests.isEmpty
                  ? const Text('لا توجد طلبات معلقة')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        final driver = request['driver']?['user'] ?? const {};
                        final image = request['receiptImage']?.toString() ?? '';
                        final imageData =
                            image.contains(',') ? image.split(',').last : '';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${driver['name'] ?? 'سائق'} - ${request['amount']} ج.م'),
                                Text(request['paymentMethod'] == 'instapay'
                                    ? 'InstaPay'
                                    : 'Vodafone Cash'),
                                if (imageData.isNotEmpty)
                                  Image.memory(base64Decode(imageData),
                                      height: 160, fit: BoxFit.contain),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () async {
                                        final dio = await AuthService
                                            .getAuthenticatedDio();
                                        await dio.post(
                                            '/api/admin/driver-top-ups/${request['id']}/review',
                                            data: {'approve': false});
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      },
                                      child: const Text('رفض',
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final dio = await AuthService
                                            .getAuthenticatedDio();
                                        await dio.post(
                                            '/api/admin/driver-top-ups/${request['id']}/review',
                                            data: {'approve': true});
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      },
                                      child: const Text('قبول وإضافة الرصيد'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إغلاق'))
            ],
          );
        },
      ),
    );
  }

  Future<void> _showPendingDriversDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xff16191D),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxHeight: 500, maxWidth: 450),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'طلبات السائقين المعلقة',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  Expanded(
                    child: FutureBuilder<dynamic>(
                      future: () async {
                        final dio = await AuthService.getAuthenticatedDio();
                        return await dio.get('/api/admin/drivers/pending');
                      }(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xffF97316)));
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'فشل تحميل السائقين: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        final data = snapshot.data?.data;
                        final List drivers = data?['drivers'] ?? [];
                        if (drivers.isEmpty) {
                          return const Center(
                            child: Text('لا توجد طلبات سائقين معلقة حالياً',
                                style: TextStyle(color: Colors.white60)),
                          );
                        }
                        return ListView.builder(
                          itemCount: drivers.length,
                          itemBuilder: (context, i) {
                            final d = drivers[i];
                            final user = d['user'] ?? {};
                            final car = d['car'] ?? {};
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xff1F2328),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        user['name'] ?? 'بدون اسم',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 15),
                                      ),
                                      Text(
                                        user['phone'] ?? '',
                                        style: const TextStyle(
                                            color: Color(0xffF97316),
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'السيارة: ${car['model'] ?? '-'} | ${car['color'] ?? '-'} | لوحة: ${car['plateNumber'] ?? '-'}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            final dio = await AuthService
                                                .getAuthenticatedDio();
                                            await dio.post(
                                                '/api/admin/drivers/${d['id']}/approve');
                                            setDialogState(() {});
                                            _fetchStats();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xff22C55E),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          child: const Text('قبول السائق ✓',
                                              style: TextStyle(fontSize: 13)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () async {
                                            final dio = await AuthService
                                                .getAuthenticatedDio();
                                            await dio.post(
                                                '/api/admin/drivers/${d['id']}/reject');
                                            setDialogState(() {});
                                            _fetchStats();
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: Color(0xffEF4444)),
                                            foregroundColor:
                                                const Color(0xffEF4444),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          child: const Text('رفض ✕',
                                              style: TextStyle(fontSize: 13)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddDriverDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: const Color(0xff16191D),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إضافة سائق واعتماده',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  _buildModalField(
                      nameCtrl, 'اسم السائق', 'أحمد علي', Icons.person),
                  const SizedBox(height: 10),
                  _buildModalField(
                      phoneCtrl, 'رقم الهاتف', '01xxxxxxxxx', Icons.phone,
                      keyboard: TextInputType.phone),
                  const SizedBox(height: 10),
                  _buildModalField(
                      passCtrl, 'كلمة المرور', '••••••••', Icons.lock,
                      obscure: true),
                  const SizedBox(height: 14),
                  const Text('بيانات السيارة',
                      style: TextStyle(
                          color: Color(0xffF97316),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildModalField(modelCtrl, 'موديل ونوع السيارة', 'نيسان صني',
                      Icons.directions_car),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _buildModalField(
                              colorCtrl, 'اللون', 'أبيض', Icons.color_lens)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildModalField(yearCtrl, 'سنة الصنع', '2023',
                              Icons.calendar_today,
                              keyboard: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildModalField(
                      plateCtrl, 'رقم اللوحة', 'س ق د 1234', Icons.badge),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty ||
                                phoneCtrl.text.trim().isEmpty ||
                                passCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('يرجى ملء البيانات الأساسية')));
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            try {
                              final res = await AuthService.register(
                                name: nameCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                password: passCtrl.text.trim(),
                                role: 'driver',
                                carModel: modelCtrl.text.trim().isEmpty
                                    ? 'سيدان'
                                    : modelCtrl.text.trim(),
                                carColor: colorCtrl.text.trim().isEmpty
                                    ? 'أبيض'
                                    : colorCtrl.text.trim(),
                                carYear: yearCtrl.text.trim().isEmpty
                                    ? '2023'
                                    : yearCtrl.text.trim(),
                                plateNumber: plateCtrl.text.trim().isEmpty
                                    ? 'أ ب ج 111'
                                    : plateCtrl.text.trim(),
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                _fetchStats();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res != null
                                        ? 'تم تسجيل السائق بنجاح ✓'
                                        : 'فشل التسجيل'),
                                    backgroundColor: const Color(0xff22C55E),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setModalState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('خطأ: $e')));
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffF97316),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('تسجيل واعتماد السائق فوراً',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalField(
      TextEditingController ctrl, String label, String hint, IconData icon,
      {TextInputType keyboard = TextInputType.text, bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1F2328),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
          hintStyle:
              TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
          prefixIcon: Icon(icon, color: const Color(0xffF97316), size: 18),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
