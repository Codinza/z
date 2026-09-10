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
import '../../core/services/location_service.dart';
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
  Position? _lastDriverPosition;
  final Map<String, List<LatLng>> _routeCache = {};
  final Set<String> _routeLoading = {};

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
    if (!await LocationService.ensurePermission()) return;

    // Send initial location immediately
    try {
      final initialPos = await LocationService.getCurrentPosition();
      if (initialPos == null) return;
      _lastDriverPosition = initialPos;
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

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) {
        if (position == null ||
            !_isOnline ||
            _socket == null ||
            !_socket!.connected) return;

        _lastDriverPosition = position;

        // Find any active trip to update location for (socket)
        final activeTrip = _incomingTrips.firstWhere(
          (t) => ['accepted', 'driver_arriving', 'driver_arrived', 'started']
              .contains(t['status']),
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
        final normalizedData =
            data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        normalizedData['status'] ??= 'pending';

        // Only show new requests if the driver doesn't have an active trip
        final hasActiveTrip = _incomingTrips.any((t) =>
            t['driverId'] == _driverId &&
            ['accepted', 'driver_arriving', 'driver_arrived', 'started']
                .contains(t['status']));

        if (hasActiveTrip) return;

        final alreadyExists = _incomingTrips.any((trip) =>
            (trip['id'] ?? trip['rideId']) ==
            (normalizedData['id'] ?? normalizedData['rideId']));

        if (alreadyExists) return;

        setState(() {
          _incomingTrips.insert(0, normalizedData);
          final tripId = normalizedData['id'] ?? normalizedData['rideId'];
          if (!_offerControllers.containsKey(tripId)) {
            _offerControllers[tripId] = TextEditingController(
              text: (normalizedData['fareEstimate'] as num?)
                      ?.toStringAsFixed(2) ??
                  '0.00',
            );
          }
        });
        NotificationService().showNotification(
          id: 10,
          title: 'طلب رحلة جديد! 🚗',
          body:
              'من: ${normalizedData['pickupAddress'] ?? 'موقع العميل'} - السعر: ${normalizedData['fareEstimate'] ?? ''} ج.م',
        );
      }
    });

    _socket!.on('offer_accepted', (data) {
      debugPrint('Offer accepted by customer: $data');
      if (mounted) {
        _fetchAvailableTrips(); // Reload to get full trip details
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تهانينا! قبل العميل عرضك.'),
              backgroundColor: Color(0xffF97316)),
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
    final status = data['status']?.toString();
    final rideId = data['rideId']?.toString();
    final assignedDriverId = data['driverId']?.toString();

    if (mounted) {
      final index = _incomingTrips.indexWhere(
        (t) => (t['id'] ?? t['rideId'])?.toString() == rideId,
      );

      if (index != -1) {
        final currentTrip = _incomingTrips[index];
        final isMyTrip = (currentTrip['driverId']?.toString() == _driverId) ||
            (assignedDriverId == _driverId);

        if (status == 'cancelled') {
          if (isMyTrip) {
            NotificationService().showNotification(
              title: 'تم إلغاء الرحلة ❌',
              body: 'قام العميل بإلغاء طلب الرحلة.',
            );
          }
          setState(() {
            _incomingTrips.removeAt(index);
          });
        } else if (status == 'completed') {
          if (isMyTrip) {
            NotificationService().showNotification(
              title: 'تم إنهاء الرحلة بنجاح 💵',
              body: 'تم إنهاء الرحلة وإضافة الأرباح إلى محفظتك.',
            );
          }
          setState(() {
            _incomingTrips.removeAt(index);
          });
        } else if (status == 'accepted' && assignedDriverId != _driverId) {
          // Another driver was assigned
          setState(() {
            _incomingTrips.removeAt(index);
          });
        } else if (assignedDriverId == _driverId || isMyTrip) {
          setState(() {
            _incomingTrips[index]['status'] = status;
          });
          if (status == 'accepted') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تهانينا! قبل العميل عرضك.')),
            );
            NotificationService().showNotification(
              title: 'تم قبول عرضك! 🎉',
              body: 'العميل وافق على عرضك. توجه إلى نقطة الاستلام الآن.',
            );
          } else if (status == 'started' || status == 'in_progress') {
            NotificationService().showNotification(
              title: 'بدأت الرحلة 🚗',
              body: 'توجه إلى وجهة العميل المحددة على الخريطة.',
            );
          }
        }
      } else if (assignedDriverId == _driverId) {
        if (status == 'cancelled') {
          NotificationService().showNotification(
            title: 'تم إلغاء الرحلة ❌',
            body: 'قام العميل بإلغاء طلب الرحلة.',
          );
        } else if (status == 'completed') {
          NotificationService().showNotification(
            title: 'تم إنهاء الرحلة بنجاح 💵',
            body: 'تم إنهاء الرحلة وإضافة الأرباح إلى محفظتك.',
          );
        } else if (status == 'accepted') {
          NotificationService().showNotification(
            title: 'تم قبول عرضك! 🎉',
            body: 'العميل وافق على عرضك. توجه إلى نقطة الاستلام الآن.',
          );
        }
        _fetchAvailableTrips();
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
          if (ride['driverId'] == _driverId &&
              ['accepted', 'driver_arriving', 'driver_arrived', 'started']
                  .contains(ride['status'])) return true;
          return false;
        }).toList();

        relevantTrips.sort(
            (a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

        if (mounted) {
          setState(() {
            _incomingTrips.clear();
            for (var trip in relevantTrips) {
              _incomingTrips.add(trip);
              final tripId = trip['id'] ?? trip['rideId'];
              if (!_offerControllers.containsKey(tripId)) {
                _offerControllers[tripId] = TextEditingController(
                  text: (trip['fareEstimate'] as num?)?.toStringAsFixed(2) ??
                      '0.00',
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
          SnackBar(
              content:
                  Text('تم إرسال العرض: $offerAmount ج.م - في انتظار العميل')),
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
        final index = _incomingTrips.indexWhere(
            (item) => (item['id'] ?? item['rideId']).toString() == tripId);
        if (index != -1) {
          setState(() => _incomingTrips[index]['status'] = 'accepted');
        }
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل قبول الطلب: $e')));
      }
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
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: ListView(children: [
            Row(children: [
              const Expanded(
                child: Text('تفاصيل الطلب',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff172B3A))),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close))
            ]),
            const Divider(),
            _detailLine(Icons.person_outline, 'العميل',
                trip['userName']?.toString() ?? 'عميل'),
            _detailLine(Icons.my_location, 'نقطة الاستلام',
                trip['pickupAddress']?.toString() ?? 'غير محدد'),
            _detailLine(Icons.flag_outlined, 'نقطة التسليم',
                trip['dropoffAddress']?.toString() ?? 'غير محدد'),
            _detailLine(Icons.route_outlined, 'المسافة',
                '${trip['distanceKm'] ?? 0} كم'),
            _detailLine(Icons.payments_outlined, 'السعر',
                '${trip['fareEstimate'] ?? 0} ج.م'),
            _detailLine(Icons.event_outlined, 'نوع الحجز',
                trip['tripType']?.toString() ?? 'حجز فوري'),
            if (trip['notes'] != null)
              _detailLine(
                  Icons.notes_outlined, 'ملاحظات', trip['notes'].toString()),
          ]),
        ),
      ),
    );
  }

  Widget _detailLine(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xffF97316)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.blueGrey.shade500, fontSize: 12)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        color: Color(0xff172B3A), fontWeight: FontWeight.w600))
              ]))
        ]),
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
          final index = _incomingTrips
              .indexWhere((t) => (t['id'] ?? t['rideId']) == tripId);
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
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
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

  Future<void> _loadRoadRoute(String tripId, double pickupLat, double pickupLng,
      double dropoffLat, double dropoffLng) async {
    if (_routeCache.containsKey(tripId) || !_routeLoading.add(tripId)) return;
    try {
      final uri = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/$pickupLng,$pickupLat;$dropoffLng,$dropoffLat?overview=full&geometries=geojson');
      final response = await http.get(uri);
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      final coordinates = routes?.isNotEmpty == true
          ? (routes!.first['geometry']?['coordinates'] as List<dynamic>?)
          : null;
      if (coordinates == null || !mounted) return;
      final points = coordinates
          .whereType<List<dynamic>>()
          .where((point) => point.length >= 2)
          .map((point) => LatLng(
                (point[1] as num).toDouble(),
                (point[0] as num).toDouble(),
              ))
          .toList();
      if (points.length > 1) {
        setState(() => _routeCache[tripId] = points);
      }
    } catch (error) {
      debugPrint('Route lookup failed: $error');
    } finally {
      _routeLoading.remove(tripId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B1117),
        body: SafeArea(
          child: Column(
            children: [
              _buildDispatchHeader(),
              Expanded(
                child: Stack(
                  children: [
                    _buildPremiumDispatchWorkspace(),
                    if (_isLoading)
                      const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xffD6A84F))),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: const BoxDecoration(
        color: Color(0xff111B24),
        border: Border(bottom: BorderSide(color: Color(0xff243543))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zoon',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('تشغيل الرحلات الفاخرة',
                          style: TextStyle(
                              color: Color(0xff8FA4B4), fontSize: 13)),
                    ]),
              ),
              IconButton(
                  icon:
                      const Icon(Icons.notifications_none, color: Colors.white),
                  onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumDispatchWorkspace() {
    if (_incomingTrips.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchAvailableTrips,
        color: const Color(0xffD6A84F),
        backgroundColor: const Color(0xff17232D),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 170),
            Icon(Icons.inbox_rounded, size: 64, color: Color(0xff536A7B)),
            SizedBox(height: 18),
            Center(
              child: Text('لا توجد طلبات جديدة حالياً',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
            SizedBox(height: 8),
            Center(
              child: Text('اسحب لأسفل لتحديث الطلبات',
                  style: TextStyle(fontSize: 13, color: Color(0xff8FA4B4))),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAvailableTrips,
      color: const Color(0xffD6A84F),
      backgroundColor: const Color(0xff17232D),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height - 150,
            child: PageView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _incomingTrips.length,
              itemBuilder: (context, index) {
                final trip = _incomingTrips[index];
                return _buildPremiumTripPage(trip, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTripPage(Map<String, dynamic> trip, int index) {
    final tripId = trip['id'] ?? trip['rideId'];
    final status = trip['status'] ?? 'pending';
    final createdAt = DateTime.tryParse(trip['createdAt']?.toString() ?? '');
    final ageMinutes = createdAt == null
        ? null
        : DateTime.now().difference(createdAt.toLocal()).inMinutes;
    final pickupLat = (trip['pickupLat'] as num?)?.toDouble();
    final pickupLng = (trip['pickupLng'] as num?)?.toDouble();
    final dropoffLat = (trip['dropoffLat'] as num?)?.toDouble();
    final dropoffLng = (trip['dropoffLng'] as num?)?.toDouble();
    if (pickupLat != null &&
        pickupLng != null &&
        dropoffLat != null &&
        dropoffLng != null) {
      _loadRoadRoute(
          tripId.toString(), pickupLat, pickupLng, dropoffLat, dropoffLng);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xff121D26),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xff3A5263)),
          boxShadow: const [
            BoxShadow(
                color: Colors.black54, blurRadius: 22, offset: Offset(0, 8)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: 270,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildTripMap(
                      pickupLat: pickupLat,
                      pickupLng: pickupLng,
                      dropoffLat: dropoffLat,
                      dropoffLng: dropoffLng,
                      driverPosition: _lastDriverPosition,
                      routePoints: _routeCache[tripId.toString()],
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xdd111B24),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xff3A5263)),
                      ),
                      child: Text('${index + 1} من ${_incomingTrips.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            _buildRequestPanel(trip, tripId, status, ageMinutes),
          ],
        ),
      ),
    );
  }

  Widget _buildTripMap({
    required double? pickupLat,
    required double? pickupLng,
    required double? dropoffLat,
    required double? dropoffLng,
    required Position? driverPosition,
    required List<LatLng>? routePoints,
  }) {
    if (pickupLat == null || pickupLng == null) {
      return Container(
        color: const Color(0xff17232D),
        child: const Center(
            child: Text('لا يوجد موقع للطلب',
                style: TextStyle(color: Color(0xffA9BAC7)))),
      );
    }

    final points = [
      LatLng(pickupLat, pickupLng),
      if (driverPosition != null)
        LatLng(driverPosition.latitude, driverPosition.longitude),
      if (dropoffLat != null && dropoffLng != null)
        LatLng(dropoffLat, dropoffLng),
    ];

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(40, 100, 40, 250),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.rideflow',
          tileProvider: CancellableNetworkTileProvider(),
        ),
        if (routePoints != null && routePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: const Color(0xffD6A84F),
                strokeWidth: 5,
              ),
            ],
          ),
        if (routePoints == null && dropoffLat != null && dropoffLng != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  LatLng(pickupLat, pickupLng),
                  LatLng(dropoffLat, dropoffLng)
                ],
                color: const Color(0xffD6A84F),
                strokeWidth: 3,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(pickupLat, pickupLng),
              width: 48,
              height: 48,
              child: const Icon(Icons.location_on,
                  color: Color(0xff5DB6E8), size: 42),
            ),
            if (dropoffLat != null && dropoffLng != null)
              Marker(
                point: LatLng(dropoffLat, dropoffLng),
                width: 48,
                height: 48,
                child: const Icon(Icons.flag_rounded,
                    color: Color(0xffFF7A7A), size: 38),
              ),
            if (driverPosition != null)
              Marker(
                point:
                    LatLng(driverPosition.latitude, driverPosition.longitude),
                width: 42,
                height: 42,
                child: const Icon(Icons.navigation_rounded,
                    color: Color(0xffD6A84F), size: 32),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequestPanel(
    Map<String, dynamic> trip,
    dynamic tripId,
    dynamic status,
    int? ageMinutes,
  ) {
    final controller = _offerControllers[tripId];
    final vehicleType = trip['vehicleType']?.toString() ?? 'VIP Sedan';
    final bookingType = trip['tripType']?.toString() ?? 'حجز فوري';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xf5111B24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xff3A5263)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xff5B7181),
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text('NEW REQUEST',
                    style: TextStyle(
                        color: Color(0xffD6A84F),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
              ),
              Text(
                  '#${tripId.toString().substring(0, tripId.toString().length.clamp(0, 9))}',
                  style:
                      const TextStyle(color: Color(0xff8FA4B4), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text('العميل: ${trip['userName'] ?? trip['customerName'] ?? 'عميل'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              _panelTag(Icons.directions_car_outlined, vehicleType),
              const SizedBox(width: 7),
              _panelTag(Icons.bolt_rounded, bookingType),
            ],
          ),
          const SizedBox(height: 10),
          _panelLine(Icons.radio_button_checked, 'من', trip['pickupAddress']),
          _panelLine(Icons.flag_rounded, 'إلى', trip['dropoffAddress']),
          const SizedBox(height: 8),
          Row(
            children: [
              _metric(Icons.route_rounded, '${trip['distanceKm'] ?? 0} كم'),
              const SizedBox(width: 16),
              _metric(
                  Icons.payments_outlined, '${trip['fareEstimate'] ?? 0} ج.م'),
              if (ageMinutes != null) ...[
                const SizedBox(width: 16),
                _metric(Icons.schedule_rounded, 'منذ $ageMinutes د'),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (status == 'pending') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptTrip(trip),
                    icon: const Icon(Icons.check_circle_outline, size: 19),
                    label: const Text('قبول الطلب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffD6A84F),
                      foregroundColor: const Color(0xff111B24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _showTripDetails(trip),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xffC9D6DF),
                    side: const BorderSide(color: Color(0xff3A5263)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'عرضك (جنيه)',
                      labelStyle: TextStyle(color: Color(0xff8FA4B4)),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xff3A5263))),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xffD6A84F))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    enabled: trip['offerSent'] != true,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: trip['offerSent'] == true
                      ? null
                      : () async {
                          final amount =
                              double.tryParse(controller?.text ?? '') ??
                                  (trip['fareEstimate'] as num?)?.toDouble() ??
                                  0;
                          await _submitOffer(tripId, amount);
                          if (mounted) {
                            setState(() {
                              final index = _incomingTrips.indexWhere((item) =>
                                  (item['id'] ?? item['rideId']) == tripId);
                              if (index != -1) {
                                _incomingTrips[index]['offerSent'] = true;
                              }
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2F9E68),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(trip['offerSent'] == true
                      ? 'في الانتظار'
                      : 'إرسال العرض'),
                ),
              ],
            ),
          ] else
            _activeTripAction(tripId, status),
        ],
      ),
    );
  }

  Widget _panelTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xff1B2A35),
          borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: const Color(0xffD6A84F)),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(color: Color(0xffC9D6DF), fontSize: 12)),
      ]),
    );
  }

  Widget _panelLine(IconData icon, String label, dynamic value) {
    return Row(children: [
      Icon(icon, size: 15, color: const Color(0xffD6A84F)),
      const SizedBox(width: 7),
      Text('$label: ',
          style: const TextStyle(color: Color(0xff8FA4B4), fontSize: 12)),
      Expanded(
          child: Text(value?.toString() ?? 'غير محدد',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xffE4EDF2),
                  fontSize: 13,
                  fontWeight: FontWeight.w600))),
    ]);
  }

  Widget _metric(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: const Color(0xffE4BE67)),
      const SizedBox(width: 4),
      Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    ]);
  }

  Widget _activeTripAction(dynamic tripId, dynamic status) {
    final actions = <String, Map<String, dynamic>>{
      'accepted': {
        'label': 'تحرك للعميل (في الطريق)',
        'status': 'driver_arriving',
        'color': const Color(0xffD6A84F)
      },
      'driver_arriving': {
        'label': 'وصلت لموقع العميل',
        'status': 'driver_arrived',
        'color': const Color(0xff3D9ED0)
      },
      'driver_arrived': {
        'label': 'بدء الرحلة والتوجه للوجهة',
        'status': 'start',
        'color': const Color(0xffD6A84F)
      },
      'started': {
        'label': 'تم التوصيل بنجاح',
        'status': 'completed',
        'color': const Color(0xffC95D5D)
      },
    };
    final action = actions[status];
    if (action == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () =>
            _updateTripStatus(tripId.toString(), action['status'] as String),
        style: ElevatedButton.styleFrom(
            backgroundColor: action['color'] as Color,
            foregroundColor: const Color(0xff111B24),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        child: Text(action['label'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildIncomingTripsList() {
    if (_incomingTrips.isEmpty) {
      return Center(
        child: RefreshIndicator(
          onRefresh: _fetchAvailableTrips,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * .2),
              const Icon(Icons.inbox_rounded,
                  size: 72, color: Color(0xff536A7B)),
              const SizedBox(height: 18),
              const Center(
                  child: Text('لا توجد طلبات جديدة حالياً',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white))),
              const SizedBox(height: 8),
              const Center(
                  child: Text('آخر تحديث: الآن',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xff8FA4B4)))),
              const SizedBox(height: 18),
              Center(
                  child: OutlinedButton.icon(
                      onPressed: _fetchAvailableTrips,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تحديث الطلبات'))),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      itemCount: _incomingTrips.length,
      itemBuilder: (context, index) {
        final trip = _incomingTrips[index];
        final tripId = trip['id'] ?? trip['rideId'];
        final status = trip['status'] ?? 'pending';
        final controller = _offerControllers[tripId];

        final bool isHeadingToCustomer =
            status == 'accepted' || status == 'driver_arriving';
        final double? destLat =
            isHeadingToCustomer ? trip['pickupLat'] : trip['dropoffLat'];
        final double? destLng =
            isHeadingToCustomer ? trip['pickupLng'] : trip['dropoffLng'];
        final createdAt =
            DateTime.tryParse(trip['createdAt']?.toString() ?? '');
        final ageMinutes = createdAt == null
            ? null
            : DateTime.now().difference(createdAt.toLocal()).inMinutes;
        final bookingType = trip['tripType']?.toString() ??
            trip['areaType']?.toString() ??
            'حجز فوري';
        final vehicleType = trip['vehicleType']?.toString() ?? 'VIP Sedan';

        return Card(
          color: const Color(0xff121D26),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: status == 'pending'
                  ? const Color(0xff243543)
                  : const Color(0xffD6A84F),
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
                    Expanded(
                        child: Text(
                            '#${tripId.toString().length > 10 ? tripId.toString().substring(0, 10) : tripId}',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white))),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: status == 'pending'
                                ? const Color(0xff3A2F1A)
                                : const Color(0xff163426),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                            status == 'pending' ? 'جديد' : 'الرحلة الحالية',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: status == 'pending'
                                    ? const Color(0xffE4BE67)
                                    : const Color(0xff65D391)))),
                    if (status != 'pending' &&
                        destLat != null &&
                        destLng != null)
                      ElevatedButton.icon(
                        onPressed: () => _openDirections(destLat, destLng),
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('الاتجاهات'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff1D3B55),
                          foregroundColor: const Color(0xffA9D4F2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('العميل: ${trip['userName'] ?? 'User Dummy'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.directions_car_outlined,
                      size: 17, color: Color(0xffD6A84F)),
                  const SizedBox(width: 5),
                  Text('$vehicleType  •  $bookingType',
                      style: const TextStyle(
                          color: Color(0xffA9BAC7), fontSize: 13))
                ]),
                Text('من: ${trip['pickupAddress'] ?? 'غير محدد'}',
                    style: const TextStyle(color: Color(0xffD5E0E8))),
                Text('إلى: ${trip['dropoffAddress'] ?? 'غير محدد'}',
                    style: const TextStyle(color: Color(0xffD5E0E8))),
                Text(
                    'المسافة: ${trip['distanceKm']?.toStringAsFixed(1) ?? '0'} كم',
                    style: const TextStyle(color: Color(0xff8FA4B4))),
                if (trip['fareEstimate'] != null || ageMinutes != null) ...[
                  const SizedBox(height: 6),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${trip['fareEstimate'] ?? 0} ج.م',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff65D391))),
                        if (ageMinutes != null)
                          Text('منذ $ageMinutes دقيقة',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: ageMinutes > 10
                                      ? const Color(0xffFF8C8C)
                                      : const Color(0xff8FA4B4)))
                      ]),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (trip['areaType'] != null)
                      Chip(
                          label: Text(trip['areaType'],
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xffC9D6DF))),
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(0xff1B2A35),
                          side: BorderSide.none),
                    if (trip['vehicleType'] != null)
                      Chip(
                          label: Text(trip['vehicleType'],
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xffA9D4F2))),
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(0xff183247),
                          side: BorderSide.none),
                    if (trip['tripType'] != null)
                      Chip(
                          label: Text(trip['tripType'],
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xffE4BE67))),
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(0xff3A2F1A),
                          side: BorderSide.none),
                  ],
                ),
                if (trip['notes'] != null &&
                    trip['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xff2D281B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xff6C592A))),
                    child: Row(
                      children: [
                        const Icon(Icons.note,
                            size: 16, color: Color(0xffE4BE67)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text('ملاحظة: ${trip['notes']}',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xffF3E4B5)))),
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
                        BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 5)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCameraFit: CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints([
                              LatLng(trip['pickupLat'], trip['pickupLng']),
                              if (trip['dropoffLat'] != null &&
                                  trip['dropoffLng'] != null)
                                LatLng(trip['dropoffLat'], trip['dropoffLng']),
                            ]),
                            padding: const EdgeInsets.all(32.0),
                          ),
                          interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.rideflow',
                            tileProvider: CancellableNetworkTileProvider(),
                          ),
                          if (trip['dropoffLat'] != null &&
                              trip['dropoffLng'] != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [
                                    LatLng(
                                        trip['pickupLat'], trip['pickupLng']),
                                    LatLng(
                                        trip['dropoffLat'], trip['dropoffLng']),
                                  ],
                                  color: Colors.blue.withOpacity(0.7),
                                  strokeWidth: 3.0,
                                  pattern: StrokePattern.dashed(
                                      segments: const [10.0, 10.0]),
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                    trip['pickupLat'], trip['pickupLng']),
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_on,
                                    color: Color(0xff5DB6E8), size: 40),
                              ),
                              if (trip['dropoffLat'] != null &&
                                  trip['dropoffLng'] != null)
                                Marker(
                                  point: LatLng(
                                      trip['dropoffLat'], trip['dropoffLng']),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.location_on,
                                      color: Color(0xffFF7A7A), size: 40),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                const Divider(height: 24, color: Color(0xff243543)),

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
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 18),
                              label: const Text('قبول الطلب'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff2F9E68),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showTripDetails(trip),
                              icon: const Icon(Icons.visibility_outlined,
                                  size: 18),
                              label: const Text('تفاصيل'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xffC9D6DF),
                                  side: const BorderSide(
                                      color: Color(0xff3A5263)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
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
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                              decoration: const InputDecoration(
                                labelText: 'عرضك (جنيه)',
                                labelStyle: TextStyle(color: Color(0xff8FA4B4)),
                                enabledBorder: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Color(0xff3A5263))),
                                focusedBorder: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Color(0xffD6A84F))),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 12),
                              ),
                              enabled: trip['offerSent'] !=
                                  true, // Disable if already sent
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: trip['offerSent'] == true
                                    ? Colors.grey
                                    : const Color(0xffF97316),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: trip['offerSent'] == true
                                  ? null
                                  : () async {
                                      final amount = double.tryParse(
                                              controller?.text ?? '') ??
                                          (trip['fareEstimate'] as num?)
                                              ?.toDouble() ??
                                          0;
                                      if (!context.mounted) return;
                                      await _submitOffer(tripId, amount);
                                      if (mounted) {
                                        setState(() {
                                          // Mark as sent locally to disable button
                                          final idx = _incomingTrips.indexWhere(
                                              (t) =>
                                                  (t['id'] ?? t['rideId']) ==
                                                  tripId);
                                          if (idx != -1) {
                                            _incomingTrips[idx]['offerSent'] =
                                                true;
                                          }
                                        });
                                      }
                                    },
                              child: Text(
                                  trip['offerSent'] == true
                                      ? 'في الانتظار'
                                      : 'إرسال العرض',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
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
                      onPressed: () =>
                          _updateTripStatus(tripId, 'driver_arriving'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('تحرك للعميل (في الطريق)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                else if (status == 'driver_arriving')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          _updateTripStatus(tripId, 'driver_arrived'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('وصلت لموقع العميل',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                else if (status == 'driver_arrived')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _updateTripStatus(tripId, 'start');
                        final lat =
                            (trip['dropoffLat'] as num?)?.toDouble() ?? 0;
                        final lng =
                            (trip['dropoffLng'] as num?)?.toDouble() ?? 0;
                        if (lat != 0 && lng != 0) _openDirections(lat, lng);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffF97316),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('بدء الرحلة والتوجه للوجهة',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                else if (status == 'started')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _updateTripStatus(tripId, 'completed'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('تم التوصيل بنجاح',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
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
