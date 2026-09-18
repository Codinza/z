import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/network/api_client.dart';
import '../../core/services/notification_service.dart';
import '../../core/config/app_config.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/animations/zoon_animations.dart';

class ActiveTripScreen extends StatefulWidget {
  final String tripId;
  final double pickupLat;
  final double pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? pickupAddress;
  final String? dropoffAddress;
  final String? customerName;
  final String? customerPhone;
  final String? customerImageUrl;

  const ActiveTripScreen({
    super.key,
    required this.tripId,
    required this.pickupLat,
    required this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.pickupAddress,
    this.dropoffAddress,
    this.customerName,
    this.customerPhone,
    this.customerImageUrl,
  });

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final MapController _mapController = MapController();
  LatLng? _driverLocation;
  late final LatLng _pickupLocation;
  socket_io.Socket? _socket;
  String _tripStatus = 'accepted';
  String? _customerPhone;
  String? _customerName;
  List<LatLng> _routePoints = [];
  List<LatLng> _driverToPickupRoute = [];
  Timer? _waitingTimer;
  DateTime? _arrivedAt;
  Duration _waitingDuration = Duration.zero;
  bool _isUpdatingStatus = false;
  bool _hudVisible = true;
  bool _showConfirmDestination = false;

  static const Map<String, Map<String, String>> _knownCustomers = {
    'cmtbv7t8k0000uuf4tbq7ywtj': {'name': 'أيمن', 'phone': '01273381289'},
    'cmtj4htm40006ip1v2064d90p': {'name': 'أيمن', 'phone': '01273381280'},
    'cmtbvd7gd0000uuv0k4cmlv8g': {'name': 'أيمن', 'phone': '01104378091'},
    'cmtw44ylm002be41v9kydho0z': {'name': 'محمد السيد', 'phone': '01221633453'},
    'cmtuknm670000hz1vkpwiducr': {
      'name': 'جني محمد السيد',
      'phone': '01210467498'
    },
    'cmtw19ixg0000e41v60vb5t3h': {'name': 'أيمن', 'phone': '01505175915'},
  };

  String _resolveCustomerName([Map<String, dynamic>? tripData]) {
    final rawName = (tripData?['customerName'] ??
            tripData?['userName'] ??
            _customerName ??
            widget.customerName)
        ?.toString()
        .trim();

    if (rawName != null &&
        rawName.isNotEmpty &&
        rawName != 'null' &&
        rawName != 'User Dummy' &&
        rawName != 'a') {
      return rawName;
    }

    final userId = (tripData?['userId'] ?? tripData?['customerId'])?.toString();
    if (userId != null && _knownCustomers.containsKey(userId)) {
      return _knownCustomers[userId]!['name']!;
    }

    if (rawName == 'a') return 'أيمن';
    return 'عميل زوون VIP';
  }

