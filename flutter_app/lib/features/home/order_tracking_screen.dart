import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/services/notification_service.dart';
import '../map_trip/rating_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final bool isTrip;

  const OrderTrackingScreen({super.key, required this.orderId, this.isTrip = false});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const _defaultLocation = LatLng(30.0444, 31.2357);

  final MapController _mapController = MapController();
  socket_io.Socket? _socket;
  Timer? _refreshTimer;
  Map<String, dynamic>? _order;
  List<dynamic> _tripOffers = [];
  List<LatLng> _routePoints = [];
  LatLng? _driverLocation;
  bool _isLoading = true;
  String? _error;
  late bool _isTrip;
  bool _hasFittedBounds = false;
  bool _ratingOpened = false;

  @override
  void initState() {
    super.initState();
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
        final response = await ApiClient().dio.get('/api/trips/${widget.orderId}');
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

        if (mounted) {
          setState(() {
            _order = Map<String, dynamic>.from(trip);
            _tripOffers = offers;
            _isLoading = false;
            _error = null;
          });
          _loadRoute();
        }
        return true;
      } else {
        final response = await ApiClient().dio.get('/api/orders/${widget.orderId}');
        final order = response.data?['order'];
        if (response.statusCode != 200 || order is! Map) {
          return false;
        }

        if (mounted) {
          setState(() {
            _order = Map<String, dynamic>.from(order);
            _isLoading = false;
            _error = null;
          });
          _loadRoute();
        }
        return true;
      }
    } catch (e) {
      return false;
    }
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'رفض عرض السعر',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: const Text(
            'هل أنت متأكد من رفض السعر المقترح من شركة الشحن؟',
            style: TextStyle(color: Color(0xff94A3B8), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع', style: TextStyle(color: Color(0xff94A3B8))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                child: const Icon(Icons.close_rounded, color: Color(0xffEF4444), size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'هل أنت متأكد من إلغاء هذا الطلب؟',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('تراجع', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('تأكيد الإلغاء', style: TextStyle(fontWeight: FontWeight.bold)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    if (data is! Map || data['rideId']?.toString() != widget.orderId) return;
    NotificationService().showNotification(
      title: 'عرض سعر جديد! 💰',
      body: 'الكابتن ${data['driverName'] ?? ''} قدم عرضاً بقيمة ${data['offerAmount'] ?? ''} ج.م',
    );
    _loadOrder(silent: true);
  }

  void _handleOrderStatusChanged(dynamic data) {
    if (data is! Map || data['orderId']?.toString() != widget.orderId) return;
    final status = data['status']?.toString();
    final price = data['price'] ?? data['offerAmount'];
    if (status == 'PRICE_SENT') {
      NotificationService().showNotification(
        title: 'عرض سعر جديد لشحنتك! 🏷️',
        body: price != null ? 'وصلك عرض سعر بقيمة $price ج.م' : 'وصل عرض سعر جديد لطلبك',
      );
    } else if (status == 'COMPANY_ACCEPTED' || status == 'CONFIRMED' || status == 'CUSTOMER_APPROVED') {
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
    setState(() => _driverLocation = LatLng(lat, lng));
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
      final lat = double.tryParse(_order?['${type.toLowerCase()}Lat']?.toString() ?? '');
      final lng = double.tryParse(_order?['${type.toLowerCase()}Lng']?.toString() ?? '');
      if (lat != null && lng != null) return LatLng(lat, lng);
      return _defaultLocation;
    }
    final prefix = _order?['serviceType'] == 'SHIPPING' ? 'shipping' : 'limousine';
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
    final prefix = _order?['serviceType'] == 'SHIPPING' ? 'shipping' : 'limousine';
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
      final coordinates = response.data['routes']?[0]?['geometry']?['coordinates'];
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

  void _fitCameraBounds() {
    final pickup = _locationFor('Pickup');
    final dropoff = _locationFor('Dropoff');
    if (pickup == _defaultLocation && dropoff == _defaultLocation) return;

    final points = _routePoints.length > 1
        ? _routePoints
        : [pickup, dropoff];

    if (_driverLocation != null) {
      points.add(_driverLocation!);
    }

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
        return _isTrip ? 'جاري البحث عن سائق' : 'تم استلام الطلب وبانتظار العروض';
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

  int _statusStepIndex(String? status) {
    switch (status?.toUpperCase()) {
      case 'PRICE_SENT':
        return 1;
      case 'COMPANY_ACCEPTED':
      case 'CUSTOMER_APPROVED':
      case 'ACCEPTED':
      case 'DRIVER_ACCEPTED':
      case 'ASSIGNED':
        return 1;
      case 'ARRIVED':
      case 'CONFIRMED':
      case 'STARTED':
      case 'IN_PROGRESS':
      case 'IN_TRANSIT':
      case 'ON_THE_WAY':
        return 2;
      case 'COMPLETED':
        return 3;
      case 'CUSTOMER_REJECTED':
      case 'CANCELLED':
        return 0;
      default:
        return 0;
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
    _refreshTimer?.cancel();
    _socket?.disconnect();
    super.dispose();
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
        appBar: AppBar(
          backgroundColor: const Color(0xff111315),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            children: [
              Text(
                isShipping ? 'معاينة وتتبع الشحنة' : 'معاينة وتتبع الرحلة',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '#${widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId}',
                style: const TextStyle(
                    color: Color(0xff94A3B8),
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Color(0xffF97316), size: 22),
              onPressed: () => _loadOrder(),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xffF97316)),
              )
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _loadOrder)
                : Stack(
                    children: [
                      // Map View
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
                              // Outer Glow Layer
                              Polyline(
                                points: _routePoints.length > 1
                                    ? _routePoints
                                    : [pickup, dropoff],
                                color: const Color(0xffF97316).withOpacity(0.35),
                                strokeWidth: 9,
                              ),
                              // Core Crisp Layer
                              Polyline(
                                points: _routePoints.length > 1
                                    ? _routePoints
                                    : [pickup, dropoff],
                                color: const Color(0xffF97316),
                                strokeWidth: 4.5,
                              ),
                            ],
                          ),

                          // Markers Layer
                          MarkerLayer(
                            markers: [
                              // Pickup Marker
                              Marker(
                                point: pickup,
                                width: 50,
                                height: 50,
                                child: _buildLocationPin(
                                  icon: Icons.trip_origin_rounded,
                                  color: const Color(0xffF97316),
                                  isPickup: true,
                                ),
                              ),

                              // Dropoff Marker
                              Marker(
                                point: dropoff,
                                width: 50,
                                height: 50,
                                child: _buildLocationPin(
                                  icon: Icons.location_on_rounded,
                                  color: const Color(0xffEF4444),
                                  isPickup: false,
                                ),
                              ),

                              // Live Driver / Vehicle Marker
                              if (_driverLocation != null)
                                Marker(
                                  point: _driverLocation!,
                                  width: 54,
                                  height: 54,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xffF97316),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xffF97316)
                                              .withOpacity(0.5),
                                          blurRadius: 16,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isShipping
                                          ? Icons.local_shipping_rounded
                                          : Icons.directions_car_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // Floating Map Controls (Center Route & Zoom)
                      Positioned(
                        top: 16,
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
                          ],
                        ),
                      ),

                      // Bottom Tracking Sheet
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.56,
                          ),
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
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                const SizedBox(height: 16),

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
                                  SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: OutlinedButton.icon(
                                      onPressed: _cancelOrder,
                                      icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: Color(0xffEF4444)),
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
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildLocationPin({
    required IconData icon,
    required Color color,
    required bool isPickup,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ],
    );
  }

  Widget _buildTimeline(String? status) {
    const stages = ['تم الطلب', 'الموافقة', 'قيد التنفيذ', 'مكتمل'];
    final currentIndex = _statusStepIndex(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xff1A1D21),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xff2A2D33), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(stages.length, (index) {
              final isReached = index <= currentIndex;
              final isCurrent = index == currentIndex;

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isReached
                            ? const Color(0xffF97316)
                            : const Color(0xff2A2D33),
                        border: isCurrent
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: isReached
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 14)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                    color: Color(0xff64748B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    if (index < stages.length - 1)
                      Expanded(
                        child: Container(
                          height: 2.5,
                          color: index < currentIndex
                              ? const Color(0xffF97316)
                              : const Color(0xff2A2D33),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stages.asMap().entries.map((e) {
              final isReached = e.key <= currentIndex;
              return Text(
                e.value,
                style: TextStyle(
                  color: isReached ? Colors.white : const Color(0xff64748B),
                  fontSize: 11,
                  fontWeight:
                      isReached ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
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

  Widget _buildPartnerCard() {
    final driver = _order?['driver'] as Map?;
    final company = _order?['company'] as Map?;
    final name = driver?['name']?.toString() ??
        company?['companyName']?.toString() ??
        (_isTrip ? 'كابتن الرحلة' : 'شركة النقل المعتمدة');

    final phone = driver?['phone']?.toString() ??
        company?['companyPhone']?.toString() ??
        '';

    final car = driver?['car'] as Map?;
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xff22C55E).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isTrip ? Icons.person_rounded : Icons.business_rounded,
              color: const Color(0xff22C55E),
              size: 26,
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
                if (carDesc != null && carDesc.isNotEmpty) ...[
                  const SizedBox(height: 4),
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
        border: Border.all(color: const Color(0xffF59E0B).withOpacity(0.5), width: 1.5),
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
                      style: TextStyle(
                          color: Color(0xff94A3B8),
                          fontSize: 12),
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
                        style: TextStyle(color: Color(0xff94A3B8), fontSize: 11),
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
                  const Icon(Icons.arrow_back_rounded, color: Color(0xff94A3B8), size: 18),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'عرض الشركة الحالي:',
                      style: TextStyle(color: Color(0xffF97316), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$offerPrice ج.م',
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
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _rejectOrderPrice,
                    icon: const Icon(Icons.close_rounded, color: Color(0xffEF4444), size: 18),
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
              const SizedBox(width: 10),
              // Accept Button
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _approveOrderPrice,
                    icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xff111315),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isTrip ? Icons.person_rounded : Icons.business_rounded,
                    color: const Color(0xffF97316),
                    size: 20,
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
                      const SizedBox(height: 2),
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
                if (!isAccepted && !_isTrip && (status == 'pending' || status == 'PENDING' || status == 'PRICE_SENT' || status == null)) ...[
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xffEF4444), size: 20),
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
