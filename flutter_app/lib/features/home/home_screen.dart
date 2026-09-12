import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/location_service.dart';
import '../notifications/notifications_screen.dart';
import '../auth/auth_service.dart';
import 'order_tracking_screen.dart';
import 'customer_drawer.dart';

class HomeScreen extends StatefulWidget {
  final String initialService;
  final bool showServiceSelector;

  const HomeScreen({
    super.key,
    this.initialService = 'limousine',
    this.showServiceSelector = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final flutter_map.MapController _flutterMapController = flutter_map.MapController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  latlong.LatLng? _currentLocation;
  latlong.LatLng? _destinationLocation;
  List<latlong.LatLng> _routePoints = [];
  bool _isLocating = true;
  String? _currentOrderId;
  bool? _currentOrderIsTrip;
  bool _isRequestingOrder = false;
  String _shipmentType = 'طرد';
  String _shipmentSize = 'متوسطة';
  XFile? _shipmentImage;
  DateTime? _shippingDateTime;
  socket_io.Socket? _socket;

  late String _selectedService;
  static const latlong.LatLng _defaultLocation = latlong.LatLng(30.78, 29.65);

  // ── Pricing System (8.5 EGP/km with flexible upper bounds and limited discount) ──
  static const double _pricePerKm = 8.5; // 8.5 EGP per kilometer
  static const double _minBaseFare = 20.0; // Minimum base starting fare
  static const double _maxDiscountRatio = 0.15; // Max 15% discount limit

  double? _estimatedDistanceKm;
  double? _baseEstimatedPrice;

  double get _minAllowedPrice {
    if (_baseEstimatedPrice == null) return _minBaseFare;
    final discounted = (_baseEstimatedPrice! * (1.0 - _maxDiscountRatio)).roundToDouble();
    return discounted < _minBaseFare ? _minBaseFare : discounted;
  }

  void _calculateFareFromDistance(double distanceKm) {
    if (!mounted) return;
    final rawFare = distanceKm * _pricePerKm;
    final fare = (rawFare < _minBaseFare ? _minBaseFare : rawFare).roundToDouble();
    setState(() {
      _estimatedDistanceKm = distanceKm;
      _baseEstimatedPrice = fare;
      _priceController.text = fare.toInt().toString();
    });
  }

  void _increasePrice([double step = 5.0]) {
    final current = double.tryParse(_priceController.text) ?? (_baseEstimatedPrice ?? 50.0);
    final next = (current + step).roundToDouble();
    setState(() {
      _priceController.text = next.toInt().toString();
    });
  }

  void _decreasePrice([double step = 5.0]) {
    final current = double.tryParse(_priceController.text) ?? (_baseEstimatedPrice ?? 50.0);
    final minLimit = _minAllowedPrice;
    final next = (current - step).roundToDouble();
    if (next < minLimit) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يمكن تخفيض السعر أكثر من ذلك. الحد الأدنى المسموح به هو ${minLimit.toInt()} ج.م',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        _priceController.text = minLimit.toInt().toString();
      });
      return;
    }
    setState(() {
      _priceController.text = next.toInt().toString();
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedService = widget.initialService;
    _initSocket();
    _determineLocation();
    _loadCurrentOrder();
  }

  Future<void> _loadCurrentOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final orderId = prefs.getString('current_order_id');
    final isTrip = prefs.getBool('current_order_is_trip');
    if (orderId != null && mounted) {
      setState(() {
        _currentOrderId = orderId;
        _currentOrderIsTrip = isTrip;
      });
    }
  }

  Future<void> _saveCurrentOrder(String orderId, {bool isTrip = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_order_id', orderId);
    await prefs.setBool('current_order_is_trip', isTrip);
    if (mounted) {
      setState(() {
        _currentOrderId = orderId;
        _currentOrderIsTrip = isTrip;
      });
    }
  }

  Future<void> _clearCurrentOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_order_id');
    await prefs.remove('current_order_is_trip');
    if (mounted) {
      setState(() {
        _currentOrderId = null;
        _currentOrderIsTrip = null;
      });
    }
  }