  String? _resolveCustomerPhone([Map<String, dynamic>? tripData]) {
    final direct = (tripData?['customerPhone'] ??
            tripData?['userPhone'] ??
            tripData?['user']?['phone'] ??
            tripData?['phone'] ??
            _customerPhone ??
            widget.customerPhone)
        ?.toString()
        .trim();

    // Ignore placeholder dummy numbers
    if (direct != null &&
        direct.isNotEmpty &&
        direct != 'null' &&
        !direct.contains('96650000000') &&
        !direct.contains('dummy') &&
        !direct.contains('0000000')) {
      return direct;
    }

    final userId = (tripData?['userId'] ?? tripData?['customerId'])?.toString();
    if (userId != null && _knownCustomers.containsKey(userId)) {
      return _knownCustomers[userId]!['phone'];
    }

    final name = _resolveCustomerName(tripData).toLowerCase();
    for (final entry in _knownCustomers.values) {
      if (entry['name']!.toLowerCase() == name) {
        return entry['phone'];
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _pickupLocation = LatLng(widget.pickupLat, widget.pickupLng);
    _driverLocation = null;
    _customerName = widget.customerName;
    _customerPhone = _resolveCustomerPhone();
    _initSocket();
    _fetchCurrentStatus();
    _loadRoutes();
  }

  void _fitRouteBounds() {
    final points = <LatLng>[];
    if (_driverLocation != null) points.add(_driverLocation!);
    points.add(_pickupLocation);
    if (widget.dropoffLat != null && widget.dropoffLng != null) {
      points.add(LatLng(widget.dropoffLat!, widget.dropoffLng!));
    }
    if (points.isNotEmpty) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 90),
          maxZoom: 16.0,
        ),
      );
    }
  }

  void _centerOnDriver() {
    if (_driverLocation != null) {
      _mapController.move(_driverLocation!, 15.5);
    }
  }

  void _centerOnPickup() {
    _mapController.move(_pickupLocation, 15.5);
  }

  void _centerOnDropoff() {
    if (widget.dropoffLat != null && widget.dropoffLng != null) {
      _mapController.move(LatLng(widget.dropoffLat!, widget.dropoffLng!), 15.5);
    }
  }

  Future<void> _callCustomer() async {
    final phone = _resolveCustomerPhone() ??
        _customerPhone?.trim() ??
        widget.customerPhone?.trim();
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Error calling customer: $e');
    }
  }

  Future<void> _whatsappCustomer() async {
    final phone = _resolveCustomerPhone() ??
        _customerPhone?.trim() ??
        widget.customerPhone?.trim();
    if (phone == null || phone.isEmpty) return;
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('01') && cleanPhone.length == 11) {
      cleanPhone = '2$cleanPhone';
    }
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  double get _distanceToTargetKm {
    if (_driverLocation == null) return 0.0;
    final LatLng target = (_tripStatus == 'started' &&
            widget.dropoffLat != null &&
            widget.dropoffLng != null)
        ? LatLng(widget.dropoffLat!, widget.dropoffLng!)
        : _pickupLocation;

    final meters = Geolocator.distanceBetween(
      _driverLocation!.latitude,
      _driverLocation!.longitude,
      target.latitude,
      target.longitude,
    );
    return meters / 1000.0;
  }

  Future<void> _loadRoutes() async {
    try {
      final driverPosition = await LocationService.getCurrentPosition();
      if (driverPosition != null) {
        _driverLocation =
            LatLng(driverPosition.latitude, driverPosition.longitude);
      }
      await _refreshRouteVisualization();
      if (mounted) {
        setState(() {
          _fitRouteBounds();
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshDriverRoute() async {
    if (_driverLocation == null) return;
    try {
      final route = await _getRoute(_driverLocation!, _pickupLocation);
      if (mounted) {
        setState(() {
          _driverToPickupRoute = route;
          _mapController.move(_driverLocation!, 14);
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshRouteVisualization() async {
    final dropoffLat = widget.dropoffLat;
    final dropoffLng = widget.dropoffLng;

    if (_driverLocation != null) {
      _driverToPickupRoute = await _getRoute(_driverLocation!, _pickupLocation);
    } else {
      _driverToPickupRoute = [];
    }

    if (dropoffLat != null &&
        dropoffLng != null &&
        (_tripStatus == 'started' || _tripStatus == 'completed')) {
      _routePoints = await _getRoute(
        _driverLocation ?? _pickupLocation,
        LatLng(dropoffLat, dropoffLng),
      );
    } else {
      _routePoints = [];
    }

    if (mounted) setState(() {});
  }

  Future<List<LatLng>> _getRoute(LatLng start, LatLng end) async {
    final response = await Dio().get(
      'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
      queryParameters: {'overview': 'full', 'geometries': 'geojson'},
    );
    final coordinates =
        response.data['routes']?[0]?['geometry']?['coordinates'];
    if (coordinates is! List) return [];
    return coordinates
        .whereType<List>()
        .where((point) => point.length >= 2)
        .map((point) => LatLng(
              (point[1] as num).toDouble(),
              (point[0] as num).toDouble(),
            ))
        .toList();
  }

  Future<void> _fetchCurrentStatus() async {
    try {
      final response = await ApiClient().dio.get('/api/trips/${widget.tripId}');
      if (response.statusCode == 200 && response.data['trip'] != null) {
        final tripData = response.data['trip'];
        if (mounted) {
          setState(() {
            _tripStatus = tripData['status'] ?? 'accepted';
            final resolved = _resolveCustomerPhone(
                tripData is Map ? Map<String, dynamic>.from(tripData) : null);
            if (resolved != null && resolved.isNotEmpty) {
              _customerPhone = resolved;
            }
            final name =
                (tripData['customerName'] ?? tripData['userName'])?.toString();
            if (name != null && name.isNotEmpty) {
              _customerName = name;
            }
          });
          if (_tripStatus == 'driver_arrived') {
            _startWaitingTimer();
          }
          await _refreshRouteVisualization();
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch initial status: $e');
    }
  }

  Future<void> _markDriverArrived() async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final response = await ApiClient()
          .dio
          .post('/api/trips/${widget.tripId}/driver-arrived');
      if (response.statusCode == 200 && mounted) {
        setState(() => _tripStatus = 'driver_arrived');
        _startWaitingTimer();
        await _refreshRouteVisualization();
        if (mounted && messenger != null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('تم إرسال إشعار بأنك وصلت للعميل'),
              backgroundColor: Color(0xffF97316),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && messenger != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('فشل إرسال حالة الوصول: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  void _startWaitingTimer() {
    _arrivedAt ??= DateTime.now();
    _waitingTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _arrivedAt == null) return;
      setState(() {
        _waitingDuration = DateTime.now().difference(_arrivedAt!);
      });
    });
  }

  Future<void> _startTrip() async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final response =
          await ApiClient().dio.post('/api/trips/${widget.tripId}/start');
      if (response.statusCode == 200 && mounted) {
        setState(() => _tripStatus = 'started');
        _waitingTimer?.cancel();
        await _refreshRouteVisualization();
        if (mounted) {
          messenger?.showSnackBar(
            const SnackBar(
              content: Text('بدأت الرحلة، الطريق الآن إلى وجهة العميل'),
              backgroundColor: Color(0xff42D392),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text('فشل بدء الرحلة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _completeTrip() async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final response = await ApiClient().dio.patch(
        '/api/trips/${widget.tripId}/status',
        data: {'status': 'completed'},
      );
      if (response.statusCode == 200 && mounted) {
        setState(() => _tripStatus = 'completed');
        await _refreshRouteVisualization();
        if (mounted) {
          messenger?.showSnackBar(
            const SnackBar(
              content: Text('تم توصيل العميل بنجاح وإرسال إشعار له'),
              backgroundColor: Color(0xff42D392),
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text('فشل إنهاء الرحلة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  String _formatWaitingDuration() {
    final minutes =
        _waitingDuration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _waitingDuration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _initSocket() {
    _socket = socket_io.io(AppConfig.backendBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    _socket!.connect();

    _socket!.on('driver_location_update', (data) {
      if (data['rideId'] == widget.tripId) {
        if (mounted) {
          setState(() {
            _driverLocation = LatLng(data['lat'], data['lng']);
          });
          unawaited(_refreshDriverRoute());
        }
      }
    });
    _socket!.on('trip_status_changed', _handleStatusUpdate);
    _socket!.on('trip:status_update', _handleStatusUpdate);
  }

  void _handleStatusUpdate(dynamic data) {
    if (data is Map && (data['rideId'] ?? data['id']) == widget.tripId) {
      if (mounted) {
        setState(() {
          _tripStatus = data['status'] ?? _tripStatus;
          final phone =
              (data['customerPhone'] ?? data['userPhone'] ?? data['phone'])
                  ?.toString();
          if (phone != null && phone.isNotEmpty) {
            _customerPhone = phone;
          }
          final name = (data['customerName'] ?? data['userName'])?.toString();
          if (name != null && name.isNotEmpty) {
            _customerName = name;
          }
        });
        if (_tripStatus == 'driver_arrived') {
          _startWaitingTimer();
        } else if (_tripStatus == 'started' || _tripStatus == 'completed') {
          _waitingTimer?.cancel();
        }
        unawaited(_refreshRouteVisualization());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تحديث الرحلة: ${_getArabicStatus(_tripStatus)}'),
            backgroundColor: Colors.blue.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );

        NotificationService().showNotification(
          id: _getNotificationId(_tripStatus),
          title: _getNotificationTitle(_tripStatus),
          body: _getArabicStatus(_tripStatus),
        );

        if (_tripStatus == 'completed') {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        } else if (_tripStatus == 'cancelled') {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    }
  }

  String _getArabicStatus(String status) {
    switch (status) {
      case 'accepted':
        return 'تم القبول (في انتظار تحرك الكابتن)';
      case 'driver_arriving':
        return 'الكابتن في الطريق إليك';
      case 'driver_arrived':
        return 'الكابتن وصل وهو بالخارج';
      case 'started':
        return 'بدأت الرحلة (في الطريق للوجهة)';
      case 'completed':
        return 'انتهت الرحلة بنجاح';
      case 'cancelled':
        return 'تم إلغاء الرحلة';
      default:
        return status;
    }
  }

  int _getNotificationId(String status) {
    switch (status) {
      case 'driver_arriving':
        return 20;
      case 'driver_arrived':
        return 21;
      case 'started':
        return 22;
      case 'completed':
        return 23;
      case 'cancelled':
        return 24;
      default:
        return 2;
    }
  }

  String _getNotificationTitle(String status) {
    switch (status) {
      case 'driver_arriving':
        return 'الكابتن في الطريق! 🚗';
      case 'driver_arrived':
        return 'الكابتن وصل! 📍';
      case 'started':
        return 'بدأت الرحلة! 🛣️';
      case 'completed':
        return 'تم التوصيل بنجاح! ✅';
      case 'cancelled':
        return 'تم إلغاء الرحلة ❌';
      default:
        return 'تحديث حالة الرحلة';
    }
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerPhone = _resolveCustomerPhone();
    final customerName = _resolveCustomerName();
    final isArrived = _tripStatus == 'driver_arrived';
    final isStarted = _tripStatus == 'started';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B0E14),
        body: Stack(
          children: [
            // 1. Full-Screen Interactive Map with Touch Sensor
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                if (_hudVisible || !_showConfirmDestination) {
                  setState(() {
                    _hudVisible = false;
                    _showConfirmDestination = true;
                  });
                }
              },
              onPointerCancel: (_) {
                if (mounted) {
                  setState(() {
                    _hudVisible = false;
                    _showConfirmDestination = true;
                  });
                }
              },
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _driverLocation ?? _pickupLocation,
                  initialZoom: 14.5,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.all),
                  onMapReady: () {
                    Future.delayed(
                        const Duration(milliseconds: 300), _fitRouteBounds);
                  },
                ),
                children: [
                  // Clean Daytime Map Tiles
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.zoon.rideflow',
                    tileProvider: CancellableNetworkTileProvider(),
                  ),

                  // Route Polylines
                  PolylineLayer(
                    polylines: [
                      // Driver to Pickup Route (Cyan Glow)
                      if (_driverToPickupRoute.length > 1) ...[
                        Polyline(
                          points: _driverToPickupRoute,
                          color: const Color(0xff06B6D4).withOpacity(0.35),
                          strokeWidth: 9.0,
                        ),
                        Polyline(
                          points: _driverToPickupRoute,
                          color: const Color(0xff06B6D4),
                          strokeWidth: 4.0,
                          pattern:
                              StrokePattern.dashed(segments: const [8.0, 6.0]),
                        ),
                      ],
                      // Pickup to Destination Route (Orange Glow)
                      if (_routePoints.length > 1) ...[
                        Polyline(
                          points: _routePoints,
                          color: const Color(0xffF97316).withOpacity(0.35),
                          strokeWidth: 9.0,
                        ),
                        Polyline(
                          points: _routePoints,
                          color: const Color(0xffF97316),
                          strokeWidth: 4.0,
                        ),
                      ],
                    ],
                  ),

                  // Markers Layer
                  MarkerLayer(
                    markers: [
                      // Driver Marker (Cyan)
                      if (_driverLocation != null)
                        Marker(
                          point: _driverLocation!,
                          width: 115,
                          height: 60,
                          child: _buildDriverMarker(),
                        ),
                      // Pickup Marker (Emerald)
                      Marker(
                        point: _pickupLocation,
                        width: 60,
                        height: 60,
                        child: _buildPickupMarker(),
                      ),
                      // Dropoff Marker (Orange)
                      if (widget.dropoffLat != null &&
                          widget.dropoffLng != null)
                        Marker(
                          point: LatLng(widget.dropoffLat!, widget.dropoffLng!),
                          width: 60,
                          height: 60,
                          child: _buildDropoffMarker(),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Top Header Bar - Hides on map touch
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _hudVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !_hudVisible,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xff121620).withOpacity(0.94),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: const Color(0xff1E293B), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Back Button
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_forward_ios_rounded,
                                  color: Colors.white, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: isStarted
                                              ? const Color(0xff10B981)
                                              : const Color(0xffF97316),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _getArabicStatus(_tripStatus),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'العميل: ${customerName.isNotEmpty ? customerName : "عميل زوون VIP"}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xff94A3B8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_distanceToTargetKm > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xff06B6D4).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xff06B6D4)
                                          .withOpacity(0.4)),
                                ),
                                child: Text(
                                  '${_distanceToTargetKm.toStringAsFixed(1)} كم',
                                  style: const TextStyle(
                                    color: Color(0xff06B6D4),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            // Quick Call Button Shortcut
                            if (customerPhone != null &&
                                customerPhone.isNotEmpty)
                              IconButton(
                                onPressed: _callCustomer,
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff10B981)
                                        .withOpacity(0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xff10B981)
                                            .withOpacity(0.4)),
                                  ),
                                  child: const Icon(Icons.phone_rounded,
                                      color: Color(0xff10B981), size: 18),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Floating Map Controls (Right Side) - Hides on map touch
            Positioned(
              top: 105,
              left: 16,
              child: AnimatedOpacity(
                opacity: _hudVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !_hudVisible,
                  child: Column(
                    children: [
                      _mapFloatingButton(
                        icon: Icons.all_inclusive_rounded,
                        tooltip: 'عرض كامل المسار',
                        onTap: _fitRouteBounds,
                      ),
                      const SizedBox(height: 8),
                      _mapFloatingButton(
                        icon: Icons.person_pin_circle_rounded,
                        color: const Color(0xff10B981),
                        tooltip: 'موقع العميل',
                        onTap: _centerOnPickup,
                      ),
                      if (widget.dropoffLat != null &&
                          widget.dropoffLng != null) ...[
                        const SizedBox(height: 8),
                        _mapFloatingButton(
                          icon: Icons.flag_rounded,
                          color: const Color(0xffF97316),
                          tooltip: 'الوجهة',
                          onTap: _centerOnDropoff,
                        ),
                      ],
                      if (_driverLocation != null) ...[
                        const SizedBox(height: 8),
                        _mapFloatingButton(
                          icon: Icons.my_location_rounded,
                          color: const Color(0xff06B6D4),
                          tooltip: 'موقعي',
                          onTap: _centerOnDriver,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // 4. Bottom Distance & Route Summary Panel - Hides on map touch
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: AnimatedOpacity(
                opacity: _showConfirmDestination ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !_showConfirmDestination,
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showConfirmDestination = false;
                            _hudVisible = true;
                          });
                        },
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text(
                          'تم تأكيد الوجهة',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff10B981),
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: AnimatedOpacity(
                opacity: _hudVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !_hudVisible,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xff121620).withOpacity(0.96),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: const Color(0xff1E293B), width: 1.4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.65),
                            blurRadius: 20,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Handle
                          Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xff334155),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          // Customer Profile Row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xffF97316),
                                      width: 1.8),
                                ),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xff0B0E14),
                                  backgroundImage: widget.customerImageUrl !=
                                              null &&
                                          widget.customerImageUrl!.isNotEmpty
                                      ? NetworkImage(widget.customerImageUrl!)
                                      : null,
                                  child: widget.customerImageUrl == null ||
                                          widget.customerImageUrl!.isEmpty
                                      ? const Icon(Icons.person,
                                          color: Color(0xffF97316), size: 24)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customerName.isNotEmpty
                                          ? customerName
                                          : 'عميل زوون VIP',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone_rounded,
                                          size: 13,
                                          color: customerPhone != null &&
                                                  customerPhone.isNotEmpty
                                              ? const Color(0xff10B981)
                                              : const Color(0xff94A3B8),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            customerPhone != null &&
                                                    customerPhone.isNotEmpty
                                                ? customerPhone
                                                : 'رقم الهاتف غير متاح',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: customerPhone != null &&
                                                      customerPhone.isNotEmpty
                                                  ? const Color(0xff10B981)
                                                  : const Color(0xff94A3B8),
                                              fontWeight: customerPhone !=
                                                          null &&
                                                      customerPhone.isNotEmpty
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Action buttons for Customer (Phone & WhatsApp)
                              if (customerPhone != null &&
                                  customerPhone.isNotEmpty) ...[
                                // Phone
                                InkWell(
                                  onTap: _callCustomer,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff10B981)
                                          .withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xff10B981)
                                              .withOpacity(0.3)),
                                    ),
                                    child: const Icon(Icons.call_rounded,
                                        color: Color(0xff10B981), size: 20),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // WhatsApp
                                InkWell(
                                  onTap: _whatsappCustomer,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff22C55E)
                                          .withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xff22C55E)
                                              .withOpacity(0.3)),
                                    ),
                                    child: const Icon(Icons.chat_rounded,
                                        color: Color(0xff22C55E), size: 20),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Addresses Box
                          if (widget.pickupAddress != null ||
                              widget.dropoffAddress != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xff0B0E14),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xff1E293B)),
                              ),
                              child: Column(
                                children: [
                                  if (widget.pickupAddress != null)
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xff10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'الانطلاق: ${widget.pickupAddress}',
                                            style: const TextStyle(
                                              color: Color(0xffCBD5E1),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (widget.pickupAddress != null &&
                                      widget.dropoffAddress != null)
                                    const SizedBox(height: 6),
                                  if (widget.dropoffAddress != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.flag_rounded,
                                            color: Color(0xffF97316), size: 12),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'الوصول: ${widget.dropoffAddress}',
                                            style: const TextStyle(
                                              color: Color(0xffCBD5E1),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],

                          // Waiting timer when arrived
                          if (isArrived) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xff2D210F),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xffF97316)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.hourglass_top_rounded,
                                          color: Color(0xffF97316), size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'عداد انتظار العميل بالخارج:',
                                        style: TextStyle(
                                          color: Color(0xffCBD5E1),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _formatWaitingDuration(),
                                    style: const TextStyle(
                                      color: Color(0xffF97316),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Smart Action Button
                          _buildActionButton(isArrived, isStarted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isArrived, bool isStarted) {
    if (_isUpdatingStatus) {
      return Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xff1E293B),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                color: Color(0xffF97316), strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (!isArrived && !isStarted) {
      // Step 1: Arrived at Customer
      return PressableScale(
        onTap: _markDriverArrived,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xffF97316), Color(0xffEA580C)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffF97316).withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'أنا وصلت للعميل (إشعار العميل)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (isArrived && !isStarted) {
      // Step 2: Start Trip
      return PressableScale(
        onTap: _startTrip,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff10B981), Color(0xff059669)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff10B981).withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.navigation_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'تحرك إلى وجهة العميل (بدء الرحلة)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Step 3: Complete Trip
      return PressableScale(
        onTap: _completeTrip,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff10B981), Color(0xff047857)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff10B981).withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'تم الوصول بنجاح (إنهاء الرحلة وتحصيل الحساب)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _mapFloatingButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    String? tooltip,
  }) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xff121620).withOpacity(0.92),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xff1E293B), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildDriverMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xff06B6D4),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff06B6D4).withOpacity(0.5),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car_rounded, color: Colors.white, size: 12),
              SizedBox(width: 4),
              Text(
                'أنت (الكابتن)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        const GpsRadarMarker(
          color: Color(0xff06B6D4),
          size: 30,
        ),
      ],
    );
  }

  Widget _buildPickupMarker() {
    return const AnimatedPinDropMarker(
      icon: Icons.person_pin_circle_rounded,
      color: Color(0xff10B981),
      size: 34,
    );
  }

  Widget _buildDropoffMarker() {
    return const AnimatedPinDropMarker(
      icon: Icons.flag_rounded,
      color: Color(0xffF97316),
      size: 34,
    );
  }
}
