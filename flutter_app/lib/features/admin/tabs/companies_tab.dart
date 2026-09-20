import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../admin_service.dart';
import '../../../core/widgets/animations/zoon_animations.dart';

class CompaniesTab extends StatefulWidget {
  final VoidCallback? onDataChanged;
  const CompaniesTab({super.key, this.onDataChanged});

  @override
  State<CompaniesTab> createState() => _CompaniesTabState();
}

class _CompaniesTabState extends State<CompaniesTab> {
  bool _isLoading = true;
  String _selectedStatus = 'ALL'; // ALL, pending, active, rejected
  List<Map<String, dynamic>> _companies = [];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoading = true);
    final list = await AdminService.getAllCompanies(
      status: _selectedStatus == 'ALL' ? null : _selectedStatus,
    );
    if (mounted) {
      setState(() {
        _companies = list;
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

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xff22C55E);
      case 'pending':
        return const Color(0xffF59E0B);
      case 'rejected':
        return const Color(0xffEF4444);
      default:
        return Colors.white54;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'نشطة';
      case 'pending':
        return 'بانتظار الموافقة';
      case 'rejected':
        return 'مرفوضة';
      default:
        return status;
    }
  }

  Future<void> _approve(String id) async {
    final ok = await AdminService.approveCompany(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم اعتماد الشركة ✓' : 'فشل الاعتماد'),
        backgroundColor: ok ? const Color(0xff22C55E) : Colors.redAccent,
      ),
    );
    if (ok) {
      _loadCompanies();
      widget.onDataChanged?.call();
    }
  }

  Future<void> _reject(String id) async {
    final ok = await AdminService.rejectCompany(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم رفض الشركة' : 'فشل الرفض'),
        backgroundColor: ok ? const Color(0xffEF4444) : Colors.redAccent,
      ),
    );
    if (ok) {
      _loadCompanies();
      widget.onDataChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          color: const Color(0xff12151A),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in const [
                  ('ALL', 'الكل'),
                  ('pending', 'قيد المراجعة'),
                  ('active', 'نشطة'),
                  ('rejected', 'مرفوضة'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: _selectedStatus == entry.$1,
                      onSelected: (_) {
                        setState(() => _selectedStatus = entry.$1);
                        _loadCompanies();
                      },
                      selectedColor: const Color(0xffF97316),
                      backgroundColor: const Color(0xff1A1F2A),
                      labelStyle: TextStyle(
                        color: _selectedStatus == entry.$1
                            ? Colors.white
                            : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      side: BorderSide.none,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xffF97316)),
                )
              : _companies.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _loadCompanies,
                      color: const Color(0xffF97316),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          ZoonEmptyState(
                            title: 'لا توجد شركات',
                            subtitle:
                                'عند تسجيل شركات ليموزين أو شحن ستظهر هنا للمراجعة والاعتماد.',
                            icon: Icons.business_outlined,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCompanies,
                      color: const Color(0xffF97316),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                        itemCount: _companies.length,
                        itemBuilder: (context, index) {
                          final company = _companies[index];
                          return _buildCompanyCard(company);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildCompanyCard(Map<String, dynamic> company) {
    final id = company['id']?.toString() ?? '';
    final name = company['companyName']?.toString() ?? 'شركة';
    final type = company['companyType']?.toString() ?? '';
    final status = company['status']?.toString() ?? 'pending';
    final phone = company['companyPhone']?.toString() ??
        company['user']?['phone']?.toString() ??
        '';
    final owner = company['user']?['name']?.toString() ?? '';
    final address = company['address']?.toString() ?? '';
    final ordersCount = (company['orders'] is List)
        ? (company['orders'] as List).length
        : 0;
    final isPending = status == 'pending';
    final isLimousine = type.toUpperCase() == 'LIMOUSINE';

    return PressableScale(
      scaleFactor: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xff161B26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending
                ? const Color(0xffF59E0B).withOpacity(0.45)
                : const Color(0xff252E3E),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (isLimousine
                            ? const Color(0xffF97316)
                            : const Color(0xff06B6D4))
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isLimousine
                        ? Icons.directions_car_filled_rounded
                        : Icons.local_shipping_rounded,
                    color: isLimousine
                        ? const Color(0xffF97316)
                        : const Color(0xff06B6D4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLimousine ? 'شركة ليموزين' : 'شركة شحن',
                        style: const TextStyle(
                          color: Color(0xff94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (owner.isNotEmpty)
              _metaRow(Icons.person_outline, 'المالك: $owner'),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _callPhone(phone),
                child: _metaRow(Icons.phone_outlined, phone),
              ),
            ],
            if (address.isNotEmpty) ...[
              const SizedBox(height: 6),
              _metaRow(Icons.location_on_outlined, address),
            ],
            const SizedBox(height: 6),
            _metaRow(Icons.receipt_long_outlined, 'الطلبات: $ordersCount'),
            if (isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xffEF4444),
                        side: const BorderSide(color: Color(0xffEF4444)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('رفض'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approve(id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff22C55E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('اعتماد'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xff64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xffCBD5E1), fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
