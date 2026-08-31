import 'package:flutter/material.dart';
import 'package:rideflow_app/features/payment/payment_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'paymob_checkout_screen.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String tripId;
  final double amount;
  final String method;

  const PaymentConfirmationScreen({
    super.key,
    required this.tripId,
    required this.amount,
    required this.method,
  });

  @override
  PaymentConfirmationScreenState createState() => PaymentConfirmationScreenState();
}

class PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  bool _isLoading = true;
  bool _isSuccess = false;
  bool _isPending = false;
  Map<String, dynamic>? _payment;

  @override
  void initState() {
    super.initState();
    _processPayment();
  }

  Future<void> _processPayment() async {
    Map<String, dynamic>? result;
    if (widget.method == 'cash') {
      result = await PaymentService.createPayment(
        widget.tripId,
        'user_dummy_123',
        widget.amount,
        widget.method,
      );
    } else {
      result = await PaymentService.createPaymobCheckout(
          widget.tripId, widget.amount, widget.method);
      final checkoutUrl = result?['checkoutUrl']?.toString();
      if (checkoutUrl != null) {
        if (kIsWeb) {
          final launched = await launchUrl(
            Uri.parse(checkoutUrl),
            mode: LaunchMode.externalApplication,
          );
          if (!mounted) return;
          if (launched) _isPending = true;
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (context) =>
                    PaymobCheckoutScreen(checkoutUrl: checkoutUrl),
              ),
            ).then((paid) {
              if (!mounted) return;
              setState(() {
                _isPending = paid != true;
              });
            });
          });
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isSuccess = result != null;
      _isPending = _isPending || (result != null && widget.method != 'cash');
      _payment = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد الدفع'), centerTitle: true, automaticallyImplyLeading: false),
      body: Center(
        child: _isLoading 
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('جاري معالجة الدفع...', style: TextStyle(fontSize: 16)),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isPending
                    ? Icons.open_in_new
                    : _isSuccess
                      ? Icons.check_circle
                      : Icons.error,
                  color: _isPending
                    ? Colors.orange
                    : _isSuccess
                      ? Colors.green
                      : Colors.red,
                  size: 100,
                ),
                const SizedBox(height: 20),
                Text(
                    _isPending
                      ? 'تم فتح صفحة الدفع'
                      : _isSuccess
                        ? 'تم الدفع بنجاح'
                        : 'حدث خطأ أثناء الدفع',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_isSuccess || _isPending)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _isPending ? Colors.orange.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Column(
                      children: [
                        Text('المبلغ: ${widget.amount.toStringAsFixed(2)} ج.م',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_isPending
                          ? 'أكمل الدفع في صفحة Paymob المفتوحة'
                          : 'طريقة الدفع: ${_methodLabel(widget.method)}'),
                        const SizedBox(height: 5),
                        Text('رقم العملية: ${_payment?['id'] ?? 'قيد الإنشاء'}',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        if (_payment?['createdAt'] != null) ...[
                          const SizedBox(height: 5),
                          Text('التاريخ: ${_payment!['createdAt']}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    // Navigate back to home
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  child: const Text('العودة للرئيسية', style: TextStyle(color: Colors.white, fontSize: 16)),
                )
              ],
            ),
      ),
    );
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'card':
        return 'بطاقة بنكية';
      case 'wallet':
        return 'محفظة إلكترونية';
      default:
        return 'دفع نقدي';
    }
  }
}
