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
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import 'order_tracking_screen.dart';

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
  final flutter_map.MapController _flutterMapController =
      flutter_map.MapController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final ScrollController _formScrollController = ScrollController();

  latlong.LatLng? _currentLocation;
  latlong.LatLng? _destinationLocation;
  List<latlong.LatLng> _routePoints = [];
  bool _isLocating = true;
  String? _currentOrderId;
  bool _isRequestingOrder = false;
  bool _isMapCollapsed = false;
  String _shipmentType = 'طرد';
  String _shipmentSize = 'متوسطة';
  XFile? _shipmentImage;
  DateTime? _shippingDateTime;
  socket_io.Socket? _socket;

  // Service selection
  late String _selectedService;

  // Fallback: Borg El Arab New, Egypt
  static const latlong.LatLng _defaultLocation = latlong.LatLng(30.78, 29.65);

  @override
  void initState() {
    super.initState();

    _selectedService = widget.initialService;

    _initSocket();
    _determineLocation();
    _loadCurrentOrder();
    _formScrollController.addListener(_handleFormScroll);
    NotificationService().requestPermission();
  }

  void _handleFormScroll() {
    final shouldCollapse = _formScrollController.offset > 28;
    if (shouldCollapse != _isMapCollapsed && mounted) {
      setState(() {
        _isMapCollapsed = shouldCollapse;
      });
    }
  }

  Future<void> _loadCurrentOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final orderId = prefs.getString('current_order_id');
    if (orderId != null && mounted) {
      setState(() {
        _currentOrderId = orderId;
      });
    }
  }

  Future<void> _saveCurrentOrder(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_order_id', orderId);
  }

  Future<void> _clearCurrentOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_order_id');
    if (mounted) {
      setState(() {
        _currentOrderId = null;
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

    try {
      final response = await Dio().get(
        'https://router.project-osrm.org/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );
      final coordinates =
          response.data['routes']?[0]?['geometry']?['coordinates'];
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

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _formScrollController
      ..removeListener(_handleFormScroll)
      ..dispose();
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
      if (mounted &&
          _currentOrderId != null &&
          data['orderId'] == _currentOrderId) {
        if (data['status'] == 'COMPANY_ACCEPTED') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم قبول الطلب من الشركة!')),
          );
          NotificationService().showNotification(
            id: 1,
            title: 'تحديث الطلب',
            body: 'تم قبول الطلب من الشركة!',
          );
        } else if (data['status'] == 'PRICE_SENT') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('تم استقبال عرض سعر جديد: ${data['price']} جنيه')),
          );
        } else if (data['status'] == 'COMPLETED' ||
            data['status'] == 'CANCELLED') {
          _clearCurrentOrder();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'الطلب ${data['status'] == 'COMPLETED' ? 'اكتمل' : 'ألغي'}')),
          );
        }
      }
    });

    // Listen for driver offers on limousine trips
    _socket!.on('driver_offer', (data) {
      debugPrint('Driver offer received: $data');
      if (mounted && _currentOrderId != null &&
          data['rideId'] == _currentOrderId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('عرض جديد من ${data['driverName'] ?? 'سائق'}: ${data['offerAmount']} جنيه'),
            duration: const Duration(seconds: 4),
          ),
        );
        NotificationService().showNotification(
          id: 2,
          title: 'عرض سعر جديد! 💰',
          body: '${data['driverName'] ?? 'سائق'} عرض ${data['offerAmount']} جنيه',
        );
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

    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء اختيار الوجهة')),
      );
      return;
    }

    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء إدخال السعر المقترح')),
      );
      return;
    }

    setState(() {
      _isRequestingOrder = true;
    });

    try {
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
          'dropoffLat': _destinationLocation!.latitude,
          'dropoffLng': _destinationLocation!.longitude,
          'proposedFare': double.parse(_priceController.text),
          'notes':
              _notesController.text.isNotEmpty ? _notesController.text : null,
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
    _priceController.clear();
    _notesController.clear();
  }

  Future<void> _determineLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLocating = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _isLocating = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLocating = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

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

  @override
  Widget build(BuildContext context) {
    final displayLocation = _currentLocation ?? _defaultLocation;
    final isLimousine = _selectedService == 'limousine';
    final serviceColor = isLimousine
        ? const Color(0xff2364aa)
        : const Color(0xff16866b);
    final serviceTitle = isLimousine ? 'رحلة جديدة' : 'شحنة جديدة';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(serviceTitle),
          backgroundColor: serviceColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(26),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.16),
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NotificationsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.16),
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (widget.showServiceSelector)
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedService = 'limousine';
                            _resetForm();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedService == 'limousine'
                                ? Colors.blue.shade800
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.directions_car,
                                color: _selectedService == 'limousine'
                                    ? Colors.white
                                    : Colors.black54,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '🚘 ليموزين',
                                style: TextStyle(
                                  color: _selectedService == 'limousine'
                                      ? Colors.white
                                      : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedService = 'shipping';
                            _resetForm();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedService == 'shipping'
                                ? Colors.green.shade700
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                color: _selectedService == 'shipping'
                                    ? Colors.white
                                    : Colors.black54,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'شحن',
                                style: TextStyle(
                                  color: _selectedService == 'shipping'
                                      ? Colors.white
                                      : Colors.black54,
                                  fontWeight: FontWeight.bold,
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

            // ── Map area ──
            Expanded(
              flex: _isMapCollapsed ? 1 : 2,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withOpacity(0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                children: [
                  if (kIsWeb)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.white],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'خريطة الويب غير متاحة في هذا المتصفح.\nاستخدم التطبيق على الهاتف أو الموبايل لتجربة الخريطة الفعلية.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    )
                  else
                    flutter_map.FlutterMap(
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
                          userAgentPackageName: 'com.zoon.rideflow',
                          tileProvider: CancellableNetworkTileProvider(),
                        ),
                        if (_routePoints.length > 1)
                          flutter_map.PolylineLayer(
                            polylines: [
                              flutter_map.Polyline(
                                points: _routePoints,
                                color: Colors.blue,
                                strokeWidth: 5,
                              ),
                            ],
                          ),
                        flutter_map.MarkerLayer(
                          markers: [
                            if (_currentLocation != null)
                              flutter_map.Marker(
                                point: _currentLocation!,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.my_location,
                                    color: Colors.blue, size: 32),
                              ),
                            if (_destinationLocation != null)
                              flutter_map.Marker(
                                point: _destinationLocation!,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_on,
                                    color: Colors.red, size: 36),
                              ),
                          ],
                        ),
                      ],
                    ),
                  if (_isLocating)
                    Container(
                      color: Colors.black.withOpacity(0.35),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                            SizedBox(height: 16),
                            Text('جاري تحديد موقعك...',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  if (_currentLocation != null && !_isLocating)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'recenter',
                        onPressed: () {
                          _moveMapTo(_currentLocation!);
                        },
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                ],
                ),
              ),
            ),

            // ── Form area ──
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5))
                  ],
                ),
                child: SingleChildScrollView(
                  controller: _formScrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        constraints: const BoxConstraints(minHeight: 132),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              serviceColor,
                              Color.lerp(serviceColor, Colors.black, 0.22)!,
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: serviceColor.withOpacity(0.22),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    isLimousine
                                        ? Icons.directions_car_outlined
                                        : Icons.inventory_2_outlined,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        serviceTitle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isLimousine ? 'تنقل بسهولة وراحة' : 'توصيل آمن وسريع',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.82),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'جاهز للطلب',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              isLimousine
                                  ? 'حدد مكانك ووجهتك لطلب سيارة الآن'
                                  : 'أدخل تفاصيل الشحنة ومكان التسليم الآن',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_selectedService == 'limousine') ...[
                        // Limousine form
                        TextField(
                          controller: _pickupController,
                          decoration: InputDecoration(
                            hintText: 'عنوان الاستلام',
                              labelText: 'من',
                            prefixIcon: const Icon(Icons.location_on,
                                color: Colors.blue),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _dropoffController,
                          decoration: InputDecoration(
                            hintText: 'عنوان الوجهة',
                              labelText: 'إلى',
                            prefixIcon: const Icon(Icons.location_on,
                                color: Colors.red),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        // Shipping form
                        TextField(
                          controller: _pickupController,
                          decoration: InputDecoration(
                            hintText: 'عنوان الاستلام',
                              labelText: 'من',
                            prefixIcon: const Icon(Icons.location_on,
                                color: Colors.blue),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _dropoffController,
                          decoration: InputDecoration(
                            hintText: 'عنوان التسليم',
                              labelText: 'إلى',
                            prefixIcon: const Icon(Icons.location_on,
                                color: Colors.red),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _shipmentType,
                                decoration: InputDecoration(
                                  labelText: 'نوع الشحنة',
                                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'طرد', child: Text('طرد')),
                                  DropdownMenuItem(value: 'مستندات', child: Text('مستندات')),
                                  DropdownMenuItem(value: 'ظرف', child: Text('ظرف')),
                                  DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _shipmentType = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickShippingDateTime,
                                icon: const Icon(Icons.event_outlined),
                                label: Text(
                                  _shippingDateTime == null
                                      ? 'موعد الاستلام'
                                      : '${_shippingDateTime!.day}/${_shippingDateTime!.month} ${_shippingDateTime!.hour.toString().padLeft(2, '0')}:${_shippingDateTime!.minute.toString().padLeft(2, '0')}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  foregroundColor: Colors.green.shade700,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _shipmentSize,
                                decoration: InputDecoration(
                                  labelText: 'حجم الشحنة',
                                  prefixIcon: const Icon(Icons.straighten_outlined),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'صغيرة', child: Text('صغيرة')),
                                  DropdownMenuItem(value: 'متوسطة', child: Text('متوسطة')),
                                  DropdownMenuItem(value: 'كبيرة', child: Text('كبيرة')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _shipmentSize = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickShipmentImage,
                                icon: Icon(_shipmentImage == null
                                    ? Icons.add_a_photo_outlined
                                    : Icons.check_circle_outline),
                                label: Text(
                                  _shipmentImage == null
                                      ? 'صورة الشحنة'
                                      : 'تم اختيار الصورة',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  foregroundColor: Colors.green.shade700,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],


                      // Common fields
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          hintText: _selectedService == 'limousine'
                              ? 'ملاحظات إضافية...'
                              : 'تفاصيل الشحنة...',
                          prefixIcon: const Icon(Icons.notes),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'السعر المقترح (جنيه)',
                          prefixIcon: const Icon(Icons.attach_money),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Button
                      ElevatedButton.icon(
                        onPressed: (_isRequestingOrder)
                            ? null
                            : () {
                                if (_selectedService == 'limousine') {
                                  _requestLimousine();
                                } else {
                                  _requestShipping();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: serviceColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isRequestingOrder
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                                : Icon(isLimousine
                                  ? Icons.directions_car_outlined
                                  : Icons.local_shipping_outlined),
                              label: Text(
                                _isRequestingOrder
                                  ? 'جاري إرسال الطلب...'
                                  : isLimousine
                                    ? 'اطلب ليموزين الآن'
                                    : 'اطلب شحن الآن',
                                style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),

                      // Active Order Tracking Button
                      if (_currentOrderId != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderTrackingScreen(
                                  orderId: _currentOrderId!,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.access_time),
                          label: const Text('متابعة الطلب الحالي'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade800),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
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
}

class ServiceDashboardScreen extends StatefulWidget {
  final String service;

  const ServiceDashboardScreen({super.key, required this.service});

  @override
  State<ServiceDashboardScreen> createState() => _ServiceDashboardScreenState();
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
        isLimousine ? Colors.blue.shade800 : Colors.green.shade700;

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
