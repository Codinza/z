import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import '../../features/auth/auth_service.dart';
import '../../core/config/app_config.dart';
import '../../core/services/notification_service.dart';
import '../../app.dart';

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
  socket_io.Socket? _socket;
  int _selectedTab = 0;

  static const _tabs = [
    ('جديدة', 'NEW'),
    ('مقبولة', 'ACCEPTED'),
    ('قيد التوصيل', 'IN_PROGRESS'),
    ('مكتملة', 'COMPLETED'),
    ('ملغاة', 'CANCELLED'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchShippingData();
    _initSocket();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchShippingData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

  void _initSocket() {
    _socket = socket_io.io(AppConfig.backendBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    _socket!.connect();
    _socket!.on('order_status_changed', (data) {
      if (data is! Map) return;
      final status = data['status']?.toString();
      final orderId = data['orderId']?.toString();
      final price = data['price'] ?? data['offeredPrice'] ?? data['offerAmount'];

      if (status == 'NEW_SHIPPING_ORDER') {
        NotificationService().showNotification(
          title: 'وصل طلب شحن جديد! 📦',
          body: 'طلب شحن جديد بانتظار مراجعتك وتقديم عرض السعر',
        );
      } else if (status == 'CUSTOMER_APPROVED' || status == 'CONFIRMED') {
        NotificationService().showNotification(
          title: 'العميل وافق على عرضك للشحن! 🚚✅',
          body: price != null
              ? 'وافق العميل على عرض السعر بقيمة $price ج.م. يمكنك متابعة الشحنة الآن.'
              : 'وافق العميل على عرض السعر. يمكنك بدء التوصيل.',
        );
      } else if (status == 'CUSTOMER_REJECTED') {
        NotificationService().showNotification(
          title: 'العميل رفض عرض السعر ✕',
          body: 'تم رفض عرض السعر لطلب الشحن ${orderId ?? ''}',
        );
      } else if (status == 'IN_PROGRESS') {
        NotificationService().showNotification(
          title: 'الشحنة قيد التوصيل 📦💨',
          body: 'تم تحديث حالة الشحنة إلى قيد التوصيل.',
        );
      } else if (status == 'COMPLETED') {
        NotificationService().showNotification(
          title: 'تم إكمال طلب الشحن بنجاح! 📦🎉',
          body: 'تم تسليم الشحنة بنجاح وإنهاء الطلب.',
        );
      } else if (status == 'CANCELLED') {
        NotificationService().showNotification(
          title: 'تم إلغاء طلب الشحن ⚠️',
          body: 'تم إلغاء طلب الشحن ${orderId ?? ''}',
        );
      }

      _fetchShippingData();
    });
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
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'خطأ ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'فشل الاتصال: $e';
        });
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'NEW': return 'جديد';
      case 'COMPANY_REVIEWING': return 'قيد المراجعة';
      case 'COMPANY_ACCEPTED': return 'مقبول';
      case 'COMPANY_REJECTED': return 'مرفوض';
      case 'PRICE_SENT': return 'تم إرسال السعر';
      case 'CUSTOMER_APPROVED': return 'وافق العميل';
      case 'CUSTOMER_REJECTED': return 'رفض العميل';
      case 'CONFIRMED': return 'مؤكد';
      case 'COMPLETED': return 'مكتمل';
      case 'CANCELLED': return 'ملغي';
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

  List<Map<String, dynamic>> _ordersForTab() {
    final filter = _tabs[_selectedTab].$2;
    return _shippingOrders.where((order) {
      final status = order['status']?.toString() ?? 'NEW';
      switch (filter) {
        case 'NEW':
          return status == 'NEW' || status == 'COMPANY_REVIEWING' || status == 'PRICE_SENT';
        case 'ACCEPTED':
          return status == 'COMPANY_ACCEPTED' || status == 'CUSTOMER_APPROVED' || status == 'CONFIRMED';
        case 'IN_PROGRESS':
          return status == 'IN_PROGRESS' || status == 'OUT_FOR_DELIVERY';
        case 'COMPLETED':
          return status == 'COMPLETED';
        case 'CANCELLED':
          return status == 'CANCELLED' || status == 'COMPANY_REJECTED' || status == 'CUSTOMER_REJECTED';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleOrders = _ordersForTab();
    final newCount = _shippingOrders.where((order) {
      final status = order['status']?.toString();
      return status == 'NEW' || status == 'COMPANY_REVIEWING';
    }).length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تشغيل الشحن'),
          backgroundColor: const Color(0xff123B5D),
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.notifications_none), onPressed: _fetchShippingData),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchShippingData,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
              onPressed: () async {
                await AuthService.logout();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (route) => false,
                );
              },
            ),
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 12),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xffF59E0B),
                child: Icon(Icons.business, color: Colors.white, size: 19),
              ),
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
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchShippingData,
                    child: LayoutBuilder(
                      builder: (context, constraints) => ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth > 700 ? constraints.maxWidth * .08 : 16,
                          vertical: 20,
                        ),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('صباح الخير، فريق التشغيل', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xff123B5D))),
                                    const SizedBox(height: 5),
                                    Text('راجع الطلبات واتخذ الإجراء المناسب بسرعة.', style: TextStyle(color: Colors.blueGrey.shade600)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(color: const Color(0xfffff4df), borderRadius: BorderRadius.circular(12)),
                                child: Row(children: [
                                  const Icon(Icons.notifications_active_outlined, color: Color(0xffD97706), size: 20),
                                  const SizedBox(width: 8),
                                  Text('$newCount جديد', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff92400E))),
                                ]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xffE4EAF0))),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: List.generate(_tabs.length, (index) {
                                final selected = index == _selectedTab;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => setState(() => _selectedTab = index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                      decoration: BoxDecoration(color: selected ? const Color(0xff123B5D) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                                      child: Text(_tabs[index].$1, style: TextStyle(color: selected ? Colors.white : const Color(0xff526579), fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                );
                              })),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(children: [
                            Text(_tabs[_selectedTab].$1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xff123B5D))),
                            const SizedBox(width: 8),
                            Text('${visibleOrders.length}', style: const TextStyle(color: Color(0xffF59E0B), fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 12),
                          if (visibleOrders.isEmpty)
                            _buildEmptyState()
                          else
                            ...visibleOrders.map(_buildOrderCard),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() => Container(
        padding: const EdgeInsets.all(34),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xffE4EAF0))),
        child: Column(children: [
          const Icon(Icons.inbox_outlined, size: 48, color: Color(0xffA8B6C5)),
          const SizedBox(height: 12),
          Text('لا توجد طلبات في هذا التبويب', style: TextStyle(color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600)),
        ]),
      );

  Future<void> _adminAcceptOrder(String orderId) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.post('/api/admin/orders/$orderId/accept');
      if (response.statusCode == 200) {
        _fetchShippingData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم قبول الطلب')));
      }
    } catch (e) {
      final message = e is DioException && e.response?.data is Map
          ? (e.response?.data['error']?.toString() ?? 'فشل إرسال العرض')
          : 'فشل إرسال العرض. حاول مرة أخرى';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      final response = await dio.post(
        '/api/admin/orders/$orderId/offer',
        data: {'offeredPrice': price},
      );
      if (response.statusCode == 200) {
        _fetchShippingData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إرسال عرض السعر ($price ج.م) بنجاح ✓'),
              backgroundColor: const Color(0xff15803D),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      final message = e is DioException && e.response?.data is Map
          ? (e.response?.data['error']?.toString() ?? 'فشل إرسال العرض')
          : 'فشل إرسال العرض. حاول مرة أخرى';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xffB42318),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showOfferPriceDialog(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final initialPrice = (order['customerOfferPrice'] as num?)?.toDouble() ?? 0.0;
    final currentCompanyPrice = (order['companyOfferPrice'] as num?)?.toDouble();
    final controller = TextEditingController(
      text: (currentCompanyPrice ?? (initialPrice > 0 ? initialPrice : 100.0)).toStringAsFixed(0),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentVal = double.tryParse(controller.text) ?? 0.0;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xff111315),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xff2A2D33),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'تقديم عرض سعر للعميل',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xff1A1D21),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xff2A2D33)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'سعر العميل المقترح:',
                          style: TextStyle(color: Color(0xff94A3B8), fontSize: 13),
                        ),
                        Text(
                          '${initialPrice.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'السعر المعروض من الشركة (ج.م):',
                    style: TextStyle(color: Color(0xffF59E0B), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xff1A1D21),
                      suffixText: 'ج.م',
                      suffixStyle: const TextStyle(color: Color(0xffF59E0B), fontWeight: FontWeight.bold),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xff2A2D33)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xffF59E0B), width: 1.5),
                      ),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'زيادة سريعة على سعر العميل:',
                    style: TextStyle(color: Color(0xff94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [20, 50, 100, 200].map((inc) {
                      final targetPrice = initialPrice + inc;
                      return ActionChip(
                        label: Text('+$inc ج.م (${targetPrice.toStringAsFixed(0)})'),
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                        backgroundColor: const Color(0xff1A1D21),
                        side: const BorderSide(color: Color(0xff2A2D33)),
                        onPressed: () {
                          controller.text = targetPrice.toStringAsFixed(0);
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: currentVal <= 0
                          ? null
                          : () {
                              Navigator.pop(context);
                              _adminSendOffer(orderId, currentVal);
                            },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        'إرسال العرض ($currentVal ج.م)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffD97706),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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

  String _orderDate(Map<String, dynamic> order) {
    final raw = order['createdAt']?.toString();
    final date = raw == null ? null : DateTime.tryParse(raw);
    if (date == null) return 'وقت غير محدد';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  double? _distanceKm(Map<String, dynamic> order) {
    final pickupLat = (order['shippingPickupLat'] as num?)?.toDouble();
    final pickupLng = (order['shippingPickupLng'] as num?)?.toDouble();
    final dropoffLat = (order['shippingDropoffLat'] as num?)?.toDouble();
    final dropoffLng = (order['shippingDropoffLng'] as num?)?.toDouble();
    if (pickupLat == null || pickupLng == null || dropoffLat == null || dropoffLng == null) return null;
    final distance = const Distance().as(LengthUnit.Kilometer, LatLng(pickupLat, pickupLng), LatLng(dropoffLat, dropoffLng));
    return distance;
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final pickup = LatLng(
      (order['shippingPickupLat'] as num?)?.toDouble() ?? 30.0444,
      (order['shippingPickupLng'] as num?)?.toDouble() ?? 31.2357,
    );
    final dropoff = LatLng(
      (order['shippingDropoffLat'] as num?)?.toDouble() ?? 30.0444,
      (order['shippingDropoffLng'] as num?)?.toDouble() ?? 31.2357,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShippingOrderDetails(
        order: order,
        pickup: pickup,
        dropoff: dropoff,
        statusText: _getStatusText(order['status']?.toString() ?? 'NEW'),
        statusColor: _getStatusColor(order['status']?.toString() ?? 'NEW'),
        dateText: _orderDate(order),
        onOfferPrice: () {
          Navigator.pop(context);
          _showOfferPriceDialog(order);
        },
      ),
    );
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
    final distance = _distanceKm(order);
    
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
            if (pickupLat != null && pickupLng != null && dropoffLat != null && dropoffLng != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints([
                          LatLng(pickupLat, pickupLng),
                          LatLng(dropoffLat, dropoffLng),
                        ]),
                        padding: const EdgeInsets.all(26.0),
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.zoon.admin',
                        tileProvider: CancellableNetworkTileProvider(),
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              LatLng(pickupLat, pickupLng),
                              LatLng(dropoffLat, dropoffLng),
                            ],
                            color: const Color(0xff16866b),
                            strokeWidth: 4,
                            pattern: StrokePattern.dashed(segments: const [10, 10]),
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(pickupLat, pickupLng),
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.location_on, color: Color(0xff15803D), size: 28),
                          ),
                          Marker(
                            point: LatLng(dropoffLat, dropoffLng),
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.flag, color: Color(0xffB42318), size: 26),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _metaItem(Icons.route_outlined, distance == null ? 'المسافة غير محددة' : '${distance.toStringAsFixed(1)} كم'),
                _metaItem(Icons.schedule_outlined, _orderDate(order)),
              ],
            ),
            if (status == 'NEW' || status == 'COMPANY_REVIEWING' || status == 'PRICE_SENT') ...[
              const Divider(height: 24),
              if (status == 'PRICE_SENT')
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xffF59E0B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xffF59E0B).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xffF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تم إرسال عرض (${order['companyOfferPrice']} ج.م) - بانتظار رد العميل',
                          style: const TextStyle(fontSize: 12, color: Color(0xffD97706), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _adminAcceptOrder(orderId),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('قبول'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff15803D), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showOfferPriceDialog(order),
                      icon: const Icon(Icons.local_offer_outlined, size: 16),
                      label: Text(status == 'PRICE_SENT' ? 'تعديل السعر' : 'عرض سعر'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffD97706), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _adminRejectOrder(orderId),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('رفض'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xffB42318), side: const BorderSide(color: Color(0xffB42318)), padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'عرض التفاصيل',
                    onPressed: () => _showOrderDetails(order),
                    icon: const Icon(Icons.visibility_outlined, color: Color(0xff123B5D)),
                  ),
                ],
              ),
            ] else ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showOrderDetails(order),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('عرض التفاصيل'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xff123B5D)),
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

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16, color: const Color(0xff6B7D90)), const SizedBox(width: 4), Text(text, style: const TextStyle(color: Color(0xff6B7D90), fontSize: 12))],
    );
  }
}

