import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/animations/zoon_animations.dart';
import '../map_trip/rating_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final bool isTrip;

  const OrderTrackingScreen(
      {super.key, required this.orderId, this.isTrip = false});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const _defaultLocation = LatLng(30.0444, 31.2357);

  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isSheetCollapsed = false;
  socket_io.Socket? _socket;
  Timer? _refreshTimer;
  Map<String, dynamic>? _order;
  List<dynamic> _tripOffers = [];
  List<LatLng> _routePoints = [];
  List<LatLng> _driverToPickupRoute = [];
  LatLng? _driverLocation;
  Timer? _driverMovementTimer;
  bool _isLoading = true;
  String? _error;
  late bool _isTrip;
  bool _hasFittedBounds = false;
  bool _ratingOpened = false;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(() {
      final isCollapsed =
          _sheetController.isAttached && _sheetController.size < 0.18;
      if (isCollapsed != _isSheetCollapsed && mounted) {
        setState(() {
          _isSheetCollapsed = isCollapsed;
        });
      }
    });
    _isTrip = widget.isTrip;
    _loadOrder();
    _connectSocket();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 6),
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
      bool loaded = await _fetchOrderData(_isTrip);

      if (!loaded) {
        loaded = await _fetchOrderData(!_isTrip);
        if (loaded && mounted) {
          setState(() {
            _isTrip = !_isTrip;
          });
        }
      }

      if (!loaded) {
        throw Exception('تعذر العثور على بيانات الطلب');
      }
    } catch (error) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _error = 'تعذر العثور على تفاصيل الطلب أو قد تكون انتهت صلاحيته.';
        });
      }
    }
  }

  Future<bool> _fetchOrderData(bool asTrip) async {
    try {
      if (asTrip) {
        final response =
            await ApiClient().dio.get('/api/trips/${widget.orderId}');
        final trip = response.data?['trip'] ?? response.data?['ride'];
        if (response.statusCode != 200 || trip is! Map) {
          return false;
        }

        List<dynamic> offers = [];
        try {
          final offersResponse =
              await ApiClient().dio.get('/api/trips/${widget.orderId}/offers');
          offers = offersResponse.data?['offers'] ?? [];
        } catch (_) {}

        final status = trip['status']?.toString();
        final isPartnerAccepted = _hasAcceptedPartner(status);

        if (isPartnerAccepted) {
          final driver = trip['driver'] as Map?;
          final dLat = double.tryParse(driver?['lat']?.toString() ??
              trip['driverLat']?.toString() ??
              '');
          final dLng = double.tryParse(driver?['lng']?.toString() ??
              trip['driverLng']?.toString() ??
              '');
          if (dLat != null && dLng != null) {
            _driverLocation = LatLng(dLat, dLng);
          } else if (_driverLocation == null) {
            await _loadPersistedDriverLocation(trip);
          }
        }

        if (mounted) {
          setState(() {
            _order = Map<String, dynamic>.from(trip);
            _tripOffers = offers;
            _isLoading = false;
            _error = null;
          });
          _loadRoute();
          if (isPartnerAccepted) {
            _loadDriverRoute();
          }
        }
        return true;
      } else {
        final response =
            await ApiClient().dio.get('/api/orders/${widget.orderId}');
        final order = response.data?['order'];
        if (response.statusCode != 200 || order is! Map) {
          return false;
        }

        final status = order['status']?.toString();
        final isPartnerAccepted = _hasAcceptedPartner(status);

        if (isPartnerAccepted && _driverLocation == null) {
          await _loadPersistedDriverLocation(order);
        }

        if (mounted) {
          setState(() {
            _order = Map<String, dynamic>.from(order);
            _isLoading = false;
            _error = null;
          });
          _loadRoute();
          if (isPartnerAccepted) {
            _loadDriverRoute();
          }
        }
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadPersistedDriverLocation(Map order) async {
    final driverId = order['driverId']?.toString() ??
        (order['driver'] as Map?)?['id']?.toString();
    if (driverId == null || driverId.isEmpty) return;

    try {
      final response = await ApiClient().dio.get('/api/locations');
      final locations = response.data?['locations'];
      if (locations is! List) return;
      for (final item in locations) {
        if (item is! Map || item['driverId']?.toString() != driverId) continue;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lng = double.tryParse(item['lng']?.toString() ?? '');
        if (lat != null && lng != null) {
          _driverLocation = LatLng(lat, lng);
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _acceptDriverOffer(String driverId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xffF97316)),
        ),
      );

      final response = await ApiClient().dio.post(
        '/api/trips/${widget.orderId}/accept-offer',
        data: {'driverId': driverId},
      );

      if (mounted) {
        Navigator.pop(context);
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم قبول العرض! السائق في الطريق إليك ✓'),
              backgroundColor: const Color(0xff22C55E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          _loadOrder();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل قبول العرض، حاول مرة أخرى'),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _approveOrderPrice() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xffF97316)),
        ),
      );

      final response = await ApiClient().dio.post(
            '/api/orders/${widget.orderId}/approve-price',
          );

      if (mounted) {
        Navigator.pop(context);
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تمت الموافقة على السعر بنجاح ✓'),
              backgroundColor: const Color(0xff22C55E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          _loadOrder();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشلت الموافقة على السعر، حاول مجدداً'),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _rejectOrderPrice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xff1A1D21),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'رفض عرض السعر',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: const Text(
            'هل أنت متأكد من رفض السعر المقترح من شركة الشحن؟',
            style: TextStyle(color: Color(0xff94A3B8), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع',
                  style: TextStyle(color: Color(0xff94A3B8))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('تأكيد الرفض'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xffF97316)),
        ),
      );

      final response = await ApiClient().dio.post(
        '/api/orders/${widget.orderId}/reject-price',
        data: {'reason': 'رفض العميل السعر المعروض'},
      );

      if (mounted) {
        Navigator.pop(context);
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم رفض عرض السعر بنجاح'),
              backgroundColor: const Color(0xffEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          _loadOrder();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل تسجيل الرفض، حاول مجدداً'),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xff111315),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xff4B5563),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xffEF4444).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Color(0xffEF4444), size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'هل أنت متأكد من إلغاء هذا الطلب؟',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'سيتم إلغاء الطلب وإيقاف البحث عن ناقل أو سائق.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xff94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff94A3B8),
                        side: const BorderSide(color: Color(0xff2A2D33)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('تراجع',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('تأكيد الإلغاء',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xffF97316)),
        ),
      );

      final endpoint = _isTrip
          ? '/api/trips/${widget.orderId}/cancel'
          : '/api/orders/${widget.orderId}/cancel';

      await ApiClient().dio.post(endpoint);

      if (mounted) {
        nav.pop(); // Close loading
        messenger.showSnackBar(
          SnackBar(
            content: const Text('تم إلغاء الطلب'),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadOrder();
      }
    } catch (_) {
      if (mounted) {
        nav.pop();
        messenger.showSnackBar(
          SnackBar(
            content: const Text('تعذر إلغاء الطلب، يرجى المحاولة لاحقاً'),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
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
    _socket!.on('order_status_changed', _handleOrderStatusChanged);
    _socket!.on('trip_status_changed', _handleOrderUpdate);
    _socket!.on('driver_accepted', _handleDriverAccepted);
    _socket!.on('driver_offer', _handleNewOffer);
  }

  void _handleDriverAccepted(dynamic data) {
    if (data is! Map ||
        (data['rideId']?.toString() != widget.orderId &&
            data['tripId']?.toString() != widget.orderId)) {
      return;
    }
    NotificationService().showNotification(
      id: 22,
      title: 'تم قبول الرحلة!',
      body: 'قبل السائق طلب رحلتك وهو في الطريق إليك الآن',
    );
    _loadOrder(silent: true);
  }

  void _handleNewOffer(dynamic data) {
    if (data is! Map) return;
    final rId =
        (data['rideId'] ?? data['tripId'] ?? data['orderId'])?.toString();
    if (rId != null && rId != widget.orderId) return;

    final driverName = data['driverName']?.toString() ?? 'كابتن';
    final offerAmount = data['offerAmount'] ?? data['price'] ?? '';

    NotificationService().showNotification(
      title: 'عرض سعر جديد! 💰',
      body: 'الكابتن $driverName قدم عرضاً بقيمة $offerAmount ج.م',
    );

    if (mounted) {
      setState(() {
        final existingIdx = _tripOffers.indexWhere(
          (o) =>
              o is Map &&
              o['driverId']?.toString() == data['driverId']?.toString(),
        );
        if (existingIdx >= 0) {
          _tripOffers[existingIdx] = Map<String, dynamic>.from(data);
        } else {
          _tripOffers.add(Map<String, dynamic>.from(data));
        }
      });
    }

    _loadOrder(silent: true);
  }

  void _handleOrderStatusChanged(dynamic data) {
    if (data is! Map || data['orderId']?.toString() != widget.orderId) return;
    final status = data['status']?.toString();
    final price = data['price'] ?? data['offerAmount'];

    if (status != null && mounted) {
      setState(() {
        _order = {
          ...?_order,
          'status': status,
          if (price != null) 'finalPrice': price,
        };
      });
    }

    if (status == 'PRICE_SENT') {
      NotificationService().showNotification(
        title: 'عرض سعر جديد لشحنتك! 🏷️',
        body: price != null
            ? 'وصلك عرض سعر بقيمة $price ج.م'
            : 'وصل عرض سعر جديد لطلبك',
      );
    } else if (status == 'COMPANY_ACCEPTED' ||
        status == 'CONFIRMED' ||
        status == 'CUSTOMER_APPROVED') {
      NotificationService().showNotification(
        title: 'تم قبول وتأكيد الطلب! 🚚',
        body: 'تم قبول طلب الشحن الخاص بك وجاري تجهيز التوصيل',
      );
    } else if (status == 'COMPANY_REJECTED') {
      NotificationService().showNotification(
        title: 'تم رفض طلب الشحن ✕',
        body: data['reason']?.toString() ?? 'تم رفض الطلب من قبل شركة الشحن',
      );
    } else if (status == 'IN_PROGRESS') {
      NotificationService().showNotification(
        title: 'الشحنة قيد التوصيل! 📦💨',
        body: 'الشحنة الآن في الطريق إلى نقطة التسليم',
      );
    } else if (status == 'COMPLETED') {
      NotificationService().showNotification(
        title: 'تم تسليم الشحنة بنجاح! 📦✅',
        body: 'تم إيصال طلبك بنجاح. شكراً لاختيارك زوون',
      );
    } else if (status == 'CANCELLED') {
      NotificationService().showNotification(
        title: 'تم إلغاء الطلب ⚠️',
        body: 'تم إلغاء طلب الشحن',
      );
    }
    _loadOrder(silent: true);
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
    _driverMovementTimer?.cancel();
    setState(() => _driverLocation = LatLng(lat, lng));
    _loadDriverRoute();
  }

  void _handleOrderUpdate(dynamic data) {
    if (data is! Map ||
        (data['rideId']?.toString() != widget.orderId &&
            data['orderId']?.toString() != widget.orderId)) {
      return;
    }
    final status = data['status']?.toString();
    if (status != null && mounted) {
      if (status == 'driver_arriving') {
        NotificationService().showNotification(
          title: 'الكابتن يقترب منك! 📍',
          body: 'الكابتن على وشك الوصول لنقطة الركوب',
        );
      } else if (status == 'driver_arrived') {
        NotificationService().showNotification(
          title: 'الكابتن وصل! 🏁',
          body: 'الكابتن ينتظرك في نقطة الركوب',
        );
      } else if (status == 'started' || status == 'in_progress') {
        NotificationService().showNotification(
          title: 'بدأت الرحلة 🛣️',
          body: 'الرحلة جارية الآن، نتمنى لك رحلة آمنة ومريحة',
        );
      } else if (status == 'completed') {
        NotificationService().showNotification(
          title: 'اكتملت الرحلة بنجاح! ✅',
          body: 'وصلت لوجهتك بسلام، حمداً لله على سلامتك',
        );
      } else if (status == 'cancelled') {
        NotificationService().showNotification(
          title: 'تم إلغاء الرحلة ❌',
          body: 'تم إلغاء الطلب',
        );
      }
      setState(() {
        _order = {...?_order, 'status': status};
      });
      _loadOrder(silent: true);
      if (status == 'completed' && _isTrip) {
        _openRatingScreen();
      }
    }
  }

  void _openRatingScreen() {
    if (_ratingOpened || !mounted) return;
    _ratingOpened = true;
    final driver = _order?['driver'] as Map?;
    final driverName = driver?['name']?.toString() ??
        _order?['driverName']?.toString() ??
        'الكابتن';
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RatingScreen(
          tripId: widget.orderId,
          driverName: driverName,
        ),
      ),
    );
  }

  LatLng _locationFor(String type) {
    if (_isTrip) {
      final lat = double.tryParse(
          _order?['${type.toLowerCase()}Lat']?.toString() ?? '');
      final lng = double.tryParse(
          _order?['${type.toLowerCase()}Lng']?.toString() ?? '');
      if (lat != null && lng != null) return LatLng(lat, lng);
      return _defaultLocation;
    }
    final prefix =
        _order?['serviceType'] == 'SHIPPING' ? 'shipping' : 'limousine';
    final lat = double.tryParse(_order?['$prefix${type}Lat']?.toString() ?? '');
    final lng = double.tryParse(_order?['$prefix${type}Lng']?.toString() ?? '');
    if (lat == null || lng == null) return _defaultLocation;
    return LatLng(lat, lng);
  }

  String _addressFor(String type) {
    if (_isTrip) {
      return _order?['${type.toLowerCase()}Address']?.toString() ??
          (type == 'Pickup' ? 'نقطة الانطلاق' : 'نقطة الوصول');
    }
    final prefix =
        _order?['serviceType'] == 'SHIPPING' ? 'shipping' : 'limousine';
    return _order?['$prefix${type}Address']?.toString() ??
        (type == 'Pickup' ? 'نقطة الانطلاق' : 'نقطة الوصول');
  }

  Future<void> _loadRoute() async {
    if (_order == null) return;
    final pickup = _locationFor('Pickup');
    final dropoff = _locationFor('Dropoff');
    if (pickup == _defaultLocation || dropoff == _defaultLocation) return;

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final response = await dio.get(
        'https://router.project-osrm.org/route/v1/driving/${pickup.longitude},${pickup.latitude};${dropoff.longitude},${dropoff.latitude}',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );
      final coordinates =
          response.data['routes']?[0]?['geometry']?['coordinates'];
      if (coordinates is List && mounted) {
        final points = coordinates
            .whereType<List>()
            .where((point) => point.length >= 2)
            .map((point) => LatLng(
                  (point[1] as num).toDouble(),
                  (point[0] as num).toDouble(),
                ))
            .toList();
        if (points.length > 1) {
          setState(() => _routePoints = points);
        }
      }
    } catch (_) {
      // Fallback: draw direct connection
    }

    if (!_hasFittedBounds && mounted) {
      _hasFittedBounds = true;
      Future.delayed(const Duration(milliseconds: 300), _fitCameraBounds);
    }
  }

  Future<void> _loadDriverRoute() async {
    final pickup = _locationFor('Pickup');
    if (_driverLocation == null || pickup == _defaultLocation) return;

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final response = await dio.get(
        'https://router.project-osrm.org/route/v1/driving/${_driverLocation!.longitude},${_driverLocation!.latitude};${pickup.longitude},${pickup.latitude}',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );
      final coordinates =
          response.data['routes']?[0]?['geometry']?['coordinates'];
      if (coordinates is List && mounted) {
        final points = coordinates
            .whereType<List>()
            .where((point) => point.length >= 2)
            .map((point) => LatLng(
                  (point[1] as num).toDouble(),
                  (point[0] as num).toDouble(),
                ))
            .toList();
        if (points.length > 1) {
          setState(() {
            _driverToPickupRoute = points;
          });
          _fitCameraBounds();
        }
      }
    } catch (_) {
      if (mounted && _driverToPickupRoute.isEmpty) {
        setState(() {
          _driverToPickupRoute = [_driverLocation!, pickup];
        });
        _fitCameraBounds();
      }
    }
  }

  void _fitCameraBounds() {
    final pickup = _locationFor('Pickup');
    final dropoff = _locationFor('Dropoff');
    if (pickup == _defaultLocation && dropoff == _defaultLocation) return;

    final status = _order?['status']?.toString();
    final isPartnerAccepted = _hasAcceptedPartner(status);

    final List<LatLng> points = [];

    if (isPartnerAccepted && status != 'started' && status != 'completed') {
      // Focus on driver coming to pickup
      if (_driverToPickupRoute.isNotEmpty) {
        points.addAll(_driverToPickupRoute);
      } else {
        if (_driverLocation != null) points.add(_driverLocation!);
        points.add(pickup);
      }
    } else {
      if (_routePoints.isNotEmpty) {
        points.addAll(_routePoints);
      } else {
        points.addAll([pickup, dropoff]);
      }
      if (_driverLocation != null) {
        points.add(_driverLocation!);
      }
    }

    if (points.isEmpty) return;

    try {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(48, 80, 48, 280),
        ),
      );
    } catch (_) {}
  }

  String _statusTitle(String? status) {
    switch (status?.toUpperCase()) {
      case 'NEW':
      case 'REQUESTED':
      case 'PENDING':
        return _isTrip
            ? 'جاري البحث عن سائق'
            : 'تم استلام الطلب وبانتظار العروض';
      case 'PRICE_SENT':
        return 'وصلك عرض سعر جديد من الشركة!';
      case 'COMPANY_ACCEPTED':
        return 'تم قبول الطلب من الشركة!';
      case 'CUSTOMER_APPROVED':
        return 'تمت الموافقة على السعر ✓';
      case 'CUSTOMER_REJECTED':
        return 'تم رفض عرض السعر';
      case 'ACCEPTED':
      case 'DRIVER_ACCEPTED':
      case 'ASSIGNED':
        return 'تم قبول الرحلة من السائق!';
      case 'ARRIVED':
        return 'وصل السائق إلى موقعك';
      case 'CONFIRMED':
        return 'الطلب مؤكد وجاري التجهيز';
      case 'STARTED':
      case 'IN_PROGRESS':
      case 'IN_TRANSIT':
      case 'ON_THE_WAY':
        return _isTrip ? 'الرحلة قيد التنفيذ الآن' : 'الشحنة في الطريق';
      case 'COMPLETED':
        return 'اكتملت العملية بنجاح';
      case 'CANCELLED':
        return 'تم إلغاء الطلب';
      default:
        return 'متابعة حالة الطلب';
    }
  }

  String _statusSubtitle(String? status) {
    switch (status?.toUpperCase()) {
      case 'NEW':
      case 'REQUESTED':
      case 'PENDING':
        return 'طلبك مرئي للشركات والسائقين المتاحين حالياً';
      case 'PRICE_SENT':
        return 'قامت الشركة بتقديم سعر مقترح، يرجى القبول أو الرفض للمتابعة';
      case 'COMPANY_ACCEPTED':
        return 'الشركة وافقت على الطلب وبدأت بالتجهيز';
      case 'CUSTOMER_APPROVED':
        return 'تم اعتماد السعر بنجاح وجاري البدء في تنفيذ الشحنة';
      case 'CUSTOMER_REJECTED':
        return 'تم رفض السعر المقترح من قبلك';
      case 'ACCEPTED':
      case 'DRIVER_ACCEPTED':
      case 'ASSIGNED':
        return 'السائق في طريقه إلى نقطة الانطلاق الآن';
      case 'ARRIVED':
        return 'السائق ينتظرك في نقطة الالتقاء المحددة';
      case 'CONFIRMED':
        return 'تم تأكيد جميع التفاصيل وجاري التنفيذ';
      case 'STARTED':
      case 'IN_PROGRESS':
      case 'IN_TRANSIT':
      case 'ON_THE_WAY':
        return 'يمكنك متابعة خط السير المباشر على الخريطة';
      case 'COMPLETED':
        return 'تم تسليم الطلب بنجاح، شكراً لاختيارك لنا';
      case 'CANCELLED':
        return 'تم إغلاق هذا الطلب ولا توجد إجراءات أخرى';
      default:
        return 'جاري مزامنة بيانات الطلب...';
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PRICE_SENT':
        return const Color(0xffF59E0B);
      case 'CUSTOMER_REJECTED':
        return const Color(0xffEF4444);
      case 'COMPANY_ACCEPTED':
      case 'CUSTOMER_APPROVED':
      case 'ACCEPTED':
      case 'DRIVER_ACCEPTED':
      case 'ASSIGNED':
      case 'ARRIVED':
      case 'STARTED':
      case 'IN_PROGRESS':
      case 'IN_TRANSIT':
      case 'ON_THE_WAY':
        return const Color(0xff22C55E);
      case 'COMPLETED':
        return const Color(0xff10B981);
      case 'CANCELLED':
        return const Color(0xffEF4444);
      default:
        return const Color(0xffF97316);
    }
  }

  bool _isCancellable(String? status) {
    final s = status?.toUpperCase();
    return s == 'NEW' ||
        s == 'REQUESTED' ||
        s == 'PENDING' ||
        s == 'PRICE_SENT' ||
        s == 'COMPANY_ACCEPTED';
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _refreshTimer?.cancel();
    _driverMovementTimer?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

  void _toggleSheet() {
    if (_sheetController.isAttached) {
      if (_sheetController.size > 0.18) {
        _sheetController.animateTo(
          0.08,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        );
      } else {
        _sheetController.animateTo(
          0.52,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isShipping = _order?['serviceType'] == 'SHIPPING';
    final pickup = _locationFor('Pickup');
    final dropoff = _locationFor('Dropoff');
    final centerPos = _driverLocation ?? pickup;
    final status = _order?['status']?.toString();
    final statusColor = _statusColor(status);

    final List<Map<String, dynamic>> offers = _isTrip
        ? _tripOffers
            .whereType<Map>()
            .map((o) => Map<String, dynamic>.from(o))
            .toList()
        : (_order?['priceOffers'] as List? ?? [])
            .whereType<Map>()
            .map((offer) => Map<String, dynamic>.from(offer))
            .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0A0A0A),
        body: _isLoading
            ? ZoonDispatchLoadingScreen(
                isShipping: !_isTrip,
                onBack: () => Navigator.of(context).pop(),
              )
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _loadOrder)
                : Stack(
                    children: [
                      // Map View (Extends under entire status bar)
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: centerPos,
                          initialZoom: 13.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.zoon.app',
                            tileProvider: CancellableNetworkTileProvider(),
                          ),

                          // Route Polyline (Multi-layer)
                          PolylineLayer(
                            polylines: [
                              // Driver Approach Route (Driver -> Pickup - "السواق جايله")
                              if (_driverToPickupRoute.length > 1) ...[
                                Polyline(
                                  points: _driverToPickupRoute,
                                  color:
                                      const Color(0xff22C55E).withOpacity(0.35),
                                  strokeWidth: 9,
                                ),
                                Polyline(
                                  points: _driverToPickupRoute,
                                  color: const Color(0xff22C55E),
                                  strokeWidth: 5,
                                ),
                              ],

                              // Trip Destination Route (Pickup -> Dropoff)
                              if (_routePoints.length > 1 ||
                                  (!_hasAcceptedPartner(status) &&
                                      pickup != _defaultLocation &&
                                      dropoff != _defaultLocation)) ...[
                                Polyline(
                                  points: _routePoints.length > 1
                                      ? _routePoints
                                      : [pickup, dropoff],
                                  color: const Color(0xffF97316).withOpacity(
                                      _hasAcceptedPartner(status)
                                          ? 0.35
                                          : 0.35),
                                  strokeWidth:
                                      _hasAcceptedPartner(status) ? 6 : 9,
                                ),
                                Polyline(
                                  points: _routePoints.length > 1
                                      ? _routePoints
                                      : [pickup, dropoff],
                                  color: _hasAcceptedPartner(status)
                                      ? const Color(0xffF97316).withOpacity(0.8)
                                      : const Color(0xffF97316),
                                  strokeWidth:
                                      _hasAcceptedPartner(status) ? 3.5 : 4.5,
                                ),
                              ],
                            ],
                          ),

                          // Markers Layer
                          MarkerLayer(
                            markers: [
                              // Pickup Marker (Animated radar sweep when searching, GPS beacon when accepted)
                              Marker(
                                point: pickup,
                                width: _hasAcceptedPartner(status) ? 54 : 96,
                                height: _hasAcceptedPartner(status) ? 54 : 96,
                                child: _hasAcceptedPartner(status)
                                    ? const GpsRadarMarker(
                                        color: Color(0xff22C55E),
                                        size: 54,
                                        icon: Icons.person_pin_circle_rounded,
                                      )
                                    : const AnimatedSearchingRadarPin(
                                        color: Color(0xffF97316),
                                        size: 96,
                                      ),
                              ),

                              // Dropoff Marker (Animated spring pin drop)
                              Marker(
                                point: dropoff,
                                width: 54,
                                height: 60,
                                child: const AnimatedPinDropMarker(
                                  icon: Icons.flag_rounded,
                                  color: Color(0xffEF4444),
                                  size: 44,
                                ),
                              ),

                              // Live Driver / Vehicle Marker ("السواق جايله")
                              if (_driverLocation != null &&
                                  _hasAcceptedPartner(status))
                                Marker(
                                  point: _driverLocation!,
                                  width: 80,
                                  height: 80,
                                  child: _buildDriverVehicleMarker(isShipping),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // Floating Top Header Bar ("معاينة وتتبع الرحلة" كلمة طايرة كدا وباقي الشاشة خريطة)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 10,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Floating Circular Back Button
                            _buildFloatingBackButton(),

                            // Floating Capsule Badge ("كلمة طايرة كدا")
                            _buildFloatingHeaderBadge(isShipping),

                            // Invisible spacer of identical width (44px) for symmetrical centering
                            const SizedBox(width: 44),
                          ],
                        ),
                      ),

                      // Floating Map Controls (Center Route & Zoom)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 68,
                        left: 16,
                        child: Column(
                          children: [
                            _buildFloatingMapButton(
                              icon: Icons.center_focus_strong_rounded,
                              onTap: _fitCameraBounds,
                              tooltip: 'ضبط المسار',
                            ),
                            const SizedBox(height: 8),
                            _buildFloatingMapButton(
                              icon: Icons.add_rounded,
                              onTap: () {
                                _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom + 1,
                                );
                              },
                              tooltip: 'تكبير',
                            ),
                            const SizedBox(height: 8),
                            _buildFloatingMapButton(
                              icon: Icons.remove_rounded,
                              onTap: () {
                                _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom - 1,
                                );
                              },
                              tooltip: 'تصغير',
                            ),
                            const SizedBox(height: 8),
                            _buildFloatingMapButton(
                              icon: _isSheetCollapsed
                                  ? Icons.receipt_long_rounded
                                  : Icons.map_rounded,
                              onTap: _toggleSheet,
                              tooltip: _isSheetCollapsed
                                  ? 'إظهار تفاصيل الرحلة'
                                  : 'عرض الخريطة كاملة',
                            ),
                          ],
                        ),
                      ),

                      // Bottom Tracking Sheet (Draggable & Collapsible to reveal full map)
                      DraggableScrollableSheet(
                        controller: _sheetController,
                        initialChildSize: 0.52,
                        minChildSize: 0.08,
                        maxChildSize: 0.88,
                        snap: true,
                        snapSizes: const [0.08, 0.52, 0.88],
                        builder: (context, scrollController) {
                          return Container(
                            decoration: const BoxDecoration(
                              color: Color(0xff111315),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black87,
                                  blurRadius: 28,
                                  offset: Offset(0, -6),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              controller: scrollController,
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Interactive Handle Bar (Tap to toggle collapse / expand)
                                  GestureDetector(
                                    onTap: _toggleSheet,
                                    behavior: HitTestBehavior.opaque,
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: const Color(0xff4B5563),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _isSheetCollapsed
                                                    ? Icons.keyboard_arrow_up_rounded
                                                    : Icons.keyboard_arrow_down_rounded,
                                                color: const Color(0xff9CA3AF),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _isSheetCollapsed
                                                    ? 'اسحب أو اضغط لعرض تفاصيل الرحلة والعروض ⬆️'
                                                    : 'اسحب لأسفل لتكبير الخريطة بالكامل 🗺️',
                                                style: const TextStyle(
                                                  color: Color(0xff9CA3AF),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                // Status Header
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        status == 'COMPLETED'
                                            ? Icons.check_circle_rounded
                                            : status == 'CANCELLED'
                                                ? Icons.cancel_rounded
                                                : Icons.local_shipping_rounded,
                                        color: statusColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _statusTitle(status),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _statusSubtitle(status),
                                            style: const TextStyle(
                                              color: Color(0xff94A3B8),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_driverLocation != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xff22C55E)
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xff22C55E)
                                                .withOpacity(0.4),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.circle,
                                                size: 7,
                                                color: Color(0xff22C55E)),
                                            SizedBox(width: 4),
                                            Text(
                                              'تتبع مباشر',
                                              style: TextStyle(
                                                color: Color(0xff22C55E),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 18),

                                // Timeline Progress Steps
                                _buildTimeline(status),

                                if (_hasAcceptedPartner(status) &&
                                    status != 'COMPLETED' &&
                                    status != 'CANCELLED') ...[
                                  const SizedBox(height: 14),
                                  ZoonDeliveryVehicleAnimation(
                                    height: 85,
                                    statusLabel: isShipping
                                        ? 'الشحنة في طريقها إليك'
                                        : 'الكابتن متوجه إليك الآن',
                                    subtitle: 'تتبع حركة المركبة مباشرة على الخريطة',
                                  ),
                                ] else if (status != 'COMPLETED' &&
                                    status != 'CANCELLED') ...[
                                  const SizedBox(height: 14),
                                  ZoonLuxuryVehicleVisualizer(
                                    vehicleType: isShipping
                                        ? ZoonVehicleType.halfTruck
                                        : ZoonVehicleType.limousine,
                                    height: 120,
                                    title: isShipping
                                        ? 'أسطول النقل والشحن في حالة ترقب'
                                        : 'رادار كباتن زوون VIP نشط',
                                    subtitle: 'جاري البحث عن كابتن متاح في منطقتك 📡',
                                    primaryColor: isShipping
                                        ? const Color(0xff06B6D4)
                                        : const Color(0xffF97316),
                                    underglowColor: isShipping
                                        ? const Color(0xff06B6D4)
                                        : const Color(0xffF97316),
                                  ),
                                ],

                                const SizedBox(height: 18),

                                // Accepted Partner Card (Driver or Company)
                                if (_hasAcceptedPartner(status))
                                  _buildPartnerCard(),

                                // Route details card (Addresses & Fare)
                                _buildRouteCard(
                                  pickupAddress: _addressFor('Pickup'),
                                  dropoffAddress: _addressFor('Dropoff'),
                                  price: _extractPrice(),
                                ),

                                // Counter Offer Alert Card (if PRICE_SENT)
                                if (status == 'PRICE_SENT' &&
                                    _order?['companyOfferPrice'] != null)
                                  _buildPriceOfferBanner(),

                                // Offers List
                                if (offers.isNotEmpty &&
                                    status != 'CONFIRMED' &&
                                    status != 'COMPLETED' &&
                                    status != 'CANCELLED')
                                  _buildOffersSection(offers),

                                const SizedBox(height: 16),

                                // Cancel button
                                if (_isCancellable(status))
                                  PressableScale(
                                    scaleFactor: 0.97,
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 46,
                                      child: OutlinedButton.icon(
                                        onPressed: _cancelOrder,
                                        icon: const Icon(Icons.close_rounded,
                                            size: 18, color: Color(0xffEF4444)),
                                        label: const Text(
                                          'إلغاء هذا الطلب',
                                          style: TextStyle(
                                            color: Color(0xffEF4444),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: Color(0xff3B1818)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                        },
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFloatingMapButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xff111315).withOpacity(0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xff2A2D33), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildFloatingBackButton() {
    return PressableScale(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xff111315).withOpacity(0.88),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingHeaderBadge(bool isShipping) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xff111315).withOpacity(0.88),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xffF97316).withOpacity(0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xff22C55E),
              boxShadow: [
                BoxShadow(
                  color: Color(0xff22C55E),
                  blurRadius: 6,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isShipping ? 'معاينة وتتبع الشحنة' : 'معاينة وتتبع الرحلة',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverVehicleMarker(bool isShipping) {
    final driver = _order?['driver'] as Map?;
    final driverName = driver?['name']?.toString() ??
        _order?['driverName']?.toString() ??
        'الكابتن';

    return AnimatedGlidingVehicleMarker(
      driverName: driverName,
      isShipping: isShipping,
      heading: _calculateDriverHeading(),
      themeColor: const Color(0xff22C55E),
    );
  }

  double _calculateDriverHeading() {
    final rawHeading =
        (_order?['driver']?['heading'] ?? _order?['driverHeading']);
    if (rawHeading is num) return rawHeading.toDouble();
    if (_driverLocation != null && _driverToPickupRoute.length >= 2) {
      final p1 = _driverToPickupRoute.first;
      final p2 = _driverToPickupRoute[1];
      final dy = p2.latitude - p1.latitude;
      final dx = (p2.longitude - p1.longitude) * 0.86;
      final rad = math.atan2(dx, dy);
      return (rad * 180 / math.pi) % 360;
    }
    return 0.0;
  }

  Widget _buildTimeline(String? status) {
    final isShipping = _order?['serviceType'] == 'SHIPPING';
    return LogisticsTimelineStepper(
      currentStatus: status,
      isShipping: isShipping,
      primaryColor: const Color(0xffF97316),
    );
  }

  bool _hasAcceptedPartner(String? status) {
    final s = status?.toUpperCase();
    return s == 'COMPANY_ACCEPTED' ||
        s == 'ACCEPTED' ||
        s == 'DRIVER_ACCEPTED' ||
        s == 'ASSIGNED' ||
        s == 'ARRIVED' ||
        s == 'CONFIRMED' ||
        s == 'STARTED' ||
        s == 'IN_PROGRESS' ||
        s == 'IN_TRANSIT' ||
        s == 'ON_THE_WAY';
  }

  Widget _buildAvatar(String? imageSource,
      {double size = 44, bool isTrip = true}) {
    if (imageSource != null && imageSource.trim().isNotEmpty) {
      final cleanSource = imageSource.trim();
      if (cleanSource.startsWith('http://') ||
          cleanSource.startsWith('https://')) {
        return ClipOval(
          child: Image.network(
            cleanSource,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackAvatar(size, isTrip),
          ),
        );
      } else {
        try {
          final base64String = cleanSource.contains(',')
              ? cleanSource.split(',').last.trim()
              : cleanSource;
          final bytes = base64Decode(base64String);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackAvatar(size, isTrip),
            ),
          );
        } catch (_) {
          return _buildFallbackAvatar(size, isTrip);
        }
      }
    }
    return _buildFallbackAvatar(size, isTrip);
  }

  Widget _buildFallbackAvatar(double size, bool isTrip) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isTrip
            ? const Color(0xffF97316).withOpacity(0.15)
            : const Color(0xff22C55E).withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          isTrip ? Icons.person_rounded : Icons.business_rounded,
          color: isTrip ? const Color(0xffF97316) : const Color(0xff22C55E),
          size: size * 0.55,
        ),
      ),
    );
  }

  Widget _buildPartnerCard() {
    final driver = _order?['driver'] as Map?;
    final company = _order?['company'] as Map?;
    final name = driver?['name']?.toString() ??
        _order?['driverName']?.toString() ??
        company?['companyName']?.toString() ??
        (_isTrip ? 'كابتن الرحلة' : 'شركة النقل المعتمدة');

    final phone = driver?['phone']?.toString() ??
        _order?['driverPhone']?.toString() ??
        company?['companyPhone']?.toString() ??
        '';

    final driverImage = driver?['profileImage']?.toString() ??
        driver?['driverImage']?.toString() ??
        _order?['driverImage']?.toString();

    final rating =
        (driver?['rating'] ?? _order?['driverRating'] as num?)?.toDouble() ??
            5.0;
    final totalRatings =
        (driver?['totalRatings'] ?? _order?['driverTotalRatings'] as num?)
                ?.toInt() ??
            0;

    final car = (driver?['car'] ?? _order?['car']) as Map?;
    final carDesc = car != null
        ? '${car['model'] ?? ''} ${car['color'] ?? ''} (${car['plateNumber'] ?? ''})'
            .trim()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff1A1D21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff22C55E).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xff22C55E),
                width: 2,
              ),
            ),
            child: _buildAvatar(
              driverImage,
              size: 46,
              isTrip: _isTrip,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded,
                        color: Color(0xff22C55E), size: 16),
                  ],
                ),
                if (_isTrip) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xffFBBF24), size: 16),
                      const SizedBox(width: 3),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xffFBBF24),
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (totalRatings > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '($totalRatings تقييم)',
                          style: const TextStyle(
                            color: Color(0xff94A3B8),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (carDesc != null && carDesc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    carDesc,
                    style: const TextStyle(
                      color: Color(0xff94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (phone.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xff22C55E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.phone_rounded,
                    color: Colors.white, size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('رقم الهاتف: $phone'),
                      backgroundColor: const Color(0xff111315),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteCard({
    required String pickupAddress,
    required String dropoffAddress,
    required String price,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff1A1D21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff2A2D33), width: 1),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.trip_origin_rounded,
                      color: Color(0xffF97316), size: 18),
                  Container(
                    width: 2,
                    height: 28,
                    color: const Color(0xff2A2D33),
                  ),
                  const Icon(Icons.location_on_rounded,
                      color: Color(0xffEF4444), size: 18),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickupAddress,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      dropoffAddress,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (price.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xff2A2D33), height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'قيمة المشوار / الشحن:',
                  style: TextStyle(color: Color(0xff94A3B8), fontSize: 13),
                ),
                Text(
                  '$price ج.م',
                  style: const TextStyle(
                    color: Color(0xffF97316),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceOfferBanner() {
    final offerPrice = _order?['companyOfferPrice']?.toString() ?? '';
    final initialPrice = _order?['customerOfferPrice']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff1A1713),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xffF59E0B).withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffF59E0B).withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xffF59E0B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_offer_rounded,
                    color: Color(0xffF59E0B), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عرض سعر جديد من شركة الشحن!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'قامت شركة النقل باقتراح سعر جديد لتنفيذ شحنتك',
                      style: TextStyle(color: Color(0xff94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xff111315),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff2A2D33)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (initialPrice.isNotEmpty) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'سعرك المقترح:',
                        style:
                            TextStyle(color: Color(0xff94A3B8), fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$initialPrice ج.م',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Color(0xffEF4444),
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_back_rounded,
                      color: Color(0xff94A3B8), size: 18),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'عرض الشركة الحالي:',
                      style: TextStyle(
                          color: Color(0xffF97316),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    AnimatedCounterText(
                      value: double.tryParse(offerPrice) ?? 0,
                      suffix: 'ج.م',
                      style: const TextStyle(
                        color: Color(0xffF97316),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Reject Button
              Expanded(
                flex: 2,
                child: PressableScale(
                  scaleFactor: 0.96,
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _rejectOrderPrice,
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xffEF4444), size: 18),
                      label: const Text(
                        'رفض العرض',
                        style: TextStyle(
                          color: Color(0xffEF4444),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xffEF4444)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Accept Button
              Expanded(
                flex: 3,
                child: PressableScale(
                  scaleFactor: 0.96,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _approveOrderPrice,
                      icon: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18),
                      label: const Text(
                        'قبول السعر',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff22C55E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOffersSection(List<Map<String, dynamic>> offers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isTrip ? 'عروض السائقين المتاحة' : 'عروض الشركات المتاحة',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xffF97316).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${offers.length} عروض',
                style: const TextStyle(
                  color: Color(0xffF97316),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...offers.map((offer) {
          final name = _isTrip
              ? (offer['driverName']?.toString() ?? 'كابتن')
              : ((offer['company'] as Map?)?['companyName']?.toString() ??
                  'شركة نقل');
          final price = _isTrip
              ? (offer['offerAmount'] as num?)?.toDouble()
              : (offer['offeredPrice'] as num?)?.toDouble();
          final status = offer['status']?.toString();
          final isAccepted =
              status == 'accepted' || status == 'CUSTOMER_APPROVED';
          final driverImage = offer['driverImage']?.toString() ??
              offer['profileImage']?.toString();
          final rating = (offer['rating'] as num?)?.toDouble() ?? 5.0;
          final totalRatings = (offer['totalRatings'] as num?)?.toInt() ?? 0;

          if (!isAccepted && _isTrip && status == 'pending') {
            return AnimatedOfferCard(
              driverName: name,
              price: price ?? 0.0,
              rating: rating,
              totalRatings: totalRatings,
              carDescription: offer['vehicleModel']?.toString() ??
                  offer['carModel']?.toString(),
              driverImage: driverImage,
              onAccept: () => _acceptDriverOffer(offer['driverId'].toString()),
            );
          }

          if (!isAccepted &&
              !_isTrip &&
              (status == 'pending' ||
                  status == 'PENDING' ||
                  status == 'PRICE_SENT' ||
                  status == null)) {
            return AnimatedOfferCard(
              driverName: name,
              price: price ?? 0.0,
              rating: rating,
              totalRatings: totalRatings,
              carDescription: 'عرض تسعيرة لنقل الشحنة',
              driverImage: driverImage,
              onAccept: _approveOrderPrice,
              onReject: _rejectOrderPrice,
            );
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xff1A1D21),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isAccepted
                    ? const Color(0xff22C55E)
                    : const Color(0xff2A2D33),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isAccepted
                          ? const Color(0xff22C55E)
                          : const Color(0xffF97316).withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: _buildAvatar(
                    driverImage,
                    size: 40,
                    isTrip: _isTrip,
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
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isTrip) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xffFBBF24), size: 15),
                            const SizedBox(width: 3),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Color(0xffFBBF24),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (totalRatings > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '($totalRatings تقييم)',
                                style: const TextStyle(
                                  color: Color(0xff94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        '${price?.toStringAsFixed(0) ?? '-'} ج.م',
                        style: const TextStyle(
                          color: Color(0xffF97316),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isAccepted && _isTrip && status == 'pending')
                  ElevatedButton(
                    onPressed: () =>
                        _acceptDriverOffer(offer['driverId'].toString()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffF97316),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      minimumSize: const Size(60, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('قبول',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                if (!isAccepted &&
                    !_isTrip &&
                    (status == 'pending' ||
                        status == 'PENDING' ||
                        status == 'PRICE_SENT' ||
                        status == null)) ...[
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xffEF4444), size: 20),
                    tooltip: 'رفض العرض',
                    onPressed: _rejectOrderPrice,
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: _approveOrderPrice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      minimumSize: const Size(56, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('قبول',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
                if (isAccepted)
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Color(0xff22C55E), size: 18),
                      SizedBox(width: 4),
                      Text(
                        'تم القبول',
                        style: TextStyle(
                            color: Color(0xff22C55E),
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _extractPrice() {
    final finalP = _order?['finalPrice'] ?? _order?['finalFare'];
    if (finalP != null && finalP.toString().isNotEmpty) {
      return finalP.toString();
    }
    final proposedP = _order?['customerOfferPrice'] ??
        _order?['proposedFare'] ??
        _order?['fareEstimate'];
    if (proposedP != null && proposedP.toString().isNotEmpty) {
      return proposedP.toString();
    }
    return '';
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xff1A1D21),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xff2A2D33)),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                size: 34,
                color: Color(0xffF97316),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xff94A3B8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 180,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffF97316),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'العودة للرئيسية',
                style: TextStyle(
                  color: Color(0xff64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
