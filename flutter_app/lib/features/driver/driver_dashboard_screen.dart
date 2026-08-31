import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/services/notification_service.dart';
import '../admin/admin_dashboard_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final bool _isOnline = true;
  bool _isLoading = false;
  
  // All relevant trips (pending, and active ones assigned to this driver)
  final List<Map<String, dynamic>> _incomingTrips = [];

  socket_io.Socket? _socket;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Controllers for offers
  final Map<String, TextEditingController> _offerControllers = {};

  final String _driverId = 'driver_dummy_001';

  @override
  void initState() {
    super.initState();
    _initSocket();
    _fetchAvailableTrips();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _socket?.disconnect();
    for (var controller in _offerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء تفعيل خدمة الموقع')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    // Send initial location immediately
    try {
      final initialPos = await Geolocator.getCurrentPosition();
      if (_isOnline) {
        ApiClient().dio.put(
          '/api/locations/$_driverId',
          data: {
            'lat': initialPos.latitude,
            'lng': initialPos.longitude,
          },
        ).ignore();
      }
    } catch (e) {
      // Ignore if can't get initial
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Only send update when moving 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) {
        if (position == null || !_isOnline || _socket == null || !_socket!.connected) return;

        // Find any active trip to update location for (socket)
        final activeTrip = _incomingTrips.firstWhere(
          (t) => ['accepted', 'driver_arriving', 'driver_arrived', 'started'].contains(t['status']),
          orElse: () => <String, dynamic>{},
        );

        if (activeTrip.isNotEmpty) {
          _socket!.emit('driver_location_update', {
            'rideId': activeTrip['id'] ?? activeTrip['rideId'],
            'driverId': _driverId,
            'lat': position.latitude,
            'lng': position.longitude,
          });
        }

        // Always update backend with current location if online
        if (_isOnline) {
          ApiClient().dio.put(
            '/api/locations/$_driverId',
            data: {
              'lat': position.latitude,
              'lng': position.longitude,
            },
          ).ignore();
        }
      },
    );
  }

  void _initSocket() {
    _socket = socket_io.io(AppConfig.backendBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.on('connect', (_) {
      _socket!.emit('driver:ready', _driverId);
    });

    _socket!.on('trip_request', (data) {
      if (mounted) {
        setState(() {
          // Add to top of list
          _incomingTrips.insert(0, data);
          final tripId = data['id'] ?? data['rideId'];
          if (!_offerControllers.containsKey(tripId)) {
            _offerControllers[tripId] = TextEditingController(
              text: (data['fareEstimate'] as num?)?.toStringAsFixed(2) ?? '0.00',
            );
          }
        });
        // Notification: New trip request
        NotificationService().showNotification(
          id: 10,
          title: 'طلب رحلة جديد! 🚗',
          body: 'من: ${data['pickupAddress'] ?? 'موقع العميل'} - السعر: ${data['fareEstimate'] ?? ''} ج.م',
        );
      }
    });

    _socket!.on('trip_status_changed', _handleStatusUpdate);
    _socket!.on('trip:status_update', _handleStatusUpdate);
  }

  void _handleStatusUpdate(dynamic data) async {
    final status = data['status'];
    final rideId = data['rideId'];
    final assignedDriverId = data['driverId'];

      if (mounted) {
        final index = _incomingTrips.indexWhere((t) => (t['id'] ?? t['rideId']) == rideId);
        
        if (index != -1) {
          if (status == 'cancelled' || status == 'completed' || (status == 'accepted' && assignedDriverId != _driverId)) {
            // Remove it from our list if it's done, cancelled, or someone else took it
            setState(() {
              _incomingTrips.removeAt(index);
            });
          } else if (assignedDriverId == _driverId) {
            // Update the status in our list
            setState(() {
              _incomingTrips[index]['status'] = status;
            });
            // If it just got accepted, notify
            if (status == 'accepted') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تهانينا! قبل العميل عرضك.')),
              );
              NotificationService().showNotification(
                id: 11,
                title: 'تم قبول عرضك! 🎉',
                body: 'العميل وافق على عرضك. توجه إليه الآن.',
              );
            }
          }
        }
      }
  }

  Future<void> _fetchAvailableTrips() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendBaseUrl}/api/trips'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rides = data['rides'] as List<dynamic>;
        
        // Include pending trips AND any active trips assigned to this driver
        final relevantTrips = rides.where((ride) {
          if (ride['status'] == 'pending') return true;
          if (ride['driverId'] == _driverId && ['accepted', 'driver_arriving', 'driver_arrived', 'started'].contains(ride['status'])) return true;
          return false;
        }).toList();
        
        relevantTrips.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

        if (mounted) {
          setState(() {
            _incomingTrips.clear();
            for (var trip in relevantTrips) {
              _incomingTrips.add(trip);
              final tripId = trip['id'] ?? trip['rideId'];
              if (!_offerControllers.containsKey(tripId)) {
                _offerControllers[tripId] = TextEditingController(
                  text: (trip['fareEstimate'] as num?)?.toStringAsFixed(2) ?? '0.00',
                );
              }
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching trips: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitOffer(String tripId, double offerAmount) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/trips/$tripId/offer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driverId': _driverId,
          'offerAmount': offerAmount,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إرسال العرض: $offerAmount ج.م - في انتظار العميل')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting offer: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptTrip(String tripId, double offerAmount) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/trips/$tripId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driverId': _driverId,
          'offerAmount': offerAmount,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        final index = _incomingTrips.indexWhere(
          (trip) => (trip['id'] ?? trip['rideId']) == tripId,
        );
        if (index != -1) {
          setState(() => _incomingTrips[index]['status'] = 'accepted');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول الطلب بنجاح')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل قبول الطلب: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectTrip(String tripId) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/trips/$tripId/reject'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'driverId': _driverId}),
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _incomingTrips.removeWhere(
            (trip) => (trip['id'] ?? trip['rideId']) == tripId,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الطلب')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل رفض الطلب: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTripStatus(String tripId, String status) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.patch(
        Uri.parse('${AppConfig.backendBaseUrl}/api/trips/$tripId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          final index = _incomingTrips.indexWhere((t) => (t['id'] ?? t['rideId']) == tripId);
          if (index != -1) {
            setState(() {
              if (status == 'completed' || status == 'cancelled') {
                _incomingTrips.removeAt(index);
              } else {
                _incomingTrips[index]['status'] = data['ride']['status'];
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDirections(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch maps';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح تطبيق الخرائط')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة القيادة'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchAvailableTrips,
            )
          ],
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                ),
              ),
            ),
            SafeArea(
              child: _buildIncomingTripsList(),
            ),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingTripsList() {
    if (_incomingTrips.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد طلبات جديدة حالياً...',
          style: TextStyle(fontSize: 18, color: Colors.black54),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _incomingTrips.length,
      itemBuilder: (context, index) {
        final trip = _incomingTrips[index];
        final tripId = trip['id'] ?? trip['rideId'];
        final status = trip['status'] ?? 'pending';
        final controller = _offerControllers[tripId];

        final bool isHeadingToCustomer = status == 'accepted' || status == 'driver_arriving';
        final double? destLat = isHeadingToCustomer ? trip['pickupLat'] : trip['dropoffLat'];
        final double? destLng = isHeadingToCustomer ? trip['pickupLng'] : trip['dropoffLng'];

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: status == 'pending' ? Colors.transparent : Colors.blue.shade300,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      status == 'pending' ? 'طلب جديد' : 'الرحلة الحالية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: status == 'pending' ? Colors.blue.shade800 : Colors.green.shade800,
                      ),
                    ),
                    if (status != 'pending' && destLat != null && destLng != null)
                      ElevatedButton.icon(
                        onPressed: () => _openDirections(destLat, destLng),
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('الاتجاهات'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade100,
                          foregroundColor: Colors.blue.shade900,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('العميل: ${trip['userName'] ?? 'User Dummy'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('من: ${trip['pickupAddress'] ?? 'غير محدد'}'),
                Text('إلى: ${trip['dropoffAddress'] ?? 'غير محدد'}'),
                Text('المسافة: ${trip['distanceKm']?.toStringAsFixed(1) ?? '0'} كم'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (trip['areaType'] != null)
                      Chip(label: Text(trip['areaType'], style: const TextStyle(fontSize: 12)), padding: EdgeInsets.zero, backgroundColor: Colors.grey.shade100),
                    if (trip['vehicleType'] != null)
                      Chip(label: Text(trip['vehicleType'], style: const TextStyle(fontSize: 12)), padding: EdgeInsets.zero, backgroundColor: Colors.blue.shade50),
                    if (trip['tripType'] != null)
                      Chip(label: Text(trip['tripType'], style: const TextStyle(fontSize: 12)), padding: EdgeInsets.zero, backgroundColor: Colors.orange.shade50),
                  ],
                ),
                if (trip['notes'] != null && trip['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.yellow.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.note, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(child: Text('ملاحظة: ${trip['notes']}', style: const TextStyle(fontSize: 13, color: Colors.black87))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                
                // Map
                if (trip['pickupLat'] != null && trip['pickupLng'] != null)
                  Container(
                    height: 180,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCameraFit: CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints([
                              LatLng(trip['pickupLat'], trip['pickupLng']),
                              if (trip['dropoffLat'] != null && trip['dropoffLng'] != null)
                                LatLng(trip['dropoffLat'], trip['dropoffLng']),
                            ]),
                            padding: const EdgeInsets.all(32.0),
                          ),
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.rideflow',
                            tileProvider: CancellableNetworkTileProvider(),
                          ),
                          if (trip['dropoffLat'] != null && trip['dropoffLng'] != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [
                                    LatLng(trip['pickupLat'], trip['pickupLng']),
                                    LatLng(trip['dropoffLat'], trip['dropoffLng']),
                                  ],
                                  color: Colors.blue.withValues(alpha: 0.7),
                                  strokeWidth: 3.0,
                                  pattern: StrokePattern.dashed(segments: const [10.0, 10.0]),
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(trip['pickupLat'], trip['pickupLng']),
                                width: 40, height: 40,
                                child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
                              ),
                              if (trip['dropoffLat'] != null && trip['dropoffLng'] != null)
                                Marker(
                                  point: LatLng(trip['dropoffLat'], trip['dropoffLng']),
                                  width: 40, height: 40,
                                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                const Divider(height: 16),
                
                // Action Buttons based on Status
                if (status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'عرضك (جنيه)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            final amount = double.tryParse(controller?.text ?? '') ?? (trip['fareEstimate'] as num?)?.toDouble() ?? 0;
                            _submitOffer(tripId, amount);
                          },
                          child: const Text('إرسال العرض', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                if (status == 'pending') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final amount = double.tryParse(controller?.text ?? '') ??
                                (trip['fareEstimate'] as num?)?.toDouble() ?? 0;
                            _acceptTrip(tripId, amount);
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('قبول الطلب'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rejectTrip(tripId),
                          icon: const Icon(Icons.close),
                          label: const Text('رفض الطلب'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]
                else if (status == 'accepted')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _updateTripStatus(tripId, 'driver_arriving'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('تحرك للعميل (في الطريق)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                else if (status == 'driver_arriving')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _updateTripStatus(tripId, 'driver_arrived'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('وصلت لموقع العميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                else if (status == 'driver_arrived')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _updateTripStatus(tripId, 'start');
                        final lat = (trip['dropoffLat'] as num?)?.toDouble() ?? 0;
                        final lng = (trip['dropoffLng'] as num?)?.toDouble() ?? 0;
                        if (lat != 0 && lng != 0) _openDirections(lat, lng);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('بدء الرحلة والتوجه للوجهة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                else if (status == 'started')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _updateTripStatus(tripId, 'completed'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('تم التوصيل بنجاح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
              ],
            ),
          ),
        );
      },
    );
  }
}