  Future<void> _selectDestination(latlong.LatLng destination) async {
    final origin = _currentLocation;
    setState(() {
      _destinationLocation = destination;
      _dropoffController.text = 'جاري تحديد العنوان...';
      _routePoints = origin == null ? [] : [origin, destination];
    });

    try {
      final address = await _reverseGeocode(destination);
      if (mounted && _destinationLocation == destination && address != null) {
        _dropoffController.text = address;
      }
    } catch (_) {
      if (mounted && _destinationLocation == destination) {
        _dropoffController.text =
            '${destination.latitude.toStringAsFixed(5)}, ${destination.longitude.toStringAsFixed(5)}';
      }
    }

    if (origin == null) return;

    // Fast direct distance calculation
    final directDistMeters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    _calculateFareFromDistance(directDistMeters / 1000.0);

    try {
      final response = await Dio().get(
        'https://router.project-osrm.org/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );
      final route = response.data['routes']?[0];
      final coordinates = route?['geometry']?['coordinates'];
      final roadDistanceMeters = route?['distance'];
      if (roadDistanceMeters is num && roadDistanceMeters > 0) {
        _calculateFareFromDistance(roadDistanceMeters.toDouble() / 1000.0);
      }

      if (coordinates is! List || !mounted) return;

      final routePoints = coordinates
          .whereType<List>()
          .where((point) => point.length >= 2)
          .map((point) => latlong.LatLng(
                (point[1] as num).toDouble(),
                (point[0] as num).toDouble(),
              ))
          .toList();
      if (routePoints.length > 1) {
        setState(() => _routePoints = routePoints);
      }
    } catch (_) {}
  }

  Widget _buildServiceCard({
    required String service,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _selectedService == service;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedService = service;
          _resetForm();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff111315) : const Color(0xff111315),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xffF97316)
                : const Color(0xff2A2D33),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0xffF97316).withOpacity(0.2)
                  : Colors.black.withOpacity(0.2),
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xffF97316).withOpacity(0.18)
                    : const Color(0xff1A1D21),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected
                    ? const Color(0xffF97316)
                    : const Color(0xff94A3B8),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xffCBD5E1),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xffF97316)
                          : const Color(0xff64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xffF97316),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _socket?.disconnect();
    super.dispose();
  }

  void _initSocket() {
    _socket = socket_io.io(AppConfig.backendBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.on('connect', (_) {
      debugPrint('Customer socket connected');
    });

    _socket!.on('order_status_changed', (data) {
      debugPrint('Order status changed: $data');
      if (data is! Map) return;
      final status = data['status']?.toString();
      final orderId = data['orderId']?.toString();
      final price = data['price'] ?? data['offerAmount'];

      if (status == 'PRICE_SENT') {
        NotificationService().showNotification(
          title: 'عرض سعر جديد لشحنتك! 🏷️',
          body: price != null ? 'وصلك عرض سعر جديد بقيمة $price ج.م' : 'وصلك عرض سعر جديد لطلب الشحن',
        );
      } else if (status == 'COMPANY_ACCEPTED' || status == 'CONFIRMED' || status == 'CUSTOMER_APPROVED') {
        NotificationService().showNotification(
          title: 'تم تأكيد طلب الشحن! 🚚',
          body: 'وافقت شركة الشحن على طلبك وجاري تحضير الشحن والتوصيل.',
        );
      } else if (status == 'COMPANY_REJECTED') {
        NotificationService().showNotification(
          title: 'تم رفض طلب الشحن ✕',
          body: data['reason']?.toString() ?? 'تم رفض الطلب من قبل شركة الشحن.',
        );
      } else if (status == 'IN_PROGRESS') {
        NotificationService().showNotification(
          title: 'شحنتك في الطريق! 📦💨',
          body: 'تم استلام الشحنة وهي الآن قيد التوصيل لوجهتك.',
        );
      } else if (status == 'COMPLETED') {
        NotificationService().showNotification(
          title: 'تم تسليم الشحنة بنجاح! 📦✅',
          body: 'تم إيصال الطرد وتسليمه بنجاح. شكراً لاختيارك زوون.',
        );
      } else if (status == 'CANCELLED') {
        NotificationService().showNotification(
          title: 'تم إلغاء الشحنة ⚠️',
          body: 'تم إلغاء طلب الشحن رقم ${orderId ?? ''}',
        );
      }
      if (mounted) {
        _loadCurrentOrder();
      }
    });

    // Listen for driver offers on limousine trips
    _socket!.on('driver_offer', (data) {
      debugPrint('Driver offer received: $data');
      if (data is! Map) return;
      final driverName = data['driverName'] ?? 'كابتن';
      final offerAmount = data['offerAmount'] ?? data['price'] ?? '';
      NotificationService().showNotification(
        title: 'وصلك عرض مشوار جديد! 💰',
        body: '$driverName قدم عرضاً بقيمة $offerAmount ج.م لرحلتك',
      );
      if (mounted) {
        _loadCurrentOrder();
      }
    });

    // Listen for driver acceptance
    _socket!.on('driver_accepted', (data) {
      if (data is! Map) return;
      NotificationService().showNotification(
        title: 'الكابتن قبل رحلتك! 🚗',
        body: 'قبل الكابتن طلب المشوار وهو في طريقه إليك الآن',
      );
      if (mounted) {
        _loadCurrentOrder();
      }
    });

    // Listen for trip status updates (accepted, driver_arriving, driver_arrived, started, completed, cancelled)
    _socket!.on('trip_status_changed', (data) {
      if (data is! Map) return;
      final status = data['status']?.toString();
      if (status == 'accepted') {
        NotificationService().showNotification(
          title: 'تم تأكيد الرحلة! 🚗',
          body: 'تم تعيين الكابتن وهو قادم إليك في نقطة الاستلام',
        );
      } else if (status == 'driver_arriving') {
        NotificationService().showNotification(
          title: 'الكابتن يقترب منك! 📍',
          body: 'الكابتن على بعد خطوات من موقعك',
        );
      } else if (status == 'driver_arrived') {
        NotificationService().showNotification(
          title: 'الكابتن وصل! 🏁',
          body: 'الكابتن وصل لنقطة الانطلاق وهو في انتظارك الآن',
        );
      } else if (status == 'started' || status == 'in_progress') {
        NotificationService().showNotification(
          title: 'بدأت الرحلة 🛣️',
          body: 'نتمنى لك مشواراً ممتعاً وآمناً مع زوون',
        );
      } else if (status == 'completed') {
        NotificationService().showNotification(
          title: 'وصلت بالسلامة! ✅',
          body: 'تم إكمال الرحلة بنجاح، شكراً لاختيارك زوون',
        );
      } else if (status == 'cancelled') {
        NotificationService().showNotification(
          title: 'تم إلغاء الرحلة ❌',
          body: 'تم إلغاء طلب الرحلة',
        );
      }
      if (mounted) {
        _loadCurrentOrder();
      }
    });

    _socket!.on('disconnect', (_) {
      debugPrint('Customer socket disconnected');
    });
  }

  Future<void> _requestLimousine() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء الانتظار حتى يتم تحديد موقعك')),
      );
      return;
    }

    if (_destinationLocation == null && _dropoffController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء تحديد الوجهة على الخريطة أو كتابة العنوان')),
      );
      return;
    }

    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء إدخال السعر المقترح')),
      );
      return;
    }

    final proposedFare = double.tryParse(_priceController.text) ?? 0.0;
    if (_baseEstimatedPrice != null && proposedFare < _minAllowedPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'عفواً، السعر المقترح (${proposedFare.toInt()} ج.م) أقل من الحد الأدنى (${_minAllowedPrice.toInt()} ج.م) لمسافة ${_estimatedDistanceKm?.toStringAsFixed(1)} كم.\nيمكنك زيادة السعر أو التخفيض بنسبة بسيطة فقط (8.5 ج.م/كم).',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xffDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isRequestingOrder = true;
    });

    try {
      final customerPhone = await AuthService.getUserPhone();
      final customerName = await AuthService.getUserName();
      final userId = await AuthService.getUserId();

      // Send as a TRIP request (goes to drivers) not an ORDER (goes to companies)
      final response = await ApiClient().dio.post(
        '/api/trips/request',
        data: {
          'pickupAddress': _pickupController.text.isNotEmpty
              ? _pickupController.text
              : 'موقعك الحالي',
          'dropoffAddress': _dropoffController.text.isNotEmpty
              ? _dropoffController.text
              : 'وجهتك',
          'pickupLat': _currentLocation!.latitude,
          'pickupLng': _currentLocation!.longitude,
          'dropoffLat': _destinationLocation?.latitude,
          'dropoffLng': _destinationLocation?.longitude,
          'proposedFare': double.parse(_priceController.text),
          'notes':
              _notesController.text.isNotEmpty ? _notesController.text : null,
          if (customerPhone != null && customerPhone.isNotEmpty)
            'customerPhone': customerPhone,
          if (customerName != null && customerName.isNotEmpty)
            'customerName': customerName,
          if (userId != null && userId.isNotEmpty)
            'userId': userId,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;
        final tripId = data['ride']['id'];
        setState(() {
          _currentOrderId = tripId;
          _isRequestingOrder = false;
        });
        await _saveCurrentOrder(tripId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال الطلب للسواقين! انتظر العروض...')),
          );
          _resetForm();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderTrackingScreen(
                orderId: tripId,
                isTrip: true,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _isRequestingOrder = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل إنشاء الطلب: ${response.data}')),
          );
        }
      }
    } on DioException catch (e) {
      setState(() {
        _isRequestingOrder = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في الطلب: ${e.response?.data ?? e.message}')),
        );
      }
    } catch (e) {
      setState(() {
        _isRequestingOrder = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  Future<String?> _reverseGeocode(latlong.LatLng location) async {
    final response = await Dio().get(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'lat': location.latitude,
        'lon': location.longitude,
        'format': 'jsonv2',
        'accept-language': 'ar',
      },
      options: Options(headers: {'User-Agent': 'RideFlow/1.0'}),
    );
    return response.data['display_name'] as String?;
  }

  Future<void> _requestShipping() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء الانتظار حتى يتم تحديد موقعك')),
      );
      return;
    }

    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء إدخال السعر المقترح')),
      );
      return;
    }

    final proposedFare = double.tryParse(_priceController.text) ?? 0.0;
    if (_baseEstimatedPrice != null && proposedFare < _minAllowedPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'عفواً، السعر المقترح (${proposedFare.toInt()} ج.م) أقل من الحد الأدنى (${_minAllowedPrice.toInt()} ج.م) لمسافة ${_estimatedDistanceKm?.toStringAsFixed(1)} كم.\nيمكنك زيادة السعر أو التخفيض بنسبة بسيطة فقط.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xffDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_pickupController.text.isEmpty || _dropoffController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء ملء عناوين الاستلام والتسليم')),
      );
      return;
    }

    setState(() {
      _isRequestingOrder = true;
    });

    try {
      final response = await ApiClient().dio.post(
        '/api/orders/shipping',
        data: {
          'pickupAddress': _pickupController.text,
          'pickupLat': _currentLocation!.latitude,
          'pickupLng': _currentLocation!.longitude,
          'dropoffAddress': _dropoffController.text,
          'dropoffLat': _destinationLocation?.latitude,
          'dropoffLng': _destinationLocation?.longitude,
          'shipmentDetails':
              _notesController.text.isNotEmpty ? _notesController.text : null,
          'shipmentType': _shipmentType,
          'shippingSize': _shipmentSize,
          if (_shipmentImage != null)
            'shippingImageBase64': base64Encode(await _shipmentImage!.readAsBytes()),
          if (_shippingDateTime != null)
            'date': _shippingDateTime!.toIso8601String().split('T').first,
          if (_shippingDateTime != null)
            'time': _shippingDateTime!.toIso8601String().split('T').last.substring(0, 5),
          'offerPrice': double.parse(_priceController.text),
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;
        setState(() {
          _currentOrderId = data['order']['id'];
          _isRequestingOrder = false;
        });
        await _saveCurrentOrder(_currentOrderId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إنشاء طلب الشحن بنجاح!')),
          );
          _resetForm();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderTrackingScreen(
                orderId: data['order']['id'],
                isTrip: false,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _isRequestingOrder = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل إنشاء الطلب: ${response.data}')),
          );
        }
      }
    } on DioException catch (e) {
      setState(() {
        _isRequestingOrder = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في الطلب: ${e.response?.data ?? e.message}')),
        );
      }
    } catch (e) {
      setState(() {
        _isRequestingOrder = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  void _resetForm() {
    _notesController.clear();
    if (_destinationLocation == null) {
      _priceController.clear();
      _estimatedDistanceKm = null;
      _baseEstimatedPrice = null;
    } else if (_baseEstimatedPrice != null) {
      _priceController.text = _baseEstimatedPrice!.toInt().toString();
    }
  }

  Future<void> _determineLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        if (mounted) {
          setState(() {
            _isLocating = false;
          });
        }
        return;
      }

      final location = latlong.LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _currentLocation = location;
        _isLocating = false;
        _pickupController.text = 'جاري تحديد العنوان...';
      });

      _moveMapTo(location);

      try {
        final address = await _reverseGeocode(location);
        if (mounted &&
            _currentLocation == location &&
            _pickupController.text == 'جاري تحديد العنوان...') {
          _pickupController.text = address ??
              '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
        }
      } catch (_) {
        if (mounted &&
            _currentLocation == location &&
            _pickupController.text == 'جاري تحديد العنوان...') {
          _pickupController.text =
              '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
      });
    }
  }

  Future<void> _moveMapTo(latlong.LatLng location) async {
    _flutterMapController.move(location, 15);
  }

  Future<void> _pickShippingDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      initialDate: _shippingDateTime ?? now,
      helpText: 'اختر يوم الاستلام',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _shippingDateTime == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_shippingDateTime!),
      helpText: 'اختر وقت الاستلام',
    );
    if (time == null || !mounted) return;

    setState(() {
      _shippingDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickShipmentImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1400,
    );
    if (image != null && mounted) {
      setState(() => _shipmentImage = image);
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required String labelText,
    required IconData prefixIcon,
    Color? iconColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      hintStyle: const TextStyle(color: Color(0xff64748B), fontSize: 13.5),
      labelStyle: const TextStyle(
        color: Color(0xff94A3B8),
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: iconColor ?? const Color(0xff94A3B8),
        size: 20,
      ),
      filled: true,
      fillColor: const Color(0xff161B24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xff252E3E)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xff252E3E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xffF97316), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayLocation = _currentLocation ?? _defaultLocation;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const CustomerDrawer(),
        backgroundColor: const Color(0xff0B0E14),
        body: Stack(
          children: [
            // ── 1. Full Screen Interactive Map ──
            Positioned.fill(
              child: _buildMapLayer(displayLocation),
            ),

            // Top gradient overlay for contrast with floating header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xff0B0E14).withOpacity(0.85),
                        const Color(0xff0B0E14).withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            // ── 2. Top Floating Header ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _buildTopFloatingHeader(),
              ),
            ),

            // ── 3. Floating Map Controls ──
            _buildFloatingMapControls(),

            // ── 4. Premium Services Bottom Sheet ──
            _buildBottomSheet(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLayer(latlong.LatLng displayLocation) {
    if (kIsWeb) {
      return Container(
        color: const Color(0xff0B0E14),
        child: const Center(
          child: Text(
            'خريطة الويب غير متاحة.\nيرجى استخدام تطبيق الهاتف لتجربة الخريطة الفعلية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return flutter_map.FlutterMap(
      mapController: _flutterMapController,
      options: flutter_map.MapOptions(
        initialCenter: displayLocation,
        initialZoom: _currentLocation != null ? 15 : 13,
        onTap: (tapPosition, point) {
          _selectDestination(point);
        },
      ),
      children: [
        flutter_map.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.zoon.app',
          tileProvider: CancellableNetworkTileProvider(),
        ),
        if (_routePoints.length > 1) ...[
          flutter_map.PolylineLayer(
            polylines: [
              flutter_map.Polyline(
                points: _routePoints,
                color: Colors.black.withOpacity(0.4),
                strokeWidth: 8,
              ),
            ],
          ),
          flutter_map.PolylineLayer(
            polylines: [
              flutter_map.Polyline(
                points: _routePoints,
                color: const Color(0xffF97316),
                strokeWidth: 4.5,
              ),
            ],
          ),
        ],
        flutter_map.MarkerLayer(
          markers: [
            if (_currentLocation != null)
              flutter_map.Marker(
                point: _currentLocation!,
                width: 44,
                height: 44,
                child: const _UserLocationMarker(),
              ),
            if (_destinationLocation != null)
              flutter_map.Marker(
                point: _destinationLocation!,
                width: 44,
                height: 44,
                child: const _DestinationMarker(),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopFloatingHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sidebar Menu Button (3 horizontal bars)
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xff121620).withOpacity(0.92),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff2A3342), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),

          // Center Brand & Live Status Capsule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xff121620).withOpacity(0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xff2A3342), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 12,
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
                  decoration: BoxDecoration(
                    color: const Color(0xff22C55E),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff22C55E).withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'زوون | متاح الآن',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Notifications Button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xff121620).withOpacity(0.92),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff2A3342), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingMapControls() {
    return Positioned(
      left: 16,
      top: 90,
      child: Column(
        children: [
          // GPS Recenter Button
          GestureDetector(
            onTap: () {
              if (_currentLocation != null) {
                _moveMapTo(_currentLocation!);
              } else {
                _determineLocation();
              }
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xff121620).withOpacity(0.94),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff2A3342), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            child: _isLocating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Color(0xffF97316),
                      strokeWidth: 2.2,
                    ),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    size: 22,
                    color: Color(0xffF97316),
                  ),
            ),
          ),
          if (_destinationLocation != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                setState(() {
                  _destinationLocation = null;
                  _routePoints = [];
                  _dropoffController.clear();
                  _estimatedDistanceKm = null;
                  _baseEstimatedPrice = null;
                  _priceController.clear();
                });
              },
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xff121620).withOpacity(0.94),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 22,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    final isLimousine = _selectedService == 'limousine';

    return DraggableScrollableSheet(
      initialChildSize: 0.44,
      minChildSize: 0.30,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.30, 0.44, 0.88],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xff11141A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: const Color(0xff252E3E),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xff475569),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Active Order Tracker Banner (if order exists)
              if (_currentOrderId != null) ...[
                _buildActiveOrderBanner(),
                const SizedBox(height: 14),
              ],

              // Section Title
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 15,
                    decoration: BoxDecoration(
                      color: const Color(0xffF97316),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'الخدمات الرئيسية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // PRIMARY HERO ACTION: Limousine Car Booking
              _buildHeroLimousineCard(isLimousine),
              const SizedBox(height: 10),

              // SECONDARY SERVICES ROW
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryServiceCard(
                      serviceKey: 'shipping',
                      title: 'شحن وطرود',
                      subtitle: 'توصيل سريع وآمن',
                      icon: Icons.local_shipping_outlined,
                      isSelected: !isLimousine,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSecondaryServiceCard(
                      serviceKey: 'scheduled',
                      title: 'رحلات مجدولة',
                      subtitle: 'حجز مسبق ومطارات',
                      icon: Icons.event_available_outlined,
                      isSelected: false,
                      isComingSoon: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // BOOKING FORM SECTION
              _buildBookingForm(isLimousine),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveOrderBanner() {
    final isTrip = _currentOrderIsTrip ?? (_selectedService == 'limousine');
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(
              orderId: _currentOrderId!,
              isTrip: isTrip,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xffF97316).withOpacity(0.20),
              const Color(0xffEA580C).withOpacity(0.08),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xffF97316).withOpacity(0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffF97316).withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xffF97316),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffF97316).withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.radar_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTrip ? 'رحلتك الحالية قيد التنفيذ' : 'شحنتك الحالية قيد المتابعة',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'انقر هنا للمتابعة المباشرة وتتبع المسار ➔',
                    style: TextStyle(
                      color: Color(0xffF97316),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xffF97316),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroLimousineCard(bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedService = 'limousine';
          _resetForm();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [
                    const Color(0xffF97316).withOpacity(0.18),
                    const Color(0xff18202E),
                  ]
                : [
                    const Color(0xff161B24),
                    const Color(0xff141820),
                  ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xffF97316) : const Color(0xff252E3E),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xffF97316).withOpacity(0.22)
                  : Colors.black.withOpacity(0.3),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Car Icon Badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xffF97316).withOpacity(0.2)
                    : const Color(0xff1F2735),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xffF97316).withOpacity(0.6)
                      : const Color(0xff2E3A4E),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.directions_car_filled_rounded,
                color: isSelected ? const Color(0xffF97316) : Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            // Information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'طلب ليموزين فوري (VIP)',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xffF97316).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'الأساسي',
                          style: TextStyle(
                            color: Color(0xffF97316),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'أسرع كابتن متاح في منطقتك • تسعيرة مرنة وتفاوض مباشر',
                    style: TextStyle(
                      color: Color(0xff94A3B8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Select Indicator
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xffF97316) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xffF97316) : const Color(0xff475569),
                  width: 1.8,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryServiceCard({
    required String serviceKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    bool isComingSoon = false,
  }) {
    return GestureDetector(
      onTap: () {
        if (isComingSoon) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خدمة الحجز المسبق ستتوفر قريباً!')),
          );
          return;
        }
        setState(() {
          _selectedService = serviceKey;
          _resetForm();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xffF97316).withOpacity(0.12)
              : const Color(0xff161B24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xffF97316) : const Color(0xff252E3E),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xffF97316).withOpacity(0.2)
                        : const Color(0xff1F2735),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? const Color(0xffF97316) : const Color(0xff94A3B8),
                    size: 20,
                  ),
                ),
                if (isComingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'قريباً',
                      style: TextStyle(color: Color(0xff94A3B8), fontSize: 9.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xffCBD5E1),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? const Color(0xffF97316) : const Color(0xff64748B),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingForm(bool isLimousine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. Locations Container ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xff161B24),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xff252E3E), width: 1),
          ),
          child: Column(
            children: [
              // Pickup
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xff22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _pickupController,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        border: InputBorder.none,
                        hintText: 'موقع الاستلام (موقعك الحالي)',
                        hintStyle: TextStyle(color: Color(0xff64748B), fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xff252E3E), height: 16),
              // Dropoff
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xffEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _dropoffController,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        border: InputBorder.none,
                        hintText: 'حدد الوجهة (انقر على الخريطة أو اكتب هنا)',
                        hintStyle: TextStyle(color: Color(0xffF97316), fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── 2. Shipping Extra Options ──
        if (!isLimousine) ...[
          // Shipment Type Dropdown
          DropdownButtonFormField<String>(
            value: _shipmentType,
            dropdownColor: const Color(0xff161B24),
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: _inputDecoration(
              hintText: 'اختر نوع الشحنة',
              labelText: 'نوع الشحنة',
              prefixIcon: Icons.inventory_2_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'طرد', child: Text('طرد', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 'مستندات', child: Text('مستندات', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 'ظرف', child: Text('ظرف', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 'أخرى', child: Text('أخرى', style: TextStyle(color: Colors.white))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _shipmentType = value);
            },
          ),
          const SizedBox(height: 12),
          // Shipment Size Dropdown
          DropdownButtonFormField<String>(
            value: _shipmentSize,
            dropdownColor: const Color(0xff161B24),
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: _inputDecoration(
              hintText: 'اختر حجم الشحنة',
              labelText: 'حجم الشحنة',
              prefixIcon: Icons.straighten_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'صغيرة', child: Text('صغيرة', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 'متوسطة', child: Text('متوسطة', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 'كبيرة', child: Text('كبيرة', style: TextStyle(color: Colors.white))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _shipmentSize = value);
            },
          ),
          const SizedBox(height: 12),
          // Date/Time & Photo Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickShippingDateTime,
                  icon: const Icon(Icons.event_outlined, size: 18, color: Color(0xffF97316)),
                  label: Text(
                    _shippingDateTime == null
                        ? 'موعد الاستلام'
                        : '${_shippingDateTime!.day}/${_shippingDateTime!.month} ${_shippingDateTime!.hour}:${_shippingDateTime!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xff161B24),
                    side: const BorderSide(color: Color(0xff252E3E)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickShipmentImage,
                  icon: Icon(
                    _shipmentImage == null ? Icons.add_a_photo_outlined : Icons.check_circle_outline,
                    size: 18,
                    color: _shipmentImage == null ? const Color(0xffF97316) : Colors.greenAccent,
                  ),
                  label: Text(
                    _shipmentImage == null ? 'إرفاق صورة' : 'تمت الإضافة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _shipmentImage == null ? Colors.white : Colors.greenAccent,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xff161B24),
                    side: const BorderSide(color: Color(0xff252E3E)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // ── 3. Price Input & Quick Suggestions ──
        if (_estimatedDistanceKm != null && _baseEstimatedPrice != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xff161B24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xffF97316).withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xffF97316).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.straighten_rounded, size: 16, color: Color(0xffF97316)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المسافة المقدرة: ${_estimatedDistanceKm!.toStringAsFixed(1)} كم (8.5 ج.م/كم)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'السعر العادل: ${_baseEstimatedPrice!.toInt()} ج.م • أقل سعر مسموح: ${_minAllowedPrice.toInt()} ج.م',
                        style: const TextStyle(
                          color: Color(0xff94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        TextField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
          decoration: _inputDecoration(
            hintText: 'السعر المقترح (جنيه مصري)',
            labelText: 'السعر المقترح (ج.م)',
            prefixIcon: Icons.payments_outlined,
            iconColor: const Color(0xffF97316),
          ).copyWith(
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Color(0xff94A3B8), size: 22),
                  onPressed: () => _decreasePrice(5),
                  tooltip: 'تخفيض السعر',
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xffF97316), size: 22),
                  onPressed: () => _increasePrice(5),
                  tooltip: 'زيادة السعر',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Quick Fare Suggestion Pills
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: (_baseEstimatedPrice != null
                  ? [
                      _baseEstimatedPrice!.toInt(),
                      (_baseEstimatedPrice! + 10).toInt(),
                      (_baseEstimatedPrice! + 20).toInt(),
                      (_baseEstimatedPrice! + 50).toInt(),
                      _minAllowedPrice.toInt(),
                    ]
                  : [50, 70, 100, 150])
              .toSet()
              .map((amt) {
            final isBase = _baseEstimatedPrice != null && amt == _baseEstimatedPrice!.toInt();
            final isMin = _baseEstimatedPrice != null && amt == _minAllowedPrice.toInt();
            final isSelected = _priceController.text == amt.toString();
            String label = '$amt ج.م';
            if (isBase) {
              label = 'العادل $amt ج.م';
            } else if (isMin) {
              label = 'أقل سعر $amt';
            }

            return GestureDetector(
              onTap: () {
                setState(() {
                  _priceController.text = amt.toString();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xffF97316).withOpacity(0.18)
                      : const Color(0xff161B24),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isSelected ? const Color(0xffF97316) : const Color(0xff2A3342),
                    width: isSelected ? 1.4 : 1.0,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xffF97316)
                        : (isBase ? Colors.white : const Color(0xff94A3B8)),
                    fontSize: 11.5,
                    fontWeight: isSelected || isBase ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // ── 4. Notes Input ──
        TextField(
          controller: _notesController,
          style: const TextStyle(color: Colors.white, fontSize: 13.5),
          decoration: _inputDecoration(
            hintText: isLimousine ? 'ملاحظات للسائق (اختياري)...' : 'تفاصيل الشحنة أو متطلبات خاصة...',
            labelText: 'ملاحظات إضافية',
            prefixIcon: Icons.notes_rounded,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 18),

        // ── 5. Primary Action CTA Button ──
        ElevatedButton.icon(
          onPressed: _isRequestingOrder
              ? null
              : () {
                  if (isLimousine) {
                    _requestLimousine();
                  } else {
                    _requestShipping();
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xffF97316),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: const Color(0xffF97316).withOpacity(0.4),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: _isRequestingOrder
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.2,
                  ),
                )
              : Icon(
                  isLimousine
                      ? Icons.directions_car_rounded
                      : Icons.local_shipping_outlined,
                  size: 22,
                ),
          label: Text(
            _isRequestingOrder
                ? 'جاري إرسال الطلب...'
                : isLimousine
                    ? 'تأكيد طلب ليموزين الآن ➔'
                    : 'تأكيد طلب الشحن الآن ➔',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xffF97316).withOpacity(0.25),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xffF97316),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffF97316).withOpacity(0.6),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xffEF4444),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffEF4444).withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.flag_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class ServiceDashboardScreen extends StatefulWidget {
  final String service;

  const ServiceDashboardScreen({super.key, required this.service});

  @override
  State<ServiceDashboardScreen> createState() => _ServiceDashboardScreenState();
}

class _PremiumMapPin extends StatelessWidget {
  const _PremiumMapPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xffF97316),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffF97316).withOpacity(.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xff111315),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: SizedBox(width: 4, height: 4),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceDashboardScreenState extends State<ServiceDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final serviceType = widget.service == 'limousine' ? 'LIMOUSINE' : 'SHIPPING';
    try {
      final response = await http.get(Uri.parse(
          '${AppConfig.backendBaseUrl}/api/admin/orders?serviceType=$serviceType'));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final orders = (payload['orders'] as List? ?? [])
          .whereType<Map>()
          .map((order) => Map<String, dynamic>.from(order))
          .toList();

      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'فشل تحميل الطلبات: $error';
        });
      }
    }
  }

  int _countByStatus(Iterable<String> statuses) {
    return _orders
        .where((order) => statuses.contains(order['status']?.toString()))
        .length;
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'NEW':
        return 'جديد';
      case 'PRICE_SENT':
        return 'عرض سعر';
      case 'CUSTOMER_APPROVED':
        return 'تمت الموافقة';
      case 'CONFIRMED':
        return 'قيد التنفيذ';
      case 'COMPLETED':
        return 'مكتمل';
      case 'CANCELLED':
        return 'ملغي';
      default:
        return status ?? 'غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLimousine = widget.service == 'limousine';
    final title = isLimousine ? 'الدليفري' : 'داشبورد الشحن';
    final accentColor =
        isLimousine ? const Color(0xff111315) : const Color(0xffF97316);

    final stats = [
      {'label': 'إجمالي الطلبات', 'value': '${_orders.length}'},
      {
        'label': isLimousine ? 'قيد التنفيذ' : 'قيد التوصيل',
        'value': '${_countByStatus(['CONFIRMED'])}',
      },
      {
        'label': 'مكتملة',
        'value': '${_countByStatus(['COMPLETED'])}',
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLimousine
                          ? 'إدارة الطلبات والتوصيل الخاصة بالليموزين.'
                          : 'إدارة الطلبات، العروض، والتأكيدات الخاصة بالشحن.',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: stats.length,
                itemBuilder: (context, index) {
                  final item = stats[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item['value']!,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['label']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadOrders,
                                  child: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          )
                        : _orders.isEmpty
                            ? const Center(child: Text('لا توجد طلبات شحن حقيقية بعد'))
                            : RefreshIndicator(
                                onRefresh: _loadOrders,
                                child: ListView.builder(
                                  itemCount: _orders.length,
                                  itemBuilder: (context, index) {
                                    final order = _orders[index];
                                    final customer = order['customer'] as Map?;
                                    final orderId = order['id']?.toString() ?? '-';
                                    final serviceLabel = isLimousine ? 'ليموزين' : 'شحن';
                                    return _DashboardItem(
                                      title: '$serviceLabel #${orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)}',
                                      subtitle: '${customer?['name'] ?? 'عميل'} - ${_statusLabel(order['status']?.toString())}',
                                      icon: Icons.local_shipping,
                                      color: accentColor,
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
