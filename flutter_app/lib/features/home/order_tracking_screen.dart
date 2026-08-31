import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const _defaultLocation = LatLng(30.0444, 31.2357);

  final MapController _mapController = MapController();
  socket_io.Socket? _socket;
  Timer? _refreshTimer;
  Map<String, dynamic>? _order;
  LatLng? _driverLocation;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _connectSocket();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadOrder(silent: true),
    );
  }

  Future<void> _loadOrder({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await ApiClient().dio.get('/api/orders/${widget.orderId}');
      final order = response.data['order'];
      if (response.statusCode != 200 || order is! Map) {
        throw Exception('تعذر تحميل تفاصيل الطلب');
      }
      if (mounted) {
        setState(() {
          _order = Map<String, dynamic>.from(order);
          _isLoading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _error = 'فشل تحميل الطلب: $error';
        });
      }
    }
  }

  void _connectSocket() {
    _socket = socket_io.io(AppConfig.backendBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    _socket!.connect();
    _socket!.on('connect', (_) {
      _socket!.emit('customer:track_trip', widget.orderId);
    });
    _socket!.on('location_update', _handleDriverLocation);
    _socket!.on('driver_location_update', _handleDriverLocation);
    _socket!.on('order_status_changed', _handleOrderUpdate);
    _socket!.on('trip_status_changed', _handleOrderUpdate);
  }

  void _handleDriverLocation(dynamic data) {
    if (data is! Map ||
        (data['rideId']?.toString() != widget.orderId &&
            data['orderId']?.toString() != widget.orderId)) {
      return;
    }
    final lat = double.tryParse(data['lat']?.toString() ?? '');
    final lng = double.tryParse(data['lng']?.toString() ?? '');
    if (lat == null || lng == null || !mounted) return;
    setState(() => _driverLocation = LatLng(lat, lng));
    _mapController.move(LatLng(lat, lng), 14);
  }

  void _handleOrderUpdate(dynamic data) {
    if (data is! Map ||
        (data['rideId']?.toString() != widget.orderId &&
            data['orderId']?.toString() != widget.orderId)) {
      return;
    }
    final status = data['status']?.toString();
    if (status != null && mounted) {
      setState(() {
        _order = {...?_order, 'status': status};
      });
    }
  }

  LatLng _locationFor(String type) {
    final prefix = _order?['serviceType'] == 'SHIPPING' ? 'shipping' : 'limousine';
    final lat = double.tryParse(_order?['$prefix${type}Lat']?.toString() ?? '');
    final lng = double.tryParse(_order?['$prefix${type}Lng']?.toString() ?? '');
    if (lat == null || lng == null) return _defaultLocation;
    return LatLng(lat, lng);
  }

  String _statusText(String? status) {
    switch (status) {
      case 'NEW':
        return 'تم استلام الطلب';
      case 'PRICE_SENT':
        return 'وصل عرض سعر';
      case 'CUSTOMER_APPROVED':
        return 'تمت الموافقة على العرض';
      case 'CONFIRMED':
        return 'الطلب قيد التنفيذ';
      case 'COMPLETED':
        return 'اكتمل الطلب';
      case 'CANCELLED':
        return 'تم إلغاء الطلب';
      default:
        return 'جاري متابعة الطلب';
    }
  }

  int _statusIndex(String? status) {
    switch (status) {
      case 'PRICE_SENT':
      case 'CUSTOMER_APPROVED':
        return 1;
      case 'CONFIRMED':
        return 2;
      case 'COMPLETED':
        return 3;
      default:
        return 0;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isShipping = _order?['serviceType'] == 'SHIPPING';
    final color = isShipping ? const Color(0xff16866b) : const Color(0xff2364aa);
    final pickup = _locationFor('Pickup');
    final dropoff = _locationFor('Dropoff');
    final route = _driverLocation ?? pickup;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isShipping ? 'تتبع الشحنة' : 'تتبع الرحلة'),
          centerTitle: true,
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _loadOrder)
                : Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(initialCenter: route, initialZoom: 13),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.zoon.rideflow',
                            tileProvider: CancellableNetworkTileProvider(),
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _driverLocation == null
                                    ? [pickup, dropoff]
                                    : [_driverLocation!, pickup, dropoff],
                                color: color,
                                strokeWidth: 5,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: pickup,
                                width: 44,
                                height: 44,
                                child: const Icon(Icons.trip_origin,
                                    color: Colors.green, size: 34),
                              ),
                              Marker(
                                point: dropoff,
                                width: 44,
                                height: 44,
                                child: const Icon(Icons.location_on,
                                    color: Colors.red, size: 38),
                              ),
                              if (_driverLocation != null)
                                Marker(
                                  point: _driverLocation!,
                                  width: 46,
                                  height: 46,
                                  child: Icon(
                                    isShipping
                                        ? Icons.local_shipping
                                        : Icons.directions_car,
                                    color: color,
                                    size: 38,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: _TrackingPanel(
                          color: color,
                          title: _statusText(_order?['status']?.toString()),
                          orderId: widget.orderId,
                          statusIndex: _statusIndex(_order?['status']?.toString()),
                          hasLiveDriver: _driverLocation != null,
                            offers: (_order?['priceOffers'] as List? ?? [])
                              .whereType<Map>()
                              .map((offer) => Map<String, dynamic>.from(offer))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _TrackingPanel extends StatelessWidget {
  final Color color;
  final String title;
  final String orderId;
  final int statusIndex;
  final bool hasLiveDriver;
  final List<Map<String, dynamic>> offers;

  const _TrackingPanel({
    required this.color,
    required this.title,
    required this.orderId,
    required this.statusIndex,
    required this.hasLiveDriver,
    required this.offers,
  });

  @override
  Widget build(BuildContext context) {
    const stages = ['تم الاستلام', 'مراجعة الطلب', 'قيد التنفيذ', 'مكتمل'];
    return Card(
      elevation: 8,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 17, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                if (hasLiveDriver)
                  Row(
                    children: [
                      Icon(Icons.circle, size: 9, color: Colors.green.shade600),
                      const SizedBox(width: 5),
                      Text('مباشر', style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text('رقم الطلب: ${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12)),
            const SizedBox(height: 15),
            Row(
              children: List.generate(stages.length, (index) {
                final active = index <= statusIndex;
                return Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 23,
                        height: 23,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? color : Colors.grey.shade200,
                        ),
                        child: active
                            ? const Icon(Icons.check, color: Colors.white, size: 15)
                            : null,
                      ),
                      if (index < stages.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: index < statusIndex ? color : Colors.grey.shade200,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: stages
                  .map((stage) => Text(stage, style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade600)))
                  .toList(),
            ),
            if (offers.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              const Text('عروض الشركات',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 7),
              ...offers.asMap().entries.map((entry) {
                final offer = entry.value;
                final company = offer['company'] as Map?;
                final price = (offer['offeredPrice'] as num?)?.toDouble();
                final prices = offers
                    .map((item) => (item['offeredPrice'] as num?)?.toDouble())
                    .whereType<double>();
                final lowest = prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b);
                final isBest = price != null && lowest != null && price == lowest;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isBest ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isBest ? color.withValues(alpha: 0.35) : Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(company?['companyName']?.toString() ?? 'شركة شحن')),
                      if (isBest)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: Text('الأفضل', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      Text('${price?.toStringAsFixed(2) ?? '-'} ج.م',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 54, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