class _ShippingOrderDetails extends StatelessWidget {
  final Map<String, dynamic> order;
  final LatLng pickup;
  final LatLng dropoff;
  final String statusText;
  final Color statusColor;
  final String dateText;
  final VoidCallback? onOfferPrice;

  const _ShippingOrderDetails({
    required this.order,
    required this.pickup,
    required this.dropoff,
    required this.statusText,
    required this.statusColor,
    required this.dateText,
    this.onOfferPrice,
  });

  @override
  Widget build(BuildContext context) {
    final customer = order['customer'] as Map?;
    final status = order['status']?.toString() ?? 'NEW';
    final canOffer = status == 'NEW' || status == 'COMPANY_REVIEWING' || status == 'PRICE_SENT';

    return Container(
      height: MediaQuery.of(context).size.height * .88,
      decoration: const BoxDecoration(color: Color(0xffF7F9FC), borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(children: [
              const Expanded(child: Text('تفاصيل طلب الشحن', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xff123B5D)))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
          ),
          SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(initialCenter: pickup, initialZoom: 11),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.zoon.admin', tileProvider: CancellableNetworkTileProvider()),
                PolylineLayer(polylines: [Polyline(points: [pickup, dropoff], color: const Color(0xff16866b), strokeWidth: 4)]),
                MarkerLayer(markers: [
                  Marker(point: pickup, width: 42, height: 42, child: const Icon(Icons.location_on, color: Color(0xff15803D), size: 36)),
                  Marker(point: dropoff, width: 42, height: 42, child: const Icon(Icons.flag, color: Color(0xffB42318), size: 32)),
                ]),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [Expanded(child: Text('#${order['id'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff123B5D)))), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: statusColor.withOpacity(.12), borderRadius: BorderRadius.circular(20)), child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)))]),
                const SizedBox(height: 18),
                _detailRow(Icons.person_outline, 'العميل', customer?['name']?.toString() ?? 'غير محدد'),
                _detailRow(Icons.phone_outlined, 'رقم الهاتف', customer?['phone']?.toString() ?? 'غير محدد'),
                _detailRow(Icons.my_location, 'الاستلام', order['shippingPickupAddress']?.toString() ?? 'غير محدد'),
                _detailRow(Icons.flag_outlined, 'التسليم', order['shippingDropoffAddress']?.toString() ?? 'غير محدد'),
                _detailRow(Icons.inventory_2_outlined, 'تفاصيل الشحنة', '${order['shippingType'] ?? ''} ${order['shippingSize'] ?? ''} ${order['shippingDetails'] ?? ''}'.trim()),
                _detailRow(Icons.payments_outlined, 'قيمة التوصيل المقترحة', '${order['customerOfferPrice'] ?? 0} ج.م'),
                if (order['companyOfferPrice'] != null)
                  _detailRow(Icons.local_offer_outlined, 'عرض سعر الشركة', '${order['companyOfferPrice']} ج.م'),
                _detailRow(Icons.schedule_outlined, 'تاريخ الطلب', dateText),
                if (canOffer && onOfferPrice != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onOfferPrice,
                      icon: const Icon(Icons.local_offer_rounded, size: 18),
                      label: Text(
                        status == 'PRICE_SENT' ? 'تعديل عرض السعر للعميل' : 'تقديم عرض سعر للعميل',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 20, color: const Color(0xff16866b)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Color(0xff6B7D90)),), const SizedBox(height: 3), Text(value.isEmpty ? 'غير محدد' : value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xff243B53))) ]))]),
      );
}

