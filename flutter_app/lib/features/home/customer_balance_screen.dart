import 'package:flutter/material.dart';
import '../auth/api_service.dart';

class CustomerBalanceScreen extends StatefulWidget {
  const CustomerBalanceScreen({super.key});

  @override
  State<CustomerBalanceScreen> createState() => _CustomerBalanceScreenState();
}

class _CustomerBalanceScreenState extends State<CustomerBalanceScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      final data = await ApiService.getCustomerBalance();
      if (!mounted) return;
      setState(() {
        _balance = (data['balance'] ?? 0.0).toDouble();
        _transactions = List<Map<String, dynamic>>.from(data['transactions'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
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
          title: const Text('الرصيد', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: _isLoading
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
                          onPressed: _loadBalance,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF97316)),
                          child: const Text('جرب مرة أخرى', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Balance Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xffF97316), Color(0xffea580c)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('رصيدك الحالي', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 12),
                                Text('${_balance.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showAddFundsDialog(),
                                        icon: const Icon(Icons.add),
                                        label: const Text('شحن'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(0xffF97316),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(Icons.send),
                                        label: const Text('تحويل'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: const BorderSide(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Transactions Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('آخر المعاملات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(
                                'عرض الكل',
                                style: TextStyle(color: const Color(0xffF97316), fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Transaction Items
                        if (_transactions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: const Text(
                              'لا توجد معاملات حتى الآن',
                              style: TextStyle(color: Color(0xff999999), fontSize: 14),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: _transactions.asMap().entries.map((entry) {
                                int index = entry.key;
                                Map<String, dynamic> transaction = entry.value;
                                bool isLast = index == _transactions.length - 1;

                                return _buildTransactionItem(
                                  icon: transaction['status'] == 'completed' ? Icons.check_circle : Icons.pending_actions,
                                  iconColor: transaction['status'] == 'completed' ? Colors.green : Colors.orange,
                                  title: transaction['type'] == 'limousine' ? 'خدمة ليموزين' : 'خدمة شحن',
                                  date: _formatDate(transaction['date']),
                                  amount: '-${transaction['amount']?.toString() ?? '0'} ج.م',
                                  amountColor: Colors.red,
                                  isLast: isLast,
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  void _showAddFundsDialog() {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff111315),
        title: const Text('شحن الرصيد', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'المبلغ (ج.م)',
            hintStyle: TextStyle(color: Color(0xff666666)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xffF97316))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xffF97316))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount > 0) {
                try {
                  await ApiService.addFunds(amount);
                  Navigator.pop(context);
                  _loadBalance();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم شحن الرصيد بنجاح')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('حدث خطأ: $e')),
                  );
                }
              }
            },
            child: const Text('تأكيد', style: TextStyle(color: Color(0xffF97316))),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String date,
    required String amount,
    required Color amountColor,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xff1a1a1a),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Icon(icon, color: iconColor, size: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(date, style: const TextStyle(color: Color(0xff999999), fontSize: 12)),
                ],
              ),
            ),
            Text(amount, style: TextStyle(color: amountColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: const Color(0xff2a2a2a), height: 1),
          ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    final DateTime dateTime = date is DateTime ? date : DateTime.parse(date.toString());
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}
