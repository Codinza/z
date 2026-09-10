import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/auth_service.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  bool _isLoading = true;
  String? _driverId;
  double _walletBalance = 0.0;
  double _todayEarnings = 0.0;
  int _todayTrips = 0;

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  Future<void> _fetchWallet() async {
    try {
      _driverId = await AuthService.getUserId();
      if (_driverId == null || _driverId!.isEmpty) {
        throw Exception('Driver session not found');
      }
      final response =
          await ApiClient().dio.get('/api/drivers/$_driverId/wallet');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _walletBalance = (response.data['walletBalance'] as num).toDouble();
            _todayEarnings =
                (response.data['todayEarnings'] as num?)?.toDouble() ?? 0;
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
    if (_driverId == null || _driverId!.isEmpty) {
      _driverId = await AuthService.getUserId();
    }
    if (!mounted || _driverId == null || _driverId!.isEmpty) {
      return;
    }
    final amountController = TextEditingController(text: '100');
    String paymentMethod = 'instapay';
    XFile? receipt;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('طلب شحن المحفظة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('حوّل المبلغ ثم ارفع صورة الإيصال للمراجعة.'),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ بالجنيه'),
              ),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(labelText: 'طريقة التحويل'),
                items: const [
                  DropdownMenuItem(value: 'instapay', child: Text('InstaPay')),
                  DropdownMenuItem(
                      value: 'vodafone_cash', child: Text('Vodafone Cash')),
                ],
                onChanged: (value) =>
                    setDialogState(() => paymentMethod = value ?? 'instapay'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final selected = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (selected != null) {
                    setDialogState(() => receipt = selected);
                  }
                },
                icon: const Icon(Icons.receipt_long),
                label: Text(receipt == null
                    ? 'اختيار صورة الإيصال'
                    : 'تم اختيار الإيصال'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: receipt == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('إرسال للأدمن'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || receipt == null) {
      amountController.dispose();
      return;
    }

    try {
      final receiptBytes = await receipt!.readAsBytes();
      final receiptImage =
          'data:image/jpeg;base64,${base64Encode(receiptBytes)}';
      final response = await ApiClient().dio.post(
        '/api/drivers/$_driverId/wallet/top-up-request',
        data: {
          'amount': double.tryParse(amountController.text.trim()),
          'paymentMethod': paymentMethod,
          'receiptImage': receiptImage,
        },
      );
      if (mounted && response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال الإيصال للأدمن للمراجعة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الشحن')),
        );
      }
    } finally {
      amountController.dispose();
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
                    color: _walletBalance < 0
                        ? Colors.red.shade50
                        : const Color(0xfffff4df),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Text(
                            'رصيد المحفظة',
                            style: TextStyle(
                                fontSize: 20, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${_walletBalance.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: _walletBalance < 0
                                  ? Colors.red
                                  : const Color(0xffF97316),
                            ),
                          ),
                          if (_walletBalance < -50)
                            const Padding(
                              padding: EdgeInsets.only(top: 16.0),
                              child: Text(
                                'الرصيد أقل من الحد المسموح. يرجى الشحن لتلقي الرحلات.',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold),
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
                          color: const Color(0xffF97316),
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
                    label: const Text('طلب شحن بإيصال'),
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
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
