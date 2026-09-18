import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/widgets/animations/zoon_animations.dart';
import '../admin_service.dart';

class FinancesTab extends StatefulWidget {
  final VoidCallback? onDataChanged;
  const FinancesTab({super.key, this.onDataChanged});

  @override
  State<FinancesTab> createState() => _FinancesTabState();
}

class _FinancesTabState extends State<FinancesTab> {
  bool _isLoading = true;
  Map<String, dynamic> _financesSummary = {};
  List<Map<String, dynamic>> _topUpRequests = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      AdminService.getFinancesSummary(),
      AdminService.getDriverTopUps(),
    ]);

    if (mounted) {
      setState(() {
        _financesSummary = results[0] as Map<String, dynamic>;
        _topUpRequests = results[1] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    }
  }

  void _showZoomedImage(String base64Image) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(base64Image),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xffF97316)));
    }

    final totalDriversBalance =
        (_financesSummary['totalDriversBalance'] as num?)?.toDouble() ?? 0.0;
    final pendingTopUpsCount = _financesSummary['pendingTopUpsCount'] ?? 0;
    final approvedTopUpsTotal =
        (_financesSummary['approvedTopUpsTotal'] as num?)?.toDouble() ?? 0.0;
    final totalTripsVolume =
        (_financesSummary['totalTripsVolume'] as num?)?.toDouble() ?? 0.0;

    return RefreshIndicator(
      color: const Color(0xffF97316),
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header title
          const Row(
            children: [
              Icon(Icons.account_balance, color: Color(0xffF97316), size: 24),
              SizedBox(width: 8),
              Text(
                'المالية والمحافظ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // KPI Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _buildFinanceCard(
                'أرصدة السائقين',
                '${totalDriversBalance.toStringAsFixed(1)} ج.م',
                Icons.account_balance_wallet,
                const Color(0xff10B981),
              ),
              _buildFinanceCard(
                'طلبات شحن معلقة',
                '$pendingTopUpsCount طلب',
                Icons.pending_actions,
                const Color(0xffF59E0B),
              ),
              _buildFinanceCard(
                'إجمالي شحن معتمد',
                '${approvedTopUpsTotal.toStringAsFixed(1)} ج.م',
                Icons.check_circle,
                const Color(0xff3B82F6),
              ),
              _buildFinanceCard(
                'حجم المشاوير المنفذة',
                '${totalTripsVolume.toStringAsFixed(1)} ج.م',
                Icons.local_taxi,
                const Color(0xff8B5CF6),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Top-Up Requests Queue Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long,
                      color: Color(0xffF97316), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'طلبات شحن المحافظ المعلقة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_topUpRequests.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xffF97316),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_topUpRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              TextButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
                label: const Text('تحديث',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Requests list or empty state
          if (_topUpRequests.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xff16191E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 48, color: Colors.green.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'رائع! لا توجد طلبات شحن معلقة حالياً',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أي طلب شحن جديد من كابتن سيظهر هنا مباشرة لمراجعته.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._topUpRequests.map((req) => _buildTopUpRequestCard(req)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFinanceCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff16191E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              AnimatedCounterText(
                value: double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
                suffix: value.contains('ج.م') ? 'ج.م' : null,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTopUpRequestCard(Map<String, dynamic> req) {
    final driver = req['driver']?['user'] as Map<String, dynamic>? ?? {};
    final amount = (req['amount'] as num?)?.toDouble() ?? 0.0;
    final method = req['paymentMethod']?.toString() ?? 'vodafone';
    final image = req['receiptImage']?.toString() ?? '';
    final imageData = image.contains(',') ? image.split(',').last : image;
    final isVodafone = method.toLowerCase().contains('vodafone');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xff1A1D24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Driver info and amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xffF97316).withOpacity(0.15),
                    child: const Icon(Icons.person,
                        color: Color(0xffF97316), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver['name'] ?? 'سائق',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        driver['phone'] ?? '',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xff22C55E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xff22C55E).withOpacity(0.3)),
                ),
                child: Text(
                  '+${amount.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                    color: Color(0xff22C55E),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Method tag
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isVodafone
                      ? Colors.red.withOpacity(0.15)
                      : Colors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isVodafone
                        ? Colors.red.withOpacity(0.4)
                        : Colors.purple.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  isVodafone ? 'فودافون كاش (Vodafone Cash)' : 'إنستاباي (InstaPay)',
                  style: TextStyle(
                    color: isVodafone ? Colors.redAccent : Colors.purpleAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Receipt Image with zoom hint
          if (imageData.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _showZoomedImage(imageData),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.black,
                      child: Image.memory(
                        base64Decode(imageData),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('تعذر عرض الإيصال',
                              style: TextStyle(color: Colors.white54)),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('اضغط للتكبير',
                            style:
                                TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Approve / Reject Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await AdminService.reviewDriverTopUp(
                      req['id'],
                      approve: true,
                    );
                    if (ok) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'تم قبول الطلب وإضافة الرصيد لمحفظة الكابتن ✓'),
                            backgroundColor: Color(0xff22C55E),
                          ),
                        );
                      }
                      _loadData();
                      widget.onDataChanged?.call();
                    }
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('قبول وشحن المحفظة',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff22C55E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _showRejectDialog(req['id']),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('رفض'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xffEF4444)),
                  foregroundColor: const Color(0xffEF4444),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String requestId) {
    final noteCtrl = TextEditingController(text: 'صورة الإيصال غير واضحة');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff16191D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('رفض طلب الشحن',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اكتب سبب الرفض ليظهر للكابتن:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xff1E232B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await AdminService.reviewDriverTopUp(
                requestId,
                approve: false,
                note: noteCtrl.text.trim(),
              );
              if (ok) {
                _loadData();
                widget.onDataChanged?.call();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
  }
}
