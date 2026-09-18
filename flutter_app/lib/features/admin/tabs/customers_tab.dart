import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../admin_service.dart';

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final list = await AdminService.getAllCustomers(
      search: _searchCtrl.text,
    );
    if (mounted) {
      setState(() {
        _customers = list;
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
      clean = '2$clean'; // Egypt code
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
        // Search & Stats Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: const Color(0xff12151A),
          child: Column(
            children: [
              // Search Input
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xff1E232B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => _loadCustomers(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'بحث في العملاء بالاسم أو رقم الهاتف...',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 12),
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xffF97316), size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white54, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadCustomers();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Summary counter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إجمالي العملاء: ${_customers.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _loadCustomers,
                    icon: const Icon(Icons.refresh, size: 16, color: Color(0xffF97316)),
                    label: const Text('تحديث',
                        style: TextStyle(color: Color(0xffF97316), fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Customers List
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xffF97316)))
              : RefreshIndicator(
                  color: const Color(0xffF97316),
                  onRefresh: _loadCustomers,
                  child: _customers.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline,
                                        size: 60,
                                        color: Colors.white.withOpacity(0.2)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'لا يوجد عملاء مسجلين حالياً',
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
                          itemCount: _customers.length,
                          itemBuilder: (context, index) {
                            final customer = _customers[index];
                            return _buildCustomerCard(customer);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final name = customer['name']?.toString() ?? 'عميل';
    final phone = customer['phone']?.toString() ?? '';
    final email = customer['email']?.toString() ?? '';
    final tripsCount = customer['totalTrips'] ?? 0;
    final ordersCount = customer['totalOrders'] ?? 0;
    final totalSpent = (customer['totalSpent'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xff1A1D24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Name, Direct Phone / WA Buttons
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xff3B82F6).withOpacity(0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Color(0xff60A5FA),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone.isNotEmpty ? phone : (email.isNotEmpty ? email : '-'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Call & WhatsApp
              if (phone.isNotEmpty) ...[
                IconButton(
                  onPressed: () => _callPhone(phone),
                  icon: const Icon(Icons.phone, color: Colors.green, size: 18),
                  tooltip: 'اتصال هاتفي',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.15),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _openWhatsApp(phone),
                  icon: const Icon(Icons.chat, color: Color(0xff25D366), size: 18),
                  tooltip: 'واتساب',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xff25D366).withOpacity(0.15),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),

          // Stats badges row
          Row(
            children: [
              _buildMiniChip(
                'مشاوير ليموزين: $tripsCount',
                Icons.local_taxi,
                const Color(0xffF97316),
              ),
              const SizedBox(width: 8),
              _buildMiniChip(
                'طلبات شحن: $ordersCount',
                Icons.local_shipping,
                const Color(0xff3B82F6),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${totalSpent.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                    color: Color(0xff10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
