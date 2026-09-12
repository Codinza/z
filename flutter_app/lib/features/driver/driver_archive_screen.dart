import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_service.dart';

class DriverArchiveScreen extends StatefulWidget {
  const DriverArchiveScreen({super.key});

  @override
  State<DriverArchiveScreen> createState() => _DriverArchiveScreenState();
}

class _DriverArchiveScreenState extends State<DriverArchiveScreen> {
  bool _isLoading = true;
  List<dynamic> _history = [];
  String _driverId = 'driver_dummy_001';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final savedId = await AuthService.getUserId();
      if (savedId != null && savedId.isNotEmpty) {
        _driverId = savedId;
      }
      final response = await ApiClient().dio.get('/api/drivers/$_driverId/history');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _history = response.data['history'] ?? [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
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
          backgroundColor: const Color(0xff121620),
          title: const Text(
            'أرشيف الرحلات',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xffF97316)))
            : _history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xff161B26),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xff1E293B)),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            size: 40,
                            color: Color(0xff94A3B8),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'لا توجد رحلات سابقة في الأرشيف',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'الرحلات المكتملة ستظهر هنا مع تفاصيل التقييم والأجرة',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xff94A3B8),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchHistory,
                    color: const Color(0xffF97316),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final trip = _history[index];
                        final isCompleted = trip['status'] == 'completed';
                        final fare = trip['finalFare'] ?? trip['fareEstimate'] ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xff121620),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xff1E293B)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: Customer + Fare
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xff1E293B),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: const Color(0xffF97316)
                                                    .withOpacity(0.4)),
                                          ),
                                          child: const Icon(Icons.person_rounded,
                                              color: Color(0xffF97316), size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          trip['userName']?.toString() ??
                                              'عميل زوون',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF97316)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xffF97316)
                                                .withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        '$fare ج.م',
                                        style: const TextStyle(
                                          color: Color(0xffF97316),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Route Details
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff161B26),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: const Color(0xff1E293B)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.circle,
                                              size: 10,
                                              color: Color(0xff10B981)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'من: ${trip['pickupAddress'] ?? 'غير محدد'}',
                                              style: const TextStyle(
                                                color: Color(0xffCBD5E1),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              size: 12,
                                              color: Color(0xffF97316)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'إلى: ${trip['dropoffAddress'] ?? 'غير محدد'}',
                                              style: const TextStyle(
                                                color: Color(0xffCBD5E1),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Status Pill
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isCompleted
                                            ? const Color(0xff064E3B)
                                                .withOpacity(0.3)
                                            : const Color(0xff7F1D1D)
                                                .withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isCompleted
                                              ? const Color(0xff10B981)
                                              : const Color(0xffEF4444),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isCompleted
                                                ? Icons.check_circle_rounded
                                                : Icons.cancel_rounded,
                                            size: 14,
                                            color: isCompleted
                                                ? const Color(0xff34D399)
                                                : const Color(0xffF87171),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isCompleted
                                                ? 'مكتملة بنجاح'
                                                : 'ملغاة',
                                            style: TextStyle(
                                              color: isCompleted
                                                  ? const Color(0xff34D399)
                                                  : const Color(0xffF87171),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Customer Rating
                                if (trip['rating'] != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff161B26),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xff1E293B)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'تقييم العميل: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: Color(0xff94A3B8),
                                              ),
                                            ),
                                            ...List.generate(
                                              5,
                                              (i) => Icon(
                                                i < (trip['rating']['score'] ?? 0)
                                                    ? Icons.star_rounded
                                                    : Icons.star_border_rounded,
                                                color: const Color(0xffFBBF24),
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '(${trip['rating']['score']}/5)',
                                              style: const TextStyle(
                                                color: Color(0xffFBBF24),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (trip['rating']['comment'] != null &&
                                            trip['rating']['comment']
                                                .toString()
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            '💬 "${trip['rating']['comment']}"',
                                            style: const TextStyle(
                                              fontStyle: FontStyle.italic,
                                              color: Color(0xffCBD5E1),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
