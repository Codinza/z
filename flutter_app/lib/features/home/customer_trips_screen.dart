import 'package:flutter/material.dart';
import '../auth/api_service.dart';

class CustomerTripsScreen extends StatefulWidget {
  const CustomerTripsScreen({super.key});

  @override
  State<CustomerTripsScreen> createState() => _CustomerTripsScreenState();
}

class _CustomerTripsScreenState extends State<CustomerTripsScreen> with SingleTickerProviderStateMixin {
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
        _pastTrips = trips.cast<Map<String, dynamic>>();
        _isLoadingPastTrips = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoadingPastTrips = false;
      });
    }
  }

  Future<void> _loadRecurringTrips() async {
    try {
      if (mounted) setState(() => _isLoadingRecurringTrips = true);
      // Mock recurring trips for now (implement actual API later)
      if (!mounted) return;
      setState(() {
        _recurringTrips = [
          {
            'name': 'الذهاب للعمل',
            'from': 'شارع النيل، القاهرة',
            'to': 'مدينة نصر، الدقي',
            'frequency': 'يومياً - الأحد إلى الخميس',
            'time': '08:00 ص',
            'lastTrip': 'آخر استخدام: اليوم',
          },
          {
            'name': 'العودة من العمل',
            'from': 'مدينة نصر، الدقي',
            'to': 'شارع النيل، القاهرة',
            'frequency': 'يومياً - الأحد إلى الخميس',
            'time': '06:00 م',
            'lastTrip': 'آخر استخدام: اليوم',
          },
        ];
        _isLoadingRecurringTrips = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingRecurringTrips = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0a0a0a),
        appBar: AppBar(
          backgroundColor: const Color(0xff111315),
          elevation: 0,
          title: const Text('رحلاتي', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xffF97316),
            indicatorWeight: 3,
            labelColor: const Color(0xffF97316),
            unselectedLabelColor: const Color(0xff999999),
            tabs: const [
              Tab(text: 'الرحلات السابقة'),
              Tab(text: 'الرحلات المتكررة'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Past Trips Tab
            _isLoadingPastTrips
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xffF97316)),
                  )
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xffF97316), size: 48),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadPastTrips,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF97316)),
                              child: const Text('جرب مرة أخرى', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : _pastTrips.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد رحلات سابقة',
                              style: TextStyle(color: Color(0xff999999), fontSize: 14),
                            ),
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
        padding: const EdgeInsets.all(16),
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
                status: trip['status'] ?? 'pending',
                statusColor: trip['statusColor'] == 'success' ? Colors.green : Colors.red,
                onTap: () {},
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRecurringTripsTab() {
    return _isLoadingRecurringTrips
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xffF97316)),
          )
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _recurringTrips.asMap().entries.map((entry) {
                  Map<String, dynamic> trip = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildRecurringTripCard(
                      name: trip['name'] ?? 'Unknown',
                      from: trip['from'] ?? 'Unknown',
                      to: trip['to'] ?? 'Unknown',
                      frequency: trip['frequency'] ?? '',
                      time: trip['time'] ?? '',
                      lastTrip: trip['lastTrip'] ?? '',
                      onBook: () {},
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xff111315),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xff2a2a2a), width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tripId, style: const TextStyle(color: Color(0xffF97316), fontSize: 14, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xffF97316), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(from, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.flag_outlined, color: Color(0xffF97316), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(to, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: const Color(0xff2a2a2a), height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date, style: const TextStyle(color: Color(0xff999999), fontSize: 12)),
                Text('$cost ج.م', style: const TextStyle(color: Color(0xffF97316), fontSize: 14, fontWeight: FontWeight.bold)),
              ],
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff111315),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff2a2a2a), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffF97316).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('متكررة', style: TextStyle(color: Color(0xffF97316), fontSize: 11, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xffF97316), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(from, style: const TextStyle(color: Color(0xffcccccc), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: Color(0xffF97316), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(to, style: const TextStyle(color: Color(0xffcccccc), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: const Color(0xff2a2a2a), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(frequency, style: const TextStyle(color: Color(0xff999999), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('الموعد: $time', style: const TextStyle(color: Color(0xff999999), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(lastTrip, style: const TextStyle(color: Color(0xff666666), fontSize: 11)),
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
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('اطلب الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    final DateTime dateTime = date is DateTime ? date : DateTime.parse(date.toString());
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
