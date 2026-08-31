import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../features/auth/auth_service.dart';

class ShippingDashboardScreen extends StatefulWidget {
  const ShippingDashboardScreen({super.key});

  @override
  State<ShippingDashboardScreen> createState() => _ShippingDashboardScreenState();
}

class _ShippingDashboardScreenState extends State<ShippingDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _shippingOrders = [];
  Timer? _refreshTimer;

  // Stats
  int _totalOrders = 0;
  int _newOrders = 0;
  int _confirmedOrders = 0;
  int _completedOrders = 0;

  @override
  void initState() {
    super.initState();
    _fetchShippingData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchShippingData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchShippingData() async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.get('/api/admin/orders');

      if (response.statusCode == 200) {
        final data = response.data;
        final allOrders = List<Map<String, dynamic>>.from(
          (data['orders'] ?? data ?? []).map((e) => Map<String, dynamic>.from(e)),
        );

        final shippingOrders = allOrders
            .where((o) => o['serviceType'] == 'SHIPPING')
            .toList();

        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = null;
            _shippingOrders = shippingOrders;
            _totalOrders = shippingOrders.length;
            _newOrders = shippingOrders.where((o) => o['status'] == 'NEW').length;
            _confirmedOrders = shippingOrders.where((o) => o['status'] == 'CONFIRMED' || o['status'] == 'COMPANY_ACCEPTED').length;
            _completedOrders = shippingOrders.where((o) => o['status'] == 'COMPLETED').length;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Ø®Ø·Ø£ ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'ÙØ´Ù„ Ø§Ù„Ø§ØªØµØ§Ù„: $e';
        });
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'NEW': return 'Ø¬Ø¯ÙŠØ¯';
      case 'COMPANY_REVIEWING': return 'Ù‚ÙŠØ¯ Ø§Ù„Ù…Ø±Ø§Ø¬Ø¹Ø©';
      case 'COMPANY_ACCEPTED': return 'Ù…Ù‚Ø¨ÙˆÙ„';
      case 'COMPANY_REJECTED': return 'Ù…Ø±ÙÙˆØ¶';
      case 'PRICE_SENT': return 'ØªÙ… Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø³Ø¹Ø±';
      case 'CUSTOMER_APPROVED': return 'ÙˆØ§ÙÙ‚ Ø§Ù„Ø¹Ù…ÙŠÙ„';
      case 'CUSTOMER_REJECTED': return 'Ø±ÙØ¶ Ø§Ù„Ø¹Ù…ÙŠÙ„';
      case 'CONFIRMED': return 'Ù…Ø¤ÙƒØ¯';
      case 'COMPLETED': return 'Ù…ÙƒØªÙ…Ù„';
      case 'CANCELLED': return 'Ù…Ù„ØºÙŠ';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'NEW': return Colors.blue;
      case 'COMPANY_REVIEWING': return Colors.orange;
      case 'COMPANY_ACCEPTED': return Colors.teal;
      case 'COMPANY_REJECTED': return Colors.red;
      case 'PRICE_SENT': return Colors.purple;
      case 'CUSTOMER_APPROVED': return Colors.green;
      case 'CONFIRMED': return Colors.green.shade700;
      case 'COMPLETED': return Colors.green.shade900;
      case 'CANCELLED': return Colors.grey;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ø¯Ø§Ø´Ø¨ÙˆØ±Ø¯ Ø§Ù„Ø´Ø­Ù†'),
          backgroundColor: const Color(0xff16866b),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchShippingData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchShippingData,
                          child: const Text('Ø¥Ø¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø©'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchShippingData,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Stats Cards
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.5,
                          children: [
                            _buildStatCard('Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø·Ù„Ø¨Ø§Øª', '$_totalOrders', Icons.inventory_2, const Color(0xff16866b)),
                            _buildStatCard('Ø·Ù„Ø¨Ø§Øª Ø¬Ø¯ÙŠØ¯Ø©', '$_newOrders', Icons.fiber_new, Colors.blue),
                            _buildStatCard('Ù…Ø¤ÙƒØ¯Ø©', '$_confirmedOrders', Icons.check_circle, Colors.teal),
                            _buildStatCard('Ù…ÙƒØªÙ…Ù„Ø©', '$_completedOrders', Icons.done_all, Colors.green.shade700),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Ø·Ù„Ø¨Ø§Øª Ø§Ù„Ø´Ø­Ù†',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_shippingOrders.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                                    const SizedBox(height: 16),
                                    Text('Ù„Ø§ ØªÙˆØ¬Ø¯ Ø·Ù„Ø¨Ø§Øª Ø´Ø­Ù† Ø¨Ø¹Ø¯', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          ..._shippingOrders.map((order) => _buildOrderCard(order)),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Future<void> _adminAcceptOrder(String orderId) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.post('/api/admin/orders/$orderId/accept');
      if (response.statusCode == 200) {
        _fetchShippingData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم قبول الطلب')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _adminRejectOrder(String orderId) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.post('/api/admin/orders/$orderId/reject', data: {'reason': 'مرفوض من الإدارة'});
      if (response.statusCode == 200) {
        _fetchShippingData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الطلب')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _adminSendOffer(String orderId, double price) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.post('/api/admin/orders/$orderId/offer', data: {'offeredPrice': price});
      if (response.statusCode == 200) {
        _fetchShippingData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال العرض')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  void _showOfferDialog(String orderId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إرسال سعر'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'السعر المقترح (ج.م)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null && price > 0) {
                Navigator.pop(context);
                _adminSendOffer(orderId, price);
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  Future<void> _openMap(double? lat, double? lng) async {
    if (lat != null && lng != null) {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'NEW';
    final customerName = order['customer']?['name'] ?? 'عميل';
    final pickupAddress = order['shippingPickupAddress'] ?? 'غير محدد';
    final dropoffAddress = order['shippingDropoffAddress'] ?? 'غير محدد';
    final price = order['customerOfferPrice'] ?? 0;
    final shippingType = order['shippingType'] ?? '';
    final shippingSize = order['shippingSize'] ?? '';
    final orderId = order['id'] ?? '';
    
    final pickupLat = order['shippingPickupLat'] != null ? (order['shippingPickupLat'] as num).toDouble() : null;
    final pickupLng = order['shippingPickupLng'] != null ? (order['shippingPickupLng'] as num).toDouble() : null;
    final dropoffLat = order['shippingDropoffLat'] != null ? (order['shippingDropoffLat'] as num).toDouble() : null;
    final dropoffLng = order['shippingDropoffLng'] != null ? (order['shippingDropoffLng'] as num).toDouble() : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    customerName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(status).withOpacity(0.5)),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _openMap(pickupLat, pickupLng),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('من: $pickupAddress', style: TextStyle(fontSize: 13, color: Colors.blue.shade700, decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _openMap(dropoffLat, dropoffLng),
              child: Row(
                children: [
                  const Icon(Icons.flag, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('إلى: $dropoffAddress', style: TextStyle(fontSize: 13, color: Colors.blue.shade700, decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (shippingType.isNotEmpty || shippingSize.isNotEmpty)
                  Text(
                    '${shippingType.isNotEmpty ? shippingType : ''}${shippingSize.isNotEmpty ? ' - $shippingSize' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                Text(
                  '$price ج.م',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff16866b)),
                ),
              ],
            ),
            if (status == 'NEW' || status == 'COMPANY_REVIEWING') ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _adminAcceptOrder(orderId),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text('قبول'),
                  ),
                  ElevatedButton(
                    onPressed: () => _showOfferDialog(orderId),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    child: const Text('سعر'),
                  ),
                  TextButton(
                    onPressed: () => _adminRejectOrder(orderId),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('رفض'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

