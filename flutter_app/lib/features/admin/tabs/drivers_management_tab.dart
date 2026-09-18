import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../admin_service.dart';
import '../../auth/auth_service.dart';

class DriversManagementTab extends StatefulWidget {
  final VoidCallback? onDataChanged;
  const DriversManagementTab({super.key, this.onDataChanged});

  @override
  State<DriversManagementTab> createState() => _DriversManagementTabState();
}

class _DriversManagementTabState extends State<DriversManagementTab> {
  bool _isLoading = true;
  String _selectedStatus = 'ALL'; // ALL, pending, approved, suspended, rejected
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    final list = await AdminService.getAllDrivers(
      status: _selectedStatus == 'ALL' ? null : _selectedStatus,
      search: _searchCtrl.text,
    );
    if (mounted) {
      setState(() {
        _drivers = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '2$clean'; // Egypt code default
    }
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search & Add Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: const Color(0xff12151A),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xff1E232B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => _loadDrivers(),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'بحث بالاسم، الهاتف، أو لوحة السيارة...',
                          hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 12),
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0xffF97316), size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: Colors.white54, size: 16),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _loadDrivers();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddDriverDialog,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('إضافة سائق',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffF97316),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('الكل', 'ALL', Icons.list),
                    const SizedBox(width: 8),
                    _buildFilterChip('معلقين ⏳', 'pending', Icons.hourglass_top),
                    const SizedBox(width: 8),
                    _buildFilterChip('معتمدين ✓', 'approved', Icons.check_circle_outline),
                    const SizedBox(width: 8),
                    _buildFilterChip('موقوفين ⛔', 'suspended', Icons.block),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Drivers List
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xffF97316)))
              : RefreshIndicator(
                  color: const Color(0xffF97316),
                  onRefresh: _loadDrivers,
                  child: _drivers.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_off_outlined,
                                        size: 60,
                                        color: Colors.white.withOpacity(0.2)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'لا يوجد سائقين في هذا القسم',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _drivers.length,
                          itemBuilder: (context, index) {
                            final driver = _drivers[index];
                            return _buildDriverCard(driver);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String status, IconData icon) {
    final isSelected = _selectedStatus == status;
    return InkWell(
      onTap: () {
        setState(() => _selectedStatus = status);
        _loadDrivers();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xffF97316)
              : const Color(0xff1E232B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xffF97316) : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final status = driver['status']?.toString() ?? 'approved';
    final car = driver['car'] as Map<String, dynamic>?;
    final wallet = (driver['walletBalance'] as num?)?.toDouble() ?? 0.0;
    final rating = (driver['rating'] as num?)?.toDouble() ?? 5.0;
    final tripsCount = driver['completedTripsCount'] ?? 0;
    final phone = driver['phone']?.toString() ?? '';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'pending':
        statusColor = const Color(0xffF59E0B);
        statusText = 'قيد المراجعة';
        break;
      case 'approved':
        statusColor = const Color(0xff22C55E);
        statusText = 'معتمد ونشط';
        break;
      case 'suspended':
        statusColor = const Color(0xffEF4444);
        statusText = 'موقوف مؤقتاً';
        break;
      case 'rejected':
        statusColor = Colors.grey;
        statusText = 'مرفوض';
        break;
      default:
        statusColor = const Color(0xff22C55E);
        statusText = 'معتمد';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xff1A1D24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Avatar, Name, Phone, Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xff2A303C),
                  child: Text(
                    driver['name']?.isNotEmpty == true
                        ? driver['name'][0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                      color: Color(0xffF97316),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              driver['name'] ?? 'سائق بدون اسم',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: statusColor.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_iphone,
                              size: 14, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          // Rating & Trips
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 2),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                ' ($tripsCount رحلة)',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),

            // Car & Wallet Details Row
            Row(
              children: [
                // Car Details Pill
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xff12151A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car,
                            size: 16, color: Color(0xffF97316)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            car != null
                                ? '${car['model'] ?? ''} | ${car['plateNumber'] ?? ''}'
                                : 'لا توجد بيانات سيارة',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Wallet Balance Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: wallet < 0
                        ? const Color(0xffEF4444).withOpacity(0.15)
                        : const Color(0xff22C55E).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: wallet < 0
                          ? const Color(0xffEF4444).withOpacity(0.3)
                          : const Color(0xff22C55E).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: wallet < 0
                            ? const Color(0xffEF4444)
                            : const Color(0xff22C55E),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${wallet.toStringAsFixed(1)} ج.م',
                        style: TextStyle(
                          color: wallet < 0
                              ? const Color(0xffEF4444)
                              : const Color(0xff22C55E),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                // Quick Call & WhatsApp
                if (phone.isNotEmpty) ...[
                  IconButton(
                    onPressed: () => _callPhone(phone),
                    icon: const Icon(Icons.phone, color: Colors.green, size: 20),
                    tooltip: 'اتصال هاتفي',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.15),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _openWhatsApp(phone),
                    icon: const Icon(Icons.chat, color: Color(0xff25D366), size: 20),
                    tooltip: 'واتساب',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xff25D366).withOpacity(0.15),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Conditional Status Actions
                if (status == 'pending') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await AdminService.approveDriver(driver['id']);
                        if (ok) {
                          _loadDrivers();
                          widget.onDataChanged?.call();
                        }
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('اعتماد ✓',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await AdminService.rejectDriver(driver['id']);
                        if (ok) {
                          _loadDrivers();
                          widget.onDataChanged?.call();
                        }
                      },
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('رفض',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xffEF4444)),
                        foregroundColor: const Color(0xffEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ] else ...[
                  // Direct Wallet Adjust Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showWalletAdjustDialog(driver),
                      icon: const Icon(Icons.add_card, size: 16),
                      label: const Text('شحن / تعديل رصيد',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffF97316),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Suspend or Re-activate
                  if (status == 'approved') ...[
                    OutlinedButton(
                      onPressed: () async {
                        final ok = await AdminService.updateDriverStatus(
                            driver['id'], 'suspended');
                        if (ok) {
                          _loadDrivers();
                          widget.onDataChanged?.call();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade400),
                        foregroundColor: Colors.red.shade400,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('إيقاف ⛔',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ] else if (status == 'suspended') ...[
                    OutlinedButton(
                      onPressed: () async {
                        final ok = await AdminService.updateDriverStatus(
                            driver['id'], 'approved');
                        if (ok) {
                          _loadDrivers();
                          widget.onDataChanged?.call();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xff22C55E)),
                        foregroundColor: const Color(0xff22C55E),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('تفعيل ✅',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Wallet adjustment dialog
  void _showWalletAdjustDialog(Map<String, dynamic> driver) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'شحن كاش في المكتب');
    bool isCredit = true; // true = add, false = deduct
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xff16191D),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'تعديل رصيد محفظة: ${driver['name'] ?? ''}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                              child: Text('إيداع (+) رصيد',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          selected: isCredit,
                          selectedColor: const Color(0xff22C55E),
                          onSelected: (val) =>
                              setModalState(() => isCredit = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                              child: Text('خصم (-) رصيد',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          selected: !isCredit,
                          selectedColor: const Color(0xffEF4444),
                          onSelected: (val) =>
                              setModalState(() => isCredit = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Quick presets
                  Wrap(
                    spacing: 8,
                    children: [50, 100, 200, 500].map((preset) {
                      return ActionChip(
                        label: Text('$preset ج.م',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        backgroundColor: const Color(0xff232832),
                        onPressed: () {
                          setModalState(() {
                            amountCtrl.text = preset.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'المبلغ بالجنيه المصري',
                      labelStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(Icons.attach_money,
                          color: Color(0xffF97316)),
                      filled: true,
                      fillColor: const Color(0xff1E232B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'سبب المعاملة / ملاحظة',
                      labelStyle: const TextStyle(color: Colors.white60),
                      prefixIcon:
                          const Icon(Icons.notes, color: Colors.white54),
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final val = double.tryParse(amountCtrl.text.trim());
                        if (val == null || val <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('يرجى كتابة مبلغ صحيح')));
                          return;
                        }
                        final finalAmount = isCredit ? val : -val;
                        setModalState(() => isSubmitting = true);
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await AdminService.adjustDriverWallet(
                          driver['id'],
                          finalAmount,
                          reason: reasonCtrl.text.trim(),
                        );
                        if (mounted) {
                          navigator.pop();
                          if (ok) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                    'تم تحديث رصيد الكابتن بنجاح ($finalAmount ج.م) ✓'),
                                backgroundColor: const Color(0xff22C55E),
                              ),
                            );
                            _loadDrivers();
                            widget.onDataChanged?.call();
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('فشل تحديث الرصيد'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCredit
                      ? const Color(0xff22C55E)
                      : const Color(0xffEF4444),
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(isCredit ? 'تأكيد الإيداع' : 'تأكيد الخصم'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Add Driver Dialog
  void _showAddDriverDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: const Color(0xff16191D),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إضافة سائق واعتماده فوراً',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  _buildModalField(nameCtrl, 'اسم السائق', 'أحمد علي', Icons.person),
                  const SizedBox(height: 10),
                  _buildModalField(phoneCtrl, 'رقم الهاتف', '01xxxxxxxxx', Icons.phone,
                      keyboard: TextInputType.phone),
                  const SizedBox(height: 10),
                  _buildModalField(passCtrl, 'كلمة المرور', '••••••••', Icons.lock,
                      obscure: true),
                  const SizedBox(height: 14),
                  const Text('بيانات السيارة',
                      style: TextStyle(
                          color: Color(0xffF97316),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildModalField(modelCtrl, 'موديل ونوع السيارة', 'نيسان صني',
                      Icons.directions_car),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _buildModalField(
                              colorCtrl, 'اللون', 'أبيض', Icons.color_lens)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildModalField(yearCtrl, 'سنة الصنع', '2023',
                              Icons.calendar_today,
                              keyboard: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildModalField(plateCtrl, 'رقم اللوحة', 'س ق د 1234', Icons.badge),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty ||
                                phoneCtrl.text.trim().isEmpty ||
                                passCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('يرجى ملء البيانات الأساسية')));
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            try {
                              final res = await AuthService.register(
                                name: nameCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                password: passCtrl.text.trim(),
                                role: 'driver',
                                carModel: modelCtrl.text.trim().isEmpty
                                    ? 'سيدان'
                                    : modelCtrl.text.trim(),
                                carColor: colorCtrl.text.trim().isEmpty
                                    ? 'أبيض'
                                    : colorCtrl.text.trim(),
                                carYear: yearCtrl.text.trim().isEmpty
                                    ? '2023'
                                    : yearCtrl.text.trim(),
                                plateNumber: plateCtrl.text.trim().isEmpty
                                    ? 'أ ب ج 111'
                                    : plateCtrl.text.trim(),
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                _loadDrivers();
                                widget.onDataChanged?.call();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res != null
                                        ? 'تم تسجيل السائق بنجاح ✓'
                                        : 'فشل التسجيل'),
                                    backgroundColor: const Color(0xff22C55E),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setModalState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('خطأ: $e')));
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffF97316),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('تسجيل واعتماد السائق فوراً',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalField(
      TextEditingController ctrl, String label, String hint, IconData icon,
      {TextInputType keyboard = TextInputType.text, bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1F2328),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
          hintStyle:
              TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
          prefixIcon: Icon(icon, color: const Color(0xffF97316), size: 18),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
