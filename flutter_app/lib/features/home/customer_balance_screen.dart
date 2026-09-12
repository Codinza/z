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
        _errorMessage = '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر تحميل بيانات الرصيد، يرجى المحاولة مرة أخرى';
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
          title: const Text('الرصيد',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xffF97316)),
              )
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xff1A1D21),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.wifi_off_rounded,
                                color: Color(0xffF97316), size: 32),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xff94A3B8), fontSize: 15),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _loadBalance,
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              label: const Text('إعادة المحاولة',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xffF97316),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBalance,
                    color: const Color(0xffF97316),
                    backgroundColor: const Color(0xff111315),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),

                          // Balance Card
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xffF97316),
                                    Color(0xffea580c)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xffF97316)
                                        .withOpacity(0.25),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                            Icons.account_balance_wallet,
                                            color: Colors.white,
                                            size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text('رصيدك الحالي',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    '${_balance.toStringAsFixed(2)} ج.م',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildBalanceButton(
                                          icon: Icons.add_rounded,
                                          label: 'شحن',
                                          filled: true,
                                          onTap: () => _showAddFundsDialog(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildBalanceButton(
                                          icon: Icons.send_rounded,
                                          label: 'تحويل',
                                          filled: false,
                                          onTap: () {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'خاصية التحويل قريباً'),
                                                backgroundColor:
                                                    Color(0xffF97316),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Quick Actions
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _buildQuickAction(
                                  icon: Icons.receipt_long_rounded,
                                  label: 'سجل كامل',
                                  onTap: () {},
                                ),
                                const SizedBox(width: 12),
                                _buildQuickAction(
                                  icon: Icons.bar_chart_rounded,
                                  label: 'إحصائيات',
                                  onTap: () {},
                                ),
                                const SizedBox(width: 12),
                                _buildQuickAction(
                                  icon: Icons.card_giftcard_rounded,
                                  label: 'كود خصم',
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Transactions Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('آخر المعاملات',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold)),
                                if (_transactions.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {},
                                    child: const Text(
                                      'عرض الكل',
                                      style: TextStyle(
                                          color: Color(0xffF97316),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Transaction Items
                          if (_transactions.isEmpty)
                            _buildEmptyTransactions()
                          else
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xff111315),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xff2A2D33),
                                      width: 1),
                                ),
                                child: Column(
                                  children: _transactions
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    int index = entry.key;
                                    Map<String, dynamic> transaction =
                                        entry.value;
                                    bool isLast =
                                        index == _transactions.length - 1;

                                    final loc = (transaction['location'] ?? '').toString();
                                    final type = (transaction['type'] ?? '').toString();
                                    final bool isTopUp =
                                        transaction['isTopUp'] == true ||
                                            type == 'wallet_topup' ||
                                            loc == 'معاملة' ||
                                            loc.contains('?') ||
                                            (transaction['order'] == null && transaction['trip'] == null && transaction['orderId'] == null);

                                    return _buildTransactionItem(
                                      icon: isTopUp
                                          ? Icons.arrow_downward_rounded
                                          : type == 'limousine'
                                              ? Icons.directions_car_rounded
                                              : Icons.local_shipping_rounded,
                                      iconColor: isTopUp
                                          ? const Color(0xff22C55E)
                                          : const Color(0xffF97316),
                                      iconBgColor: isTopUp
                                          ? const Color(0xff22C55E).withOpacity(0.12)
                                          : const Color(0xffF97316).withOpacity(0.12),
                                      title: isTopUp
                                          ? 'شحن رصيد'
                                          : (transaction['title'] ??
                                              (type == 'limousine'
                                                  ? 'خدمة ليموزين'
                                                  : 'خدمة شحن')),
                                      subtitle: isTopUp
                                          ? (transaction['paymentMethod'] == 'card' ? 'بطاقة بنكية' : 'شحن محفظة')
                                          : loc,
                                      date: _formatDate(transaction['date']),
                                      amount: isTopUp
                                          ? '+${transaction['amount']?.toString() ?? '0'} ج.م'
                                          : '-${transaction['amount']?.toString() ?? '0'} ج.م',
                                      amountColor: isTopUp
                                          ? const Color(0xff22C55E)
                                          : const Color(0xffEF4444),
                                      status: transaction['status'] ?? '',
                                      isLast: isLast,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          const SizedBox(height: 110),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildBalanceButton({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: filled ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: filled
                ? null
                : Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color: filled ? const Color(0xffF97316) : Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled ? const Color(0xffF97316) : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xff111315),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xff2A2D33), width: 1),
            ),
            child: Column(
              children: [
                Icon(icon, color: const Color(0xffF97316), size: 24),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        color: Color(0xff94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: const Color(0xff111315),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xff2A2D33), width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xff1A1D21),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: Color(0xff4B5563), size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد معاملات حتى الآن',
              style: TextStyle(color: Color(0xff64748B), fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'ابدأ بشحن رصيدك أو اطلب خدمة',
              style: TextStyle(color: Color(0xff4B5563), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFundsDialog() {
    final TextEditingController controller = TextEditingController();
    final List<int> presetAmounts = [50, 100, 200, 500];
    int? selectedPreset;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (builderContext, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xff111315),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xff4B5563),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xffF97316).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance_wallet,
                              color: Color(0xffF97316), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text('شحن الرصيد',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Preset amounts
                    const Text('اختر مبلغ سريع',
                        style: TextStyle(
                            color: Color(0xff94A3B8), fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                      children: presetAmounts.map((amount) {
                        final isSelected = selectedPreset == amount;
                        return Expanded(
                          child: Padding(
                            padding:
                                EdgeInsets.only(left: amount == presetAmounts.last ? 0 : 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setSheetState(() {
                                    selectedPreset = amount;
                                    controller.text = amount.toString();
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xffF97316)
                                        : const Color(0xff1A1D21),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xffF97316)
                                          : const Color(0xff2A2D33),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$amount ج.م',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xff94A3B8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Custom amount input
                    const Text('أو أدخل مبلغ مخصص',
                        style: TextStyle(
                            color: Color(0xff94A3B8), fontSize: 13)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      onChanged: (val) {
                        setSheetState(() {
                          final parsed = int.tryParse(val);
                          selectedPreset =
                              presetAmounts.contains(parsed) ? parsed : null;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'المبلغ (ج.م)',
                        hintStyle: const TextStyle(
                            color: Color(0xff4B5563), fontSize: 16),
                        filled: true,
                        fillColor: const Color(0xff1A1D21),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xff2A2D33)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xffF97316)),
                        ),
                        suffixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Text('ج.م',
                              style: TextStyle(
                                  color: Color(0xff64748B), fontSize: 14)),
                        ),
                        suffixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount =
                              double.tryParse(controller.text) ?? 0;
                          if (amount > 0) {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.of(sheetContext).pop();
                            setState(() => _isLoading = true);
                            try {
                              final result =
                                  await ApiService.addFunds(amount);
                              if (result['success'] == true) {
                                _loadBalance();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'تم شحن $amount ج.م بنجاح ✓'),
                                    backgroundColor:
                                        const Color(0xff22C55E),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                );
                              } else {
                                _loadBalance();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'حدث خطأ أثناء شحن الرصيد'),
                                    backgroundColor:
                                        const Color(0xffEF4444),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            } catch (e) {
                              _loadBalance();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('حدث خطأ: $e'),
                                  backgroundColor:
                                      const Color(0xffEF4444),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    const Text('يرجى إدخال مبلغ صحيح'),
                                backgroundColor: const Color(0xffEF4444),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffF97316),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('تأكيد الشحن',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String date,
    required String amount,
    required Color amountColor,
    required String status,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Icon(icon, color: iconColor, size: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle.isNotEmpty ? subtitle : date,
                      style: const TextStyle(
                          color: Color(0xff64748B), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(amount,
                      style: TextStyle(
                          color: amountColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(date,
                      style: const TextStyle(
                          color: Color(0xff4B5563), fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Color(0xff1A1D21), height: 1),
          ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final DateTime dateTime =
          date is DateTime ? date : DateTime.parse(date.toString());
      final now = DateTime.now();
      final diff = now.difference(dateTime);

      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
      if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';

      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
