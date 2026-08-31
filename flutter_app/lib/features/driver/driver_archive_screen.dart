import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';

class DriverArchiveScreen extends StatefulWidget {
  const DriverArchiveScreen({super.key});

  @override
  State<DriverArchiveScreen> createState() => _DriverArchiveScreenState();
}

class _DriverArchiveScreenState extends State<DriverArchiveScreen> {
  bool _isLoading = true;
  List<dynamic> _history = [];
  final String _driverId = 'driver_dummy_001';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('أرشيف الرحلات'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('لا يوجد رحلات في الأرشيف'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final trip = _history[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'العميل: ${trip['userName']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  '${trip['finalFare'] ?? trip['fareEstimate']} ج.م',
                                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('من: ${trip['pickupAddress']}'),
                            Text('إلى: ${trip['dropoffAddress']}'),
                            const SizedBox(height: 8),
                            Text(
                              'الحالة: ${trip['status'] == 'completed' ? 'مكتملة' : 'ملغاة'}',
                              style: TextStyle(
                                color: trip['status'] == 'completed' ? Colors.blue : Colors.red,
                              ),
                            ),
                            if (trip['rating'] != null) ...[
                              const SizedBox(height: 8),
                              const Divider(),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text('تقييم العميل: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ...List.generate(5, (i) => Icon(
                                    i < (trip['rating']['score'] ?? 0) ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20,
                                  )),
                                  const SizedBox(width: 8),
                                  Text('(${trip['rating']['score']}/5)'),
                                ],
                              ),
                              if (trip['rating']['comment'] != null && trip['rating']['comment'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'تعليق: "${trip['rating']['comment']}"',
                                    style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
