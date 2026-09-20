import 'package:flutter/material.dart';
import '../auth/api_service.dart';
import 'order_tracking_screen.dart';
import 'home_screen.dart';
import 'customer_main_screen.dart';
import '../../core/widgets/animations/zoon_animations.dart';

class CustomerTripsScreen extends StatefulWidget {
  const CustomerTripsScreen({super.key});

  @override
  State<CustomerTripsScreen> createState() => _CustomerTripsScreenState();
}

class _CustomerTripsScreenState extends State<CustomerTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingPastTrips = true;
  bool _isLoadingRecurringTrips = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _pastTrips = [];
  List<Map<String, dynamic>> _recurringTrips = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPastTrips();
    _loadRecurringTrips();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPastTrips() async {
    try {
      if (mounted) setState(() => _isLoadingPastTrips = true);
      final trips = await ApiService.getCustomerOrders();
      if (!mounted) return;
      setState(() {
        _pastTrips = List<Map<String, dynamic>>.from(trips);
        _errorMessage = '';
        _isLoadingPastTrips = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر تحميل الرحلات حالياً، يرجى المحاولة مرة أخرى';
        _isLoadingPastTrips = false;
      });
    }
  }

  Future<void> _loadRecurringTrips() async {
    try {
      if (mounted) setState(() => _isLoadingRecurringTrips = true);
      final trips = await ApiService.getRecurringTrips();
      if (!mounted) return;
      setState(() {
        _recurringTrips = trips;
        _isLoadingRecurringTrips = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingRecurringTrips = false;
      });
    }
  }

  String _statusLabel(String? status) {
    switch (status?.toUpperCase()) {
      case 'NEW':
      case 'PENDING':
        return 'جديد';
      case 'PRICE_SENT':
        return 'عرض سعر';
      case 'CUSTOMER_APPROVED':
        return 'تمت الموافقة';
      case 'COMPANY_ACCEPTED':
      case 'ACCEPTED':
        return 'تم القبول';
      case 'CONFIRMED':
      case 'DRIVER_ARRIVING':
        return 'قيد التنفيذ';
      case 'COMPLETED':
      case 'مكتملة':
        return 'مكتملة';
      case 'CANCELLED':
      case 'CANCELED':
      case 'ملغاة':
        return 'ملغاة';
      default:
        return status ?? 'قيد المراجعة';
    }
  }

  void _reorderTrip(Map<String, dynamic> trip) {
    final serviceType = trip['serviceType']?.toString().toUpperCase();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          initialService: serviceType == 'SHIPPING' ? 'shipping' : 'limousine',
          initialPickupAddress: trip['from']?.toString(),
          initialDropoffAddress: trip['to']?.toString(),
        ),
      ),
    );
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
          title: const Text(
            'رحلاتي',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xff161B26),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xff252E3E)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xffF97316).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xffF97316).withOpacity(0.45),
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: const Color(0xffF97316),
                unselectedLabelColor: const Color(0xff94A3B8),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                ),
                tabs: const [
                  Tab(text: 'السابقة'),
                  Tab(text: 'المتكررة'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Past Trips Tab
            _isLoadingPastTrips
                ? const Center(
                    child: ZoonRiveLoading(
                      size: 80,
                      message: 'جاري تحميل رحلاتك...',
                    ),
                  )
                : _errorMessage.isNotEmpty
                    ? ZoonEmptyState(
                        title: 'تعذر التحميل',
                        subtitle: _errorMessage,
                        icon: Icons.wifi_off_rounded,
                        actionLabel: 'إعادة المحاولة',
                        onAction: _loadPastTrips,
                      )
                    : _pastTrips.isEmpty
                        ? ZoonEmptyState(
                            title: 'لا توجد رحلات سابقة',
                            subtitle:
                                'ابدأ رحلتك الأولى مع زوون واطلب كابتن الآن بسهولة وسرعة.',
                            icon: Icons.directions_car_filled_rounded,
                            actionLabel: 'طلب رحلة الآن',
                            onAction: () {
                              CustomerMainScreen.switchTab(context, 0);
                            },
                          )
                        : _buildPastTripsTab(),
            // Recurring Trips Tab
            _buildRecurringTripsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPastTripsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          children: _pastTrips.asMap().entries.map((entry) {
            Map<String, dynamic> trip = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTripCard(
                tripId: trip['tripId'] ?? '#0000',
                from: trip['from'] ?? 'Unknown',
                to: trip['to'] ?? 'Unknown',
                date: _formatDate(trip['date']),
                cost: trip['cost']?.toString() ?? '0',
                status: _statusLabel(trip['status']?.toString()),
                statusColor: trip['statusColor'] == 'success'
                    ? Colors.green
                    : Colors.red,
                onReorder: () => _reorderTrip(trip),
                onTap: () {
                  final id = trip['id']?.toString();
                  if (id != null && id.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(
                          orderId: id,
                          isTrip: trip['serviceType'] == null ||
                              trip['serviceType'] == 'TRIP' ||
                              trip['type'] == 'trip',
                        ),
                      ),
                    ).then((_) {
                      if (mounted) _loadPastTrips();
                    });
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _bookRecurringTrip(Map<String, dynamic> trip) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xff111315),
        content: Text(
          'تم اختيار وجهة: ${trip['to'] ?? ''}\nتوجه إلى الرئيسية لتأكيد الطلب الآن',
          style: const TextStyle(color: Colors.white, fontSize: 13.5),
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildRecurringTripsTab() {
    if (_isLoadingRecurringTrips) {
      return const Center(
        child: ZoonRiveLoading(
          size: 80,
          message: 'جاري تحميل الرحلات المتكررة...',
        ),
      );
    }

    if (_recurringTrips.isEmpty) {
      return const ZoonEmptyState(
        title: 'لا توجد رحلات متكررة بعد',
        subtitle:
            'عندما تطلب مشاويرك ووجهاتك أكثر من مرة، ستظهر هنا تلقائياً لتمكنك من حجزها بضغطة زر واحدة.',
        icon: Icons.repeat_rounded,
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          children: _recurringTrips.asMap().entries.map((entry) {
            Map<String, dynamic> trip = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRecurringTripCard(
                name: trip['name'] ?? 'مشوار متكرر',
                from: trip['from'] ?? 'غير محدد',
                to: trip['to'] ?? 'غير محدد',
                frequency: trip['frequency'] ?? 'رحلة متكررة',
                time: trip['time'] ?? '',
                lastTrip: trip['lastTrip'] ?? '',
                onBook: () => _bookRecurringTrip(trip),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTripCard({
    required String tripId,
    required String from,
    required String to,
    required String date,
    required String cost,
    required String status,
    required Color statusColor,
    required VoidCallback onTap,
    required VoidCallback onReorder,
  }) {
    return PressableScale(
      onTap: onTap,
      scaleFactor: 0.97,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xff121620),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xff252E3E), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tripId,
                    style: const TextStyle(
                        color: Color(0xffF97316),
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on,
                    color: Color(0xffF97316), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(from,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.flag_outlined,
                    color: Color(0xffF97316), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(to,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xff1E2633), height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date,
                    style: const TextStyle(
                        color: Color(0xff94A3B8), fontSize: 12)),
                Text('$cost ج.م',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onReorder,
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: const Text('إعادة الطلب'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xffF97316),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringTripCard({
    required String name,
    required String from,
    required String to,
    required String frequency,
    required String time,
    required String lastTrip,
    required VoidCallback onBook,
  }) {
    return PressableScale(
      scaleFactor: 0.97,
      child: Container(
      decoration: BoxDecoration(
        color: const Color(0xff121620),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff252E3E), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffF97316).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('متكررة',
                    style: TextStyle(
                        color: Color(0xffF97316),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xffF97316), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(from,
                    style:
                        const TextStyle(color: Color(0xffcccccc), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.flag_outlined,
                  color: Color(0xffF97316), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(to,
                    style:
                        const TextStyle(color: Color(0xffcccccc), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xff2a2a2a), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(frequency,
                      style: const TextStyle(
                          color: Color(0xff999999), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('الموعد: $time',
                      style: const TextStyle(
                          color: Color(0xff999999), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(lastTrip,
                      style: const TextStyle(
                          color: Color(0xff666666), fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffF97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('اطلب الآن',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    final DateTime dateTime =
        date is DateTime ? date : DateTime.parse(date.toString());
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
