import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'dart:convert';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/services/notification_service.dart';
import '../auth/auth_service.dart';
import '../map_trip/active_trip_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../core/widgets/animations/zoon_animations.dart';
import 'driver_background_service.dart';
import 'driver_trip_route_map_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with TickerProviderStateMixin {
  final bool _isOnline = true;
  /// Only blocks the list on the very first load when there is nothing to show.
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isFetching = false;
  String? _submittingTripId;

  // All relevant trips (pending, and active ones assigned to this driver)
  final List<Map<String, dynamic>> _incomingTrips = [];

  socket_io.Socket? _socket;
  Timer? _tripsRefreshTimer;
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _currentDriverPosition;

  // Controllers for offers
  final Map<String, TextEditingController> _offerControllers = {};

  String _driverId = '';
  String _vehicleCategory = 'car'; // car | motorcycle
  bool _isAdminViewer = false;

  late final AnimationController _pulseController;
  late final AnimationController _headerController;

  bool _matchesDriverVehicle(Map<String, dynamic> trip) {
    if (_isAdminViewer) return true;
    final rideType =
        (trip['vehicleType']?.toString().toLowerCase() == 'motorcycle')
            ? 'motorcycle'
            : 'car';
    return rideType == _vehicleCategory;
  }

  String _resolveCustomerName(Map<String, dynamic> trip) {
    final rawName = (trip['customerName'] ??
            trip['userName'] ??
            trip['user']?['name'])
        ?.toString()
        .trim();

    if (rawName != null &&
        rawName.isNotEmpty &&
        rawName != 'null' &&
        rawName != 'User Dummy' &&
        rawName != 'a') {
      return rawName;
    }

    return 'عميل';
  }

  String? _resolveCustomerPhone(Map<String, dynamic> trip) {
    final direct = (trip['customerPhone'] ??
            trip['userPhone'] ??
            trip['user']?['phone'] ??
            trip['phone'])
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

    return null;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..forward();
    _initializeDriverSession();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _headerController.dispose();
    _positionStreamSubscription?.cancel();
    _tripsRefreshTimer?.cancel();
    _socket?.disconnect();
    for (var controller in _offerControllers.values) {
      controller.dispose();
    }
    // Keep DriverBackgroundService running in background
    super.dispose();
  }

  Future<void> _initializeDriverSession() async {
    final savedDriverId = await AuthService.getUserId();
    if (savedDriverId != null && savedDriverId.isNotEmpty) {
      _driverId = savedDriverId;
    }
    _vehicleCategory = await AuthService.getVehicleCategory();
    final role = await AuthService.getUserRole();
    _isAdminViewer = role == 'admin' || role == 'super_admin';

    if (!mounted) return;

    _initSocket();
    _fetchAvailableTrips();
    _tripsRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      // Soft poll even while socket is connected so new trips never stick
      // until a manual refresh.
      _fetchAvailableTrips();
    });
    _startLocationUpdates();

    if (_driverId.isNotEmpty && !_isAdminViewer) {
      DriverBackgroundService().startService(_driverId);
    }
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
      if (mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('موقع الكابتن'),
              content: const Text(
                'نحتاج موقعك أثناء فتح التطبيق لاستقبال الطلبات القريبة وتتبع الرحلة للعميل.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('لاحقًا'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('سماح'),
                ),
              ],
            ),
          ),
        );
        if (proceed != true) return;
      }
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
      _currentDriverPosition = initialPos;
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
        if (position != null) {
          _currentDriverPosition = position;
        }
        if (position == null ||
            !_isOnline ||
            _socket == null ||
            !_socket!.connected) return;

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
      if (_driverId.isEmpty) {
        _driverId = await AuthService.getUserId() ?? '';
      }
      if (_vehicleCategory.isEmpty) {
        _vehicleCategory = await AuthService.getVehicleCategory();
      }
      if (_isAdminViewer) {
        _socket!.emit('admin:ready');
      } else if (_driverId.isNotEmpty) {
        _socket!.emit('driver:ready', {
          'driverId': _driverId,
          'vehicleCategory': _vehicleCategory,
        });
      }
      await _fetchAvailableTrips();
      if (mounted) setState(() {});
    });

    _socket!.on('reconnect', (_) async {
      if (_driverId.isEmpty) {
        _driverId = await AuthService.getUserId() ?? '';
      }
      if (!_isAdminViewer && _driverId.isNotEmpty) {
        _socket!.emit('driver:ready', {
          'driverId': _driverId,
          'vehicleCategory': _vehicleCategory,
        });
      }
      await _fetchAvailableTrips();
    });

    _socket!.on('disconnect', (_) {
      if (mounted) setState(() {});
    });

    void ingestIncomingTrip(Map<String, dynamic> normalizedData) {
      normalizedData['status'] ??= 'pending';

      // Assigned trips for this driver always show; pending must match vehicle.
      // Admin/super_admin viewers see every trip type (car + motorcycle).
      final isMine = normalizedData['driverId'] == _driverId;
      if (!isMine && !_matchesDriverVehicle(normalizedData)) return;

      // Only show new requests if the driver doesn't have an active trip
      // (admins monitor all requests, so skip this guard for them).
      if (!_isAdminViewer) {
        final hasActiveTrip = _incomingTrips.any((t) =>
            t['driverId'] == _driverId &&
            ['accepted', 'driver_arriving', 'driver_arrived', 'started']
                .contains(t['status']));

        if (hasActiveTrip && !isMine) return;
      }

      final alreadyExists = _incomingTrips.any((trip) =>
          (trip['id'] ?? trip['rideId']) ==
          (normalizedData['id'] ?? normalizedData['rideId']));

      if (alreadyExists) return;

      setState(() {
        _incomingTrips.insert(0, normalizedData);
        final tripId = normalizedData['id'] ?? normalizedData['rideId'];
        if (!_offerControllers.containsKey(tripId)) {
          _offerControllers[tripId] = TextEditingController(
            text: (normalizedData['fareEstimate'] as num?)?.toStringAsFixed(2) ??
                '0.00',
          );
        }
      });
      NotificationService().showDriverTripAlert(
        tripId:
            (normalizedData['id'] ?? normalizedData['rideId'] ?? '').toString(),
        pickupAddress:
            (normalizedData['pickupAddress'] ?? 'موقع العميل').toString(),
        fare: (normalizedData['fareEstimate'] ?? '0').toString(),
        customerName: (normalizedData['customerName'] ??
                normalizedData['user']?['name'])
            ?.toString(),
      );
    }

    _socket!.on('trip_request', (data) {
      if (!mounted) return;
      final normalizedData =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      ingestIncomingTrip(normalizedData);
    });

    _socket!.on('pending_rides_sync', (data) {
      if (!mounted || data is! List) return;
      for (final item in data) {
        if (item is Map) {
          ingestIncomingTrip(Map<String, dynamic>.from(item));
        }
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
    final status = data['status'];
    final rideId = data['rideId'];
    final assignedDriverId = data['driverId'];

    if (mounted) {
      final index =
          _incomingTrips.indexWhere((t) => (t['id'] ?? t['rideId']) == rideId);

      if (index != -1) {
        if (status == 'cancelled' ||
            status == 'completed' ||
            (status == 'accepted' && assignedDriverId != _driverId)) {
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

  Future<void> _fetchAvailableTrips({bool forceLoader = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    final showBlockingLoader =
        forceLoader || (_isInitialLoading && _incomingTrips.isEmpty);

    if (mounted) {
      setState(() {
        if (showBlockingLoader) {
          _isInitialLoading = true;
        } else {
          _isRefreshing = true;
        }
      });
    }

    try {
      final response = await ApiClient().dio.get('/api/trips');

      if (response.statusCode == 200) {
        final rides = response.data['rides'] as List<dynamic>;

        // Include matching pending trips AND any active trips assigned to this driver
        final relevantTrips = rides.where((ride) {
          final map = Map<String, dynamic>.from(ride as Map);
          if (ride['status'] == 'pending') {
            return _matchesDriverVehicle(map);
          }
          if (ride['driverId'] == _driverId &&
              ['accepted', 'driver_arriving', 'driver_arrived', 'started']
                  .contains(ride['status'])) return true;
          return false;
        }).toList();

        relevantTrips.sort(
            (a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

        if (mounted) {
          setState(() {
            // Merge instead of clearing so live socket trips don't vanish
            // while the HTTP poll is in flight.
            final byId = <String, Map<String, dynamic>>{};
            for (final existing in _incomingTrips) {
              final id = (existing['id'] ?? existing['rideId'])?.toString();
              if (id != null && id.isNotEmpty) byId[id] = existing;
            }
            for (final trip in relevantTrips) {
              final map = Map<String, dynamic>.from(trip as Map);
              final id = (map['id'] ?? map['rideId'])?.toString();
              if (id == null || id.isEmpty) continue;
              byId[id] = {...?byId[id], ...map};
              if (!_offerControllers.containsKey(id)) {
                _offerControllers[id] = TextEditingController(
                  text: (map['fareEstimate'] as num?)?.toStringAsFixed(2) ??
                      '0.00',
                );
              }
            }
            // Drop finished trips that the API no longer returns as active.
            final activeIds = relevantTrips
                .map((t) => (t['id'] ?? t['rideId'])?.toString())
                .whereType<String>()
                .toSet();
            byId.removeWhere((id, trip) {
              final status = trip['status']?.toString();
              if (status == 'completed' || status == 'cancelled') return true;
              // Keep live pending/active items; remove stale ones gone from API.
              if (!activeIds.contains(id) &&
                  (status == 'pending' ||
                      status == 'accepted' ||
                      status == 'driver_arriving' ||
                      status == 'driver_arrived' ||
                      status == 'started')) {
                // If API didn't list it, trust API for pending; keep assigned mine briefly.
                return status == 'pending';
              }
              return false;
            });

            _incomingTrips
              ..clear()
              ..addAll(byId.values);
            _incomingTrips.sort((a, b) =>
                (b['createdAt'] ?? '').toString().compareTo(
                    (a['createdAt'] ?? '').toString()));
          });
        }
      }
    } catch (e) {
      debugPrint('Silent error fetching trips: $e');
    } finally {
      _isFetching = false;
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _submitOffer(String tripId, double offerAmount) async {
    if (_submittingTripId != null) return;
    setState(() => _submittingTripId = tripId);
    try {
      final driverName = await AuthService.getUserName() ?? 'كابتن زوون';
      final driverPhone = await AuthService.getUserPhone() ?? '';

      final response = await ApiClient().dio.post(
        '/api/trips/$tripId/offer',
        data: {
          'driverId': _driverId,
          'offerAmount': offerAmount,
          'driverName': driverName,
          'driverPhone': driverPhone,
        },
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'تم إرسال العرض: ${offerAmount.toStringAsFixed(0)} ج.م - في انتظار موافقة العميل 🎉'),
            backgroundColor: const Color(0xff10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        final errorMsg = e.response?.data?['message'] ??
            e.response?.data?['error'] ??
            e.message ??
            'تعذر إرسال العرض';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إرسال العرض: $errorMsg'),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء إرسال العرض: $e'),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingTripId = null);
    }
  }

  Future<void> _updateTripStatus(String tripId, String status) async {
    try {
      final response = await ApiClient().dio.patch(
        '/api/trips/$tripId/status',
        data: {'status': status},
      );

      if (response.statusCode == 200) {
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : <String, dynamic>{};
        if (mounted) {
          final index = _incomingTrips
              .indexWhere((t) => (t['id'] ?? t['rideId']) == tripId);
          if (index != -1) {
            setState(() {
              if (status == 'completed' || status == 'cancelled') {
                _incomingTrips.removeAt(index);
              } else {
                _incomingTrips[index]['status'] =
                    data['ride']?['status'] ?? status;
              }
            });
          }
          if (status == 'completed') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إنهاء الرحلة ونقلت للأرشيف'),
                backgroundColor: Color(0xff22C55E),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث حالة الرحلة: $e')),
        );
      }
    }
  }

  void _openTripTracking(Map<String, dynamic> trip) async {
    final tripId = (trip['id'] ?? trip['rideId']).toString();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveTripScreen(
          tripId: tripId,
          pickupLat: (trip['pickupLat'] as num?)?.toDouble() ?? 0,
          pickupLng: (trip['pickupLng'] as num?)?.toDouble() ?? 0,
          dropoffLat: (trip['dropoffLat'] as num?)?.toDouble(),
          dropoffLng: (trip['dropoffLng'] as num?)?.toDouble(),
          pickupAddress: trip['pickupAddress']?.toString(),
          dropoffAddress: trip['dropoffAddress']?.toString(),
          customerName: _resolveCustomerName(trip),
          customerPhone: _resolveCustomerPhone(trip),
          customerImageUrl:
              (trip['customerImageUrl'] ?? trip['userImageUrl'])?.toString(),
        ),
      ),
    );

    if (!mounted) return;
    if (result == 'completed' || result == true) {
      setState(() {
        _incomingTrips.removeWhere(
            (t) => (t['id'] ?? t['rideId'])?.toString() == tripId);
      });
      await _fetchAvailableTrips();
    } else {
      await _fetchAvailableTrips();
    }
  }

  void _openRouteMapScreen(Map<String, dynamic> trip) {
    final tripId = (trip['id'] ?? trip['rideId']).toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverTripRouteMapScreen(
          trip: trip,
          driverPosition: _currentDriverPosition,
          onSubmitOffer: (amount) async {
            await _submitOffer(tripId, amount);
            if (mounted) {
              setState(() {
                final idx = _incomingTrips.indexWhere(
                    (t) => (t['id'] ?? t['rideId']).toString() == tripId);
                if (idx != -1) {
                  _incomingTrips[idx]['offerSent'] = true;
                }
              });
            }
          },
          isOfferSent: trip['offerSent'] == true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B0E14),
        body: SafeArea(
          child: Column(
            children: [
              _buildDispatchHeader(),
              Expanded(
                child: Stack(
                  children: [
                    _buildIncomingTripsList(),
                    if (_isInitialLoading && _incomingTrips.isEmpty)
                      Center(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final t = _pulseController.value;
                            return Transform.scale(
                              scale: 0.92 + (t * 0.08),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xff121620),
                                  border: Border.all(
                                    color: Color.lerp(
                                          const Color(0xffF97316).withOpacity(0.2),
                                          const Color(0xffF97316).withOpacity(0.7),
                                          t)!,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xffF97316)
                                          .withOpacity(0.15 + t * 0.2),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.local_taxi_rounded,
                                  color: Color(0xffF97316),
                                  size: 28,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (_isRefreshing && _incomingTrips.isNotEmpty)
                      const Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xffF97316),
                            ),
                          ),
                        ),
                      ),
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
    final tripCount = _incomingTrips.length;
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _headerController,
        curve: Curves.easeOutCubic,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.18),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _headerController,
          curve: Curves.easeOutCubic,
        )),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff161B26), Color(0xff121620)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xff252E3E)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: const Color(0xffF97316).withOpacity(0.06),
                blurRadius: 20,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glow = 0.2 + (_pulseController.value * 0.35);
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xffF97316), Color(0xffEA580C)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF97316).withOpacity(glow),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/branding/zoon_logo.jpeg',
                    width: 26,
                    height: 26,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.local_taxi_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'كابتن زوون',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tripCount == 0
                          ? 'جاهز لاستقبال الطلبات'
                          : '$tripCount طلب متاح الآن',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (tripCount > 0)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xffF97316).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xffF97316).withOpacity(0.45),
                    ),
                  ),
                  child: Text(
                    '$tripCount',
                    style: const TextStyle(
                      color: Color(0xffF97316),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: const Icon(Icons.notifications_none_rounded,
                    color: Colors.white, size: 22),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingTripsList() {
    if (_incomingTrips.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetchAvailableTrips(forceLoader: false),
        color: const Color(0xffF97316),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final t = _pulseController.value;
                return Opacity(
                  opacity: 0.55 + (t * 0.35),
                  child: Transform.translate(
                    offset: Offset(0, -6 + (t * 12)),
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xff121620),
                            border: Border.all(
                              color: const Color(0xffF97316)
                                  .withOpacity(0.25 + t * 0.35),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffF97316)
                                    .withOpacity(0.12 + t * 0.18),
                                blurRadius: 28,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_taxi_rounded,
                            color: Color(0xffF97316),
                            size: 36,
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
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchAvailableTrips(forceLoader: false),
      color: const Color(0xffF97316),
      child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      itemCount: _incomingTrips.length,
      itemBuilder: (context, index) {
        final trip = _incomingTrips[index];
        final tripId = (trip['id'] ?? trip['rideId']).toString();
        final status = trip['status'] ?? 'pending';
        final controller = _offerControllers[tripId];

        final createdAt =
            DateTime.tryParse(trip['createdAt']?.toString() ?? '');
        final ageMinutes = createdAt == null
            ? null
            : DateTime.now().difference(createdAt.toLocal()).inMinutes;
        final bookingType = trip['tripType']?.toString() ??
            trip['areaType']?.toString() ??
            'حجز فوري';
        final rawVehicleType = trip['vehicleType']?.toString() ?? 'car';
        final vehicleType = rawVehicleType.toLowerCase() == 'motorcycle'
            ? 'موتوسيكل'
            : rawVehicleType.toLowerCase() == 'car'
                ? 'سيارة'
                : rawVehicleType;
        final fareEstimate = (trip['fareEstimate'] as num?)?.toDouble() ?? 0.0;

        final isPending = status == 'pending';

        return _DriverTripEntrance(
          index: index,
          isPending: isPending,
          pulse: _pulseController,
          child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xff121620),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isPending
                  ? const Color(0xffF97316).withOpacity(0.4)
                  : const Color(0xff4ADE80).withOpacity(0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              if (isPending)
                BoxShadow(
                  color: const Color(0xffF97316).withOpacity(0.08),
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header of Card: Status Badge + Age + Service Chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPending
                            ? const Color(0xff2D210F)
                            : const Color(0xff0D2818),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPending
                              ? const Color(0xffF97316).withOpacity(0.5)
                              : const Color(0xff4ADE80).withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPending
                                ? Icons.bolt_rounded
                                : Icons.directions_car_rounded,
                            size: 15,
                            color: isPending
                                ? const Color(0xffF97316)
                                : const Color(0xff4ADE80),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isPending ? 'طلب جديد متاح' : 'رحلتك الحالية',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isPending
                                  ? const Color(0xffF97316)
                                  : const Color(0xff4ADE80),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ageMinutes != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xff161B26),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xff1E293B)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 13, color: Color(0xff94A3B8)),
                            const SizedBox(width: 4),
                            Text(
                              'منذ $ageMinutes د',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ageMinutes > 10
                                    ? const Color(0xffEF4444)
                                    : const Color(0xff94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Customer Info Row
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xff161B26),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xff1E293B)),
                  ),
                  child: Row(
                    children: [
                      _customerAvatar(trip),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _resolveCustomerName(trip),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // Show customer phone ONLY after order is accepted (hidden when pending outside)
                            if (!isPending && _resolveCustomerPhone(trip) != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Row(
                                  children: [
                                    const Icon(Icons.phone_rounded,
                                        size: 13, color: Color(0xff10B981)),
                                    const SizedBox(width: 4),
                                    Text(
                                      _resolveCustomerPhone(trip)!,
                                      style: const TextStyle(
                                        color: Color(0xff10B981),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Row(
                              children: [
                                const Icon(Icons.verified_rounded,
                                    size: 14, color: Color(0xff38BDF8)),
                                const SizedBox(width: 4),
                                const Text(
                                  'عميل معتمد',
                                  style: TextStyle(
                                    color: Color(0xff94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '• $vehicleType',
                                  style: const TextStyle(
                                    color: Color(0xffCBD5E1),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Route Visual Timeline (From -> To)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xff161B26),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xff1E293B)),
                  ),
                  child: Column(
                    children: [
                      // Pickup Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xff10B981).withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xff10B981),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xff10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'نقطة الانطلاق (الركوب)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xff94A3B8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  trip['pickupAddress']?.toString() ?? 'غير محدد',
                                  style: const TextStyle(
                                    color: Color(0xffF1F5F9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Connecting vertical line + Distance Badge
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 2,
                              height: 28,
                              color: const Color(0xff334155),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xff0B0E14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xff1E293B)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.navigation_rounded,
                                      size: 12, color: Color(0xffF97316)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'المسافة: ${trip['distanceKm']?.toStringAsFixed(1) ?? '0'} كم',
                                    style: const TextStyle(
                                      color: Color(0xffE2E8F0),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Dropoff Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xffF97316).withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xffF97316),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: Color(0xffF97316),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'الوجهة (نقطة الوصول)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xff94A3B8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  trip['dropoffAddress']?.toString() ?? 'غير محدد',
                                  style: const TextStyle(
                                    color: Color(0xffF1F5F9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (trip['notes'] != null &&
                    trip['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xff2D210F).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xffF97316).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 16, color: Color(0xffF97316)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ملاحظة: ${trip['notes']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xffFED7AA),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Big Fare Highlight Box
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xff161B26),
                        Color(0xff1A202C),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xffF97316).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الأجرة المقترحة للرحلة',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xff94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                fareEstimate.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xffF97316),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'ج.م',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xffF97316),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xffF97316).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          bookingType,
                          style: const TextStyle(
                            color: Color(0xffF97316),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Map preview if coordinates are available (Clickable to view distances & full route)
                if (trip['pickupLat'] != null && trip['pickupLng'] != null)
                  GestureDetector(
                    onTap: () => _openRouteMapScreen(trip),
                    child: Container(
                    height: 185,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xff0F131C),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xff2A3447),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          FlutterMap(
                            options: MapOptions(
                              initialCameraFit: CameraFit.bounds(
                                bounds: LatLngBounds.fromPoints([
                                  LatLng(trip['pickupLat'], trip['pickupLng']),
                                  if (trip['dropoffLat'] != null &&
                                      trip['dropoffLng'] != null)
                                    LatLng(trip['dropoffLat'],
                                        trip['dropoffLng']),
                                ]),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 45.0, vertical: 35.0),
                                maxZoom: 15.0,
                              ),
                              interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.zoon.rideflow',
                                tileProvider: CancellableNetworkTileProvider(),
                              ),
                              if (trip['dropoffLat'] != null &&
                                  trip['dropoffLng'] != null)
                                PolylineLayer(
                                  polylines: [
                                    // Ambient glow polyline (wide & translucent)
                                    Polyline(
                                      points: [
                                        LatLng(trip['pickupLat'],
                                            trip['pickupLng']),
                                        LatLng(trip['dropoffLat'],
                                            trip['dropoffLng']),
                                      ],
                                      color: const Color(0xffF97316)
                                          .withOpacity(0.35),
                                      strokeWidth: 9.0,
                                    ),
                                    // Sharp neon core line
                                    Polyline(
                                      points: [
                                        LatLng(trip['pickupLat'],
                                            trip['pickupLng']),
                                        LatLng(trip['dropoffLat'],
                                            trip['dropoffLng']),
                                      ],
                                      color: const Color(0xffF97316),
                                      strokeWidth: 3.5,
                                      pattern: StrokePattern.dashed(
                                          segments: const [9.0, 6.0]),
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  // Pickup Marker (Emerald glowing badge)
                                  Marker(
                                    point: LatLng(trip['pickupLat'],
                                        trip['pickupLng']),
                                    width: 96,
                                    height: 36,
                                    alignment: Alignment.center,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xff0B0E14)
                                            .withOpacity(0.92),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: const Color(0xff10B981),
                                            width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xff10B981)
                                                .withOpacity(0.45),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xff10B981),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          const Text(
                                            'نقطة الركوب',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Dropoff Marker (Orange glowing badge)
                                  if (trip['dropoffLat'] != null &&
                                      trip['dropoffLng'] != null)
                                    Marker(
                                      point: LatLng(trip['dropoffLat'],
                                          trip['dropoffLng']),
                                      width: 78,
                                      height: 36,
                                      alignment: Alignment.center,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xff0B0E14)
                                              .withOpacity(0.92),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: const Color(0xffF97316),
                                              width: 1.5),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.location_on,
                                                color: Color(0xffF97316),
                                                size: 13),
                                            SizedBox(width: 4),
                                            Text(
                                              'الوجهة',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),

                          // Vignette edge fade overlay
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xff121620).withOpacity(0.55),
                                      Colors.transparent,
                                      Colors.transparent,
                                      const Color(0xff121620).withOpacity(0.55),
                                    ],
                                    stops: const [0.0, 0.22, 0.78, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Top-Right Glass HUD badge (Distance / Route title)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xff0B0E14)
                                    .withOpacity(0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xff334155)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.alt_route_rounded,
                                      color: Color(0xffF97316), size: 14),
                                  const SizedBox(width: 5),
                                  Text(
                                    trip['distanceKm'] != null
                                        ? '${trip['distanceKm'] is num ? trip['distanceKm'].toStringAsFixed(1) : trip['distanceKm']} كم • مسار الرحلة'
                                        : 'المسار التقديري للرحلة',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Top-Left Glass HUD badge (Dark Night Mode indicator)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xff0B0E14)
                                    .withOpacity(0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xff1E293B)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xff10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'خريطة المسار 🗺️',
                                    style: TextStyle(
                                      color: Color(0xff94A3B8),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bottom Interactive Pill (Tap hint)
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xff0B0E14).withOpacity(0.92),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xff06B6D4).withOpacity(0.65),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.touch_app_rounded,
                                      color: Color(0xff06B6D4), size: 14),
                                  SizedBox(width: 5),
                                  Text(
                                    'اضغط لمعاينة المسافة للعميل والوجهة بالتفصيل 🗺️',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      color: Color(0xff06B6D4), size: 9),
                                ],
                              ),
                            ),
                          ),

                          // Touch Overlay (Captures taps anywhere on the map card)
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openRouteMapScreen(trip),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Actions Area
                if (isPending)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Counter Offer & Action Section (Driver sends offers only; customer accepts)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xff161B26),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xff1E293B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'تقديم عرض سعر للعميل:',
                                  style: TextStyle(
                                    color: Color(0xff94A3B8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffF97316)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'المقترح: ${fareEstimate.toStringAsFixed(0)} ج.م',
                                    style: const TextStyle(
                                      color: Color(0xffF97316),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Quick Increment Chips (+10, +20, +50)
                            Row(
                              children: [
                                _quickAddChip(controller, 10, fareEstimate),
                                const SizedBox(width: 8),
                                _quickAddChip(controller, 20, fareEstimate),
                                const SizedBox(width: 8),
                                _quickAddChip(controller, 50, fareEstimate),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Price Input
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xff0B0E14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xff334155)),
                              ),
                              child: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  hintText: 'السعر بالجنيه',
                                  hintStyle: TextStyle(
                                      color: Color(0xff64748B),
                                      fontSize: 13),
                                  suffixText: 'ج.م',
                                  suffixStyle: TextStyle(
                                    color: Color(0xffF97316),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                ),
                                enabled: trip['offerSent'] != true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Send Offer or Waiting Status
                            if (trip['offerSent'] == true)
                              Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xff1A2332),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xffF59E0B)
                                          .withOpacity(0.6)),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.hourglass_top_rounded,
                                        color: Color(0xffF59E0B), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'تم إرسال عرضك (${controller?.text ?? ''} ج.م) • في انتظار قبول العميل ⏳',
                                      style: const TextStyle(
                                        color: Color(0xffF59E0B),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ShimmerGlowButton(
                                height: 50,
                                borderRadius: 14,
                                isEnabled: _submittingTripId != tripId,
                                glowColor: const Color(0xffF97316),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xffF97316),
                                    Color(0xffEA580C)
                                  ],
                                ),
                                onPressed: _submittingTripId != null
                                    ? null
                                    : () async {
                                  final amount = double.tryParse(
                                          controller?.text ?? '') ??
                                      fareEstimate;
                                  if (!context.mounted) return;
                                  await _submitOffer(tripId, amount);
                                  if (mounted) {
                                    setState(() {
                                      final idx = _incomingTrips.indexWhere(
                                          (t) =>
                                              (t['id'] ?? t['rideId'])
                                                  .toString() ==
                                              tripId);
                                      if (idx != -1) {
                                        _incomingTrips[idx]['offerSent'] = true;
                                      }
                                    });
                                  }
                                },
                                child: _submittingTripId == tripId
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send_rounded,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'إرسال العرض للعميل',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Details & Map button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => _openRouteMapScreen(trip),
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: const Text(
                            'معاينة المسار والخريطة بالتفصيل 🗺️',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff06B6D4),
                            side: const BorderSide(
                              color: Color(0xff06B6D4),
                              width: 1.1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (status == 'accepted')
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xffF59E0B), Color(0xffD97706)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF59E0B).withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _updateTripStatus(tripId, 'driver_arriving');
                        _openTripTracking(trip);
                      },
                      icon: const Icon(Icons.directions_car_rounded,
                          color: Colors.white),
                      label: const Text(
                        'تحرك للعميل (في الطريق)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  )
                else if (status == 'driver_arriving')
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff0EA5E9), Color(0xff0284C7)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff0EA5E9).withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _updateTripStatus(tripId, 'driver_arrived');
                        _openTripTracking(trip);
                      },
                      icon: const Icon(Icons.place_rounded, color: Colors.white),
                      label: const Text(
                        'وصلت لموقع العميل 📍',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  )
                else if (status == 'driver_arrived')
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff8B5CF6), Color(0xff7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff8B5CF6).withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _updateTripStatus(tripId, 'start');
                        _openTripTracking(trip);
                      },
                      icon: const Icon(Icons.rocket_launch_rounded,
                          color: Colors.white),
                      label: const Text(
                        'بدء الرحلة والتوجه للوجهة 🚀',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  )
                else if (status == 'started')
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff10B981), Color(0xff059669)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff10B981).withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _updateTripStatus(tripId, 'completed'),
                      icon: const Icon(Icons.check_circle_rounded,
                          color: Colors.white),
                      label: const Text(
                        'تم التوصيل بنجاح واستلام الأجرة ✅',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        );
      },
      ),
    );
  }

  Widget _quickAddChip(
      TextEditingController? controller, int addAmount, double baseFare) {
    return InkWell(
      onTap: () {
        if (controller != null) {
          final current = double.tryParse(controller.text) ?? baseFare;
          controller.text = (current + addAmount).toStringAsFixed(0);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xff0B0E14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xff334155)),
        ),
        child: Text(
          '+$addAmount ج.م',
          style: const TextStyle(
            color: Color(0xffF97316),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _customerAvatar(Map<String, dynamic> trip) {
    final image =
        (trip['customerImageUrl'] ?? trip['userImageUrl'])?.toString();
    if (image == null || image.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xff1E293B),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xffF97316).withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: const Icon(Icons.person_rounded, color: Color(0xffF97316), size: 24),
      );
    }
    try {
      final bytes = base64Decode(image.split(',').last);
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xffF97316),
            width: 1.5,
          ),
          image: DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
        ),
      );
    } catch (_) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xff1E293B),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xffF97316).withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: const Icon(Icons.person_rounded, color: Color(0xffF97316), size: 24),
      );
    }
  }
}

class _DriverTripEntrance extends StatelessWidget {
  const _DriverTripEntrance({
    required this.index,
    required this.isPending,
    required this.pulse,
    required this.child,
  });

  final int index;
  final bool isPending;
  final Animation<double> pulse;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + (index.clamp(0, 6) * 70)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - value)),
            child: Transform.scale(
              scale: 0.96 + (0.04 * value),
              child: animatedChild,
            ),
          ),
        );
      },
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, animatedChild) {
          if (!isPending) return animatedChild!;
          final glow = 0.08 + (pulse.value * 0.14);
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffF97316).withOpacity(glow),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: animatedChild,
          );
        },
        child: child,
      ),
    );
  }
}
