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
import '../auth/auth_service.dart';
import '../map_trip/active_trip_screen.dart';

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
  Timer? _tripsRefreshTimer;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Controllers for offers
  final Map<String, TextEditingController> _offerControllers = {};

  String _driverId = 'driver_dummy_001';

  @override
  void initState() {
    super.initState();
    _initializeDriverSession();
  }

  Future<void> _initializeDriverSession() async {
    final savedDriverId = await AuthService.getUserId();
    if (savedDriverId != null && savedDriverId.isNotEmpty) {
      _driverId = savedDriverId;
    }

    if (!mounted) return;

    _initSocket();
    _fetchAvailableTrips();
    _tripsRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_socket?.connected != true) _fetchAvailableTrips();
    });
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _tripsRefreshTimer?.cancel();
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
      'reconnection': true,
      'reconnectionAttempts': 20,
      'reconnectionDelay': 1000,
    });

    _socket!.connect();

    _socket!.on('connect', (_) async {
      _socket!.emit('driver:ready', _driverId);
      await _fetchAvailableTrips();
      if (mounted) setState(() {});
    });

    _socket!.on('disconnect', (_) {
      if (mounted) setState(() {});
    });

    _socket!.on('trip_request', (data) {
      if (mounted) {
        final normalizedData = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        normalizedData['status'] ??= 'pending';

        // Only show new requests if the driver doesn't have an active trip
        final hasActiveTrip = _incomingTrips.any((t) => 
          t['driverId'] == _driverId && 
          ['accepted', 'driver_arriving', 'driver_arrived', 'started'].contains(t['status'])
        );

        if (hasActiveTrip) return;

        final alreadyExists = _incomingTrips.any((trip) =>
          (trip['id'] ?? trip['rideId']) == (normalizedData['id'] ?? normalizedData['rideId'])
        );

        if (alreadyExists) return;

        setState(() {
          _incomingTrips.insert(0, normalizedData);
          final tripId = normalizedData['id'] ?? normalizedData['rideId'];
          if (!_offerControllers.containsKey(tripId)) {
            _offerControllers[tripId] = TextEditingController(
              text: (normalizedData['fareEstimate'] as num?)?.toStringAsFixed(2) ?? '0.00',
            );
          }
        });
        NotificationService().showNotification(
          id: 10,
          title: 'طلب رحلة جديد! 🚗',
          body: 'من: ${normalizedData['pickupAddress'] ?? 'موقع العميل'} - السعر: ${normalizedData['fareEstimate'] ?? ''} ج.م',
        );
      }
    });

    _socket!.on('offer_accepted', (data) {
      debugPrint('Offer accepted by customer: $data');
      if (mounted) {
        _fetchAvailableTrips(); // Reload to get full trip details
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تهانينا! قبل العميل عرضك.'), backgroundColor: Color(0xffF97316)),
        );
        NotificationService().showNotification(
          id: 11,
          title: 'تم قبول عرضك! 🎉',
          body: 'العميل وافق على عرضك. توجه إليه الآن.',
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
      final response = await ApiClient().dio.get('/api/trips');

      if (response.statusCode == 200) {
        final rides = response.data['rides'] as List<dynamic>;
        
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

  Future<void> _acceptTrip(Map<String, dynamic> trip) async {
    final tripId = (trip['id'] ?? trip['rideId']).toString();
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().dio.post(
        '/api/trips/$tripId/accept',
        data: {'driverId': _driverId, 'offerAmount': trip['fareEstimate']},
      );
      if (response.statusCode == 200 && mounted) {
        final index = _incomingTrips.indexWhere((item) => (item['id'] ?? item['rideId']).toString() == tripId);
        if (index != -1) setState(() => _incomingTrips[index]['status'] = 'accepted');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveTripScreen(
              tripId: tripId,
              pickupLat: (trip['pickupLat'] as num).toDouble(),
              pickupLng: (trip['pickupLng'] as num).toDouble(),
              dropoffLat: (trip['dropoffLat'] as num?)?.toDouble(),
              dropoffLng: (trip['dropoffLng'] as num?)?.toDouble(),
              pickupAddress: trip['pickupAddress']?.toString(),
              dropoffAddress: trip['dropoffAddress']?.toString(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل قبول الطلب: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTripDetails(Map<String, dynamic> trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * .72,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: ListView(children: [
            Row(children: [const Expanded(child: Text('تفاصيل الطلب', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xff172B3A))),), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
            const Divider(),
            _detailLine(Icons.person_outline, 'العميل', trip['userName']?.toString() ?? 'عميل'),
            _detailLine(Icons.my_location, 'نقطة الاستلام', trip['pickupAddress']?.toString() ?? 'غير محدد'),
            _detailLine(Icons.flag_outlined, 'نقطة التسليم', trip['dropoffAddress']?.toString() ?? 'غير محدد'),
            _detailLine(Icons.route_outlined, 'المسافة', '${trip['distanceKm'] ?? 0} كم'),
            _detailLine(Icons.payments_outlined, 'السعر', '${trip['fareEstimate'] ?? 0} ج.م'),
            _detailLine(Icons.event_outlined, 'نوع الحجز', trip['tripType']?.toString() ?? 'حجز فوري'),
            if (trip['notes'] != null) _detailLine(Icons.notes_outlined, 'ملاحظات', trip['notes'].toString()),
          ]),
        ),
      ),
    );
  }

  Widget _detailLine(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: const Color(0xffF97316)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12)), const SizedBox(height: 3), Text(value, style: const TextStyle(color: Color(0xff172B3A), fontWeight: FontWeight.w600))]))]),
  );


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
        backgroundColor: const Color(0xffF3F6F8),
        body: SafeArea(
          child: Column(
            children: [
              _buildDispatchHeader(),
              Expanded(
                child: Stack(
                  children: [
                    _buildIncomingTripsList(),
                    if (_isLoading) const Center(child: CircularProgressIndicator(color: Color(0xffD6A84F))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDispatchHeader() {
    final isConnected = _socket?.connected == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xff172B3A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Dispatch Center', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('تشغيل الرحلات الفاخرة', style: TextStyle(color: Color(0xffB7C5D1), fontSize: 13)),
                ]),
              ),
              IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchAvailableTrips),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: isConnected ? const Color(0xff42D392) : const Color(0xffF59E0B), shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text(isConnected ? 'متصل بالخادم مباشرة' : 'جاري الاتصال بالخادم', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${_incomingTrips.where((trip) => trip['status'] == 'pending').length} طلبات جديدة', style: const TextStyle(color: Color(0xffD6A84F), fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  Widget _buildIncomingTripsList() {
    if (_incomingTrips.isEmpty) {
      return Center(
        child: RefreshIndicator(
          onRefresh: _fetchAvailableTrips,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * .2),
              const Icon(Icons.inbox_rounded, size: 72, color: Color(0xff9AA9B5)),
              const SizedBox(height: 18),
              const Center(child: Text('لا توجد طلبات جديدة حالياً', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xff172B3A)))),
              const SizedBox(height: 8),
              Center(child: Text('آخر تحديث: الآن', style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade500))),
              const SizedBox(height: 18),
              Center(child: OutlinedButton.icon(onPressed: _fetchAvailableTrips, icon: const Icon(Icons.refresh), label: const Text('تحديث الطلبات'))),
            ],
          ),
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
        final createdAt = DateTime.tryParse(trip['createdAt']?.toString() ?? '');
        final ageMinutes = createdAt == null ? null : DateTime.now().difference(createdAt.toLocal()).inMinutes;
        final bookingType = trip['tripType']?.toString() ?? trip['areaType']?.toString() ?? 'حجز فوري';
        final vehicleType = trip['vehicleType']?.toString() ?? 'VIP Sedan';

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: status == 'pending' ? const Color(0xffE1E8ED) : const Color(0xffD6A84F),
              width: 1,
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
                    Expanded(child: Text('#${tripId.toString().length > 10 ? tripId.toString().substring(0, 10) : tripId}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xff172B3A)))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: status == 'pending' ? const Color(0xfffff4df) : const Color(0xffE7F5EC), borderRadius: BorderRadius.circular(20)), child: Text(status == 'pending' ? 'جديد' : 'الرحلة الحالية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: status == 'pending' ? const Color(0xffA16207) : const Color(0xff15803D)))),
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
                const SizedBox(height: 6),
                Row(children: [Icon(Icons.directions_car_outlined, size: 17, color: Colors.blueGrey.shade600), const SizedBox(width: 5), Text('$vehicleType  •  $bookingType', style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13))]),
                Text('من: ${trip['pickupAddress'] ?? 'غير محدد'}'),
                Text('إلى: ${trip['dropoffAddress'] ?? 'غير محدد'}'),
                Text('المسافة: ${trip['distanceKm']?.toStringAsFixed(1) ?? '0'} كم'),
                if (trip['fareEstimate'] != null || ageMinutes != null) ...[
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${trip['fareEstimate'] ?? 0} ج.م', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xff15803D))), if (ageMinutes != null) Text('منذ $ageMinutes دقيقة', style: TextStyle(fontSize: 12, color: ageMinutes > 10 ? const Color(0xffB42318) : Colors.blueGrey.shade600))]),
                ],
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
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
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
                                  color: Colors.blue.withOpacity(0.7),
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
                  
                const Divider(height: 20),
                
                // Action Buttons based on Status
                if (status == 'pending')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _acceptTrip(trip),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('قبول الطلب'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff15803D), foregroundColor: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showTripDetails(trip),
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                              label: const Text('تفاصيل'),
                              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xff172B3A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                          enabled: trip['offerSent'] != true, // Disable if already sent
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: trip['offerSent'] == true ? Colors.grey : const Color(0xffF97316),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: trip['offerSent'] == true ? null : () async {
                            final amount = double.tryParse(controller?.text ?? '') ?? (trip['fareEstimate'] as num?)?.toDouble() ?? 0;
                            if (!context.mounted) return;
                            await _submitOffer(tripId, amount);
                            if (mounted) {
                              setState(() {
                                // Mark as sent locally to disable button
                                final idx = _incomingTrips.indexWhere((t) => (t['id'] ?? t['rideId']) == tripId);
                                if (idx != -1) _incomingTrips[idx]['offerSent'] = true;
                              });
                            }
                          },
                          child: Text(trip['offerSent'] == true ? 'في الانتظار' : 'إرسال العرض', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                        ],
                      ),
                    ],
                  )
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
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF97316), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
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
