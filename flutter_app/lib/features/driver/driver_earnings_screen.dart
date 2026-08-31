import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  bool _isLoading = true;
  double _walletBalance = 0.0;
  double _todayEarnings = 0.0;
  int _todayTrips = 0;
  final String _driverId = 'driver_dummy_001';

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  Future<void> _fetchWallet() async {
    try {
      final response = await ApiClient().dio.get('/api/drivers/$_driverId/wallet');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _walletBalance = (response.data['walletBalance'] as num).toDouble();
            _todayEarnings = (response.data['todayEarnings'] as num?)?.toDouble() ?? 0;
            _todayTrips = (response.data['todayTrips'] as num?)?.toInt() ?? 0;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch wallet: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _recharge() async {
    try {
      final response = await ApiClient().dio.post(
        '/api/drivers/$_driverId/wallet/checkout',
        data: {'amount': 100},
      );
      final checkoutUrl = response.data['checkoutUrl']?.toString();
      if (response.statusCode == 201 && checkoutUrl != null) {
        final opened = await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(opened
                  ? 'تم فتح صفحة الدفع. سيتم تحديث الرصيد بعد التأكيد.'
                  : 'تعذر فتح صفحة الدفع'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الشحن')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأرباح والمحفظة'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    color: _walletBalance < 0 ? Colors.red.shade50 : Colors.green.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Text(
                            'رصيد المحفظة',
                            style: TextStyle(fontSize: 20, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${_walletBalance.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: _walletBalance < 0 ? Colors.red : Colors.green,
                            ),
                          ),
                          if (_walletBalance < -50)
                            const Padding(
                              padding: EdgeInsets.only(top: 16.0),
                              child: Text(
                                'الرصيد أقل من الحد المسموح. يرجى الشحن لتلقي الرحلات.',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'أرباح اليوم',
                          value: '${_todayEarnings.toStringAsFixed(2)} ج.م',
                          icon: Icons.trending_up,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: 'رحلات اليوم',
                          value: '$_todayTrips',
                          icon: Icons.route,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _recharge,
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('شحن المحفظة (100 ج.م)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
