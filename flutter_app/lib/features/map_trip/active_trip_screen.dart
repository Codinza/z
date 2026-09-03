import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../../core/network/api_client.dart';
import '../../core/services/notification_service.dart';
import 'rating_screen.dart';
import '../../core/config/app_config.dart';

class ActiveTripScreen extends StatefulWidget {
  final String tripId;
  final double pickupLat;
  final double pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? pickupAddress;
  final String? dropoffAddress;
  
  const ActiveTripScreen({
    super.key,
    required this.tripId,
    required this.pickupLat,
    required this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.pickupAddress,
    this.dropoffAddress,
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
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _pickupLocation = LatLng(widget.pickupLat, widget.pickupLng);
    // Dummy initial driver location slightly away from pickup
    _driverLocation = LatLng(widget.pickupLat + 0.005, widget.pickupLng + 0.005);
    _initSocket();
    _fetchCurrentStatus();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final dropoffLat = widget.dropoffLat;
    final dropoffLng = widget.dropoffLng;
    if (dropoffLat == null || dropoffLng == null) return;
    try {
      final response = await Dio().get(
        'https://router.project-osrm.org/route/v1/driving/${widget.pickupLng},${widget.pickupLat};$dropoffLng,$dropoffLat',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );
      final coordinates = response.data['routes']?[0]?['geometry']?['coordinates'];
      if (coordinates is! List || !mounted) return;
      final points = coordinates.whereType<List>().where((point) => point.length >= 2).map((point) => LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble())).toList();
      if (points.length > 1) setState(() => _routePoints = points);
    } catch (_) {}
  }

  Future<void> _fetchCurrentStatus() async {
    try {
      final response = await ApiClient().dio.get('/api/trips/${widget.tripId}');
      if (response.statusCode == 200 && response.data['trip'] != null) {
        if (mounted) {
          setState(() {
            _tripStatus = response.data['trip']['status'] ?? 'accepted';
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch initial status: $e');
    }
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
        }
      }
    });
    _socket!.on('trip_status_changed', _handleStatusUpdate);
    _socket!.on('trip:status_update', _handleStatusUpdate);
  }

  void _handleStatusUpdate(dynamic data) {
    if (data['rideId'] == widget.tripId) {
      if (mounted) {
        setState(() {
          _tripStatus = data['status'];
        });
        
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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => RatingScreen(
                    tripId: widget.tripId,
                    driverName: '',
                  ),
                ),
              );
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
      case 'accepted': return 'تم القبول (في انتظار تحرك الكابتن)';
      case 'driver_arriving': return 'الكابتن في الطريق إليك';
      case 'driver_arrived': return 'الكابتن وصل وهو بالخارج';
      case 'started': return 'بدأت الرحلة (في الطريق للوجهة)';
      case 'completed': return 'انتهت الرحلة بنجاح';
      case 'cancelled': return 'تم إلغاء الرحلة';
      default: return status;
    }
  }

  int _getNotificationId(String status) {
    switch (status) {
      case 'driver_arriving': return 20;
      case 'driver_arrived': return 21;
      case 'started': return 22;
      case 'completed': return 23;
      case 'cancelled': return 24;
      default: return 2;
    }
  }

  String _getNotificationTitle(String status) {
    switch (status) {
      case 'driver_arriving': return 'الكابتن في الطريق! 🚗';
      case 'driver_arrived': return 'الكابتن وصل! 📍';
      case 'started': return 'بدأت الرحلة! 🛣️';
      case 'completed': return 'تم التوصيل بنجاح! ✅';
      case 'cancelled': return 'تم إلغاء الرحلة ❌';
      default: return 'تحديث حالة الرحلة';
    }
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تتبع الرحلة'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pickupLocation,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.zoon.rideflow',
                  tileProvider: CancellableNetworkTileProvider(),
                ),
                if (_driverLocation != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints.length > 1 ? _routePoints : [_driverLocation!, _pickupLocation, if (widget.dropoffLat != null && widget.dropoffLng != null) LatLng(widget.dropoffLat!, widget.dropoffLng!)],
                        color: const Color(0xffF97316),
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pickupLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.person_pin_circle, color: Color(0xffF97316), size: 40),
                    ),
                    if (widget.dropoffLat != null && widget.dropoffLng != null)
                      Marker(
                        point: LatLng(widget.dropoffLat!, widget.dropoffLng!),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.flag, color: Color(0xffF97316), size: 34),
                      ),
                    if (_driverLocation != null)
                      Marker(
                        point: _driverLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.directions_car, color: Colors.blue, size: 40),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'حالة الرحلة: ${_getArabicStatus(_tripStatus)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text('جاري تتبع موقع السائق...'),
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
