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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B0E14),
        appBar: AppBar(
          backgroundColor: const Color(0xff121620),
          title: const Text(
            'الأرباح والمحفظة',
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
            : RefreshIndicator(
                onRefresh: _fetchWallet,
                color: const Color(0xffF97316),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  children: [
                    // Main Balance Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff1A202C), Color(0xff121620)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _walletBalance < 0
                              ? const Color(0xffEF4444).withOpacity(0.5)
                              : const Color(0xffF97316).withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: (_walletBalance < 0
                                    ? const Color(0xffEF4444)
                                    : const Color(0xffF97316))
                                .withOpacity(0.08),
                            blurRadius: 16,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 28),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xffF97316).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Color(0xffF97316),
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'رصيد المحفظة المتاح',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xff94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _walletBalance.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: _walletBalance < 0
                                        ? const Color(0xffEF4444)
                                        : const Color(0xffF97316),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'ج.م',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _walletBalance < 0
                                        ? const Color(0xffEF4444)
                                        : const Color(0xffF97316),
                                  ),
                                ),
                              ],
                            ),
                            if (_walletBalance < -50)
                              Container(
                                margin: const EdgeInsets.only(top: 18),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xff7F1D1D).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xffEF4444).withOpacity(0.4)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        size: 16, color: Color(0xffEF4444)),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'الرصيد أقل من الحد المسموح. يرجى الشحن لتلقي الرحلات.',
                                        style: TextStyle(
                                          color: Color(0xffFCA5A5),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            label: 'أرباح اليوم',
                            value: '${_todayEarnings.toStringAsFixed(2)} ج.م',
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xffF97316),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _SummaryCard(
                            label: 'رحلات اليوم',
                            value: '$_todayTrips رحلات',
                            icon: Icons.route_rounded,
                            color: const Color(0xff38BDF8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Recharge Action Button
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xffF97316), Color(0xffEA580C)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xffF97316).withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _recharge,
                        icon: const Icon(Icons.add_card_rounded,
                            color: Colors.white, size: 20),
                        label: const Text(
                          'طلب شحن المحفظة بإيصال',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xff94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
