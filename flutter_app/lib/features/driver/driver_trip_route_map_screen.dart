import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/widgets/animations/pressable_scale.dart';

class DriverTripRouteMapScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final Position? driverPosition;
  final Future<void> Function(double amount)? onSubmitOffer;
  final bool isOfferSent;

  const DriverTripRouteMapScreen({
    super.key,
    required this.trip,
    this.driverPosition,
    this.onSubmitOffer,
    this.isOfferSent = false,
  });

  @override
  State<DriverTripRouteMapScreen> createState() =>
      _DriverTripRouteMapScreenState();
}

class _DriverTripRouteMapScreenState extends State<DriverTripRouteMapScreen> {
  final MapController _mapController = MapController();
  Position? _currentDriverPosition;
  bool _isLoadingLocation = false;
  bool _hudVisible = true;

  double get _pickupLat =>
      (widget.trip['pickupLat'] as num?)?.toDouble() ?? 0.0;
  double get _pickupLng =>
      (widget.trip['pickupLng'] as num?)?.toDouble() ?? 0.0;
  double? get _dropoffLat => (widget.trip['dropoffLat'] as num?)?.toDouble();
  double? get _dropoffLng => (widget.trip['dropoffLng'] as num?)?.toDouble();

  String get _pickupAddress =>
      widget.trip['pickupAddress']?.toString() ?? 'نقطة الانطلاق غير محددة';
  String get _dropoffAddress =>
      widget.trip['dropoffAddress']?.toString() ?? 'الوجهة غير محددة';
  double get _fareEstimate =>
      (widget.trip['fareEstimate'] as num?)?.toDouble() ?? 0.0;
  String get _customerName =>
      (widget.trip['userName'] ?? widget.trip['customerName'])?.toString() ??
      'عميل زوون';

  @override
  void initState() {
    super.initState();
    _currentDriverPosition = widget.driverPosition;
    _fetchLiveDriverLocation();
  }

  Future<void> _fetchLiveDriverLocation() async {
    if (_currentDriverPosition != null) return;
    setState(() => _isLoadingLocation = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _currentDriverPosition = pos;
          _isLoadingLocation = false;
        });
        _fitRouteBounds();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // Distance 1: Driver to Customer (المسافة للعميل)
  double get _distanceToCustomerKm {
    if (_currentDriverPosition == null || _pickupLat == 0 || _pickupLng == 0) {
      return 0.0;
    }
    final meters = Geolocator.distanceBetween(
      _currentDriverPosition!.latitude,
      _currentDriverPosition!.longitude,
      _pickupLat,
      _pickupLng,
    );
    return meters / 1000.0;
  }

  // Time to customer (at ~35 km/h city avg)
  int get _minutesToCustomer {
    final km = _distanceToCustomerKm;
    if (km <= 0) return 2;
    final mins = (km / 35.0 * 60).round();
    return mins < 1 ? 1 : mins;
  }

  // Distance 2: Customer to Destination (المسافة من العميل للوجهة)
  double get _distanceCustomerToDropoffKm {
    if (widget.trip['distanceKm'] != null) {
      final d = (widget.trip['distanceKm'] as num).toDouble();
      if (d > 0) return d;
    }
    if (_dropoffLat != null && _dropoffLng != null && _pickupLat != 0) {
      final meters = Geolocator.distanceBetween(
        _pickupLat,
        _pickupLng,
        _dropoffLat!,
        _dropoffLng!,
      );
      return meters / 1000.0;
    }
    return 0.0;
  }

  // Time for the customer trip (at ~45 km/h)
  int get _minutesForTrip {
    final km = _distanceCustomerToDropoffKm;
    if (km <= 0) return 5;
    final mins = (km / 45.0 * 60).round();
    return mins < 1 ? 1 : mins;
  }

  // Total Distance (إجمالي المسافة)
  double get _totalDistanceKm =>
      _distanceToCustomerKm + _distanceCustomerToDropoffKm;

  void _fitRouteBounds() {
    final points = <LatLng>[];
    if (_currentDriverPosition != null) {
      points.add(LatLng(
          _currentDriverPosition!.latitude, _currentDriverPosition!.longitude));
    }
    if (_pickupLat != 0 && _pickupLng != 0) {
      points.add(LatLng(_pickupLat, _pickupLng));
    }
    if (_dropoffLat != null && _dropoffLng != null) {
      points.add(LatLng(_dropoffLat!, _dropoffLng!));
    }

    if (points.isNotEmpty) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 70),
          maxZoom: 16.0,
        ),
      );
    }
  }

  void _showOfferBottomSheet() {
    final fare = _fareEstimate > 0 ? _fareEstimate : 20.0;
    final controller = TextEditingController(text: fare.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff121620),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xff334155),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'تقديم عرض سعر للعميل',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'السعر المقترح للرحلة: ${fare.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                    color: Color(0xff94A3B8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [10, 20, 50].map((inc) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        backgroundColor: const Color(0xff1E293B),
                        side: const BorderSide(color: Color(0xff334155)),
                        label: Text(
                          '+$inc ج.م',
                          style: const TextStyle(
                            color: Color(0xffF97316),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () {
                          final cur = double.tryParse(controller.text) ?? fare;
                          controller.text = (cur + inc).toStringAsFixed(0);
                          setSheetState(() {});
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xff0B0E14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xff334155)),
                  ),
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      suffixText: 'ج.م ',
                      suffixStyle: TextStyle(
                        color: Color(0xffF97316),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                PressableScale(
                  onTap: () async {
                    final entered = double.tryParse(controller.text) ?? fare;
                    final nav = Navigator.of(context);
                    Navigator.pop(ctx);
                    if (widget.onSubmitOffer != null) {
                      await widget.onSubmitOffer!(entered);
                    }
                    if (!mounted) return;
                    nav.pop();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
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
                        Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'إرسال العرض للعميل',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _centerOnDriver() {
    if (_currentDriverPosition != null) {
      _mapController.move(
        LatLng(_currentDriverPosition!.latitude,
            _currentDriverPosition!.longitude),
        15.5,
      );
    }
  }

  void _centerOnPickup() {
    if (_pickupLat != 0 && _pickupLng != 0) {
      _mapController.move(LatLng(_pickupLat, _pickupLng), 15.5);
    }
  }

  void _centerOnDropoff() {
    if (_dropoffLat != null && _dropoffLng != null) {
      _mapController.move(LatLng(_dropoffLat!, _dropoffLng!), 15.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDriver = _currentDriverPosition != null;
    final hasDropoff = _dropoffLat != null && _dropoffLng != null;

    final initialCenter = _currentDriverPosition != null
        ? LatLng(_currentDriverPosition!.latitude,
            _currentDriverPosition!.longitude)
        : LatLng(_pickupLat != 0 ? _pickupLat : 31.0,
            _pickupLng != 0 ? _pickupLng : 30.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0B0E14),
        body: Stack(
          children: [
            // 1. Full-Screen Interactive Map
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                if (_hudVisible) setState(() => _hudVisible = false);
              },
              onPointerUp: (_) {
                if (!_hudVisible) setState(() => _hudVisible = true);
              },
              onPointerCancel: (_) {
                if (!_hudVisible) setState(() => _hudVisible = true);
              },
              child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 13.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onMapReady: () {
                  Future.delayed(
                      const Duration(milliseconds: 250), _fitRouteBounds);
                },
              ),
              children: [
                // Daytime Map Tiles
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.zoon.rideflow',
                  tileProvider: CancellableNetworkTileProvider(),
                ),

                // Polylines
                PolylineLayer(
                  polylines: [
                    // Segment 1: Driver to Customer (Cyan Glow + Dashed Core)
                    if (hasDriver && _pickupLat != 0 && _pickupLng != 0) ...[
                      Polyline(
                        points: [
                          LatLng(_currentDriverPosition!.latitude,
                              _currentDriverPosition!.longitude),
                          LatLng(_pickupLat, _pickupLng),
                        ],
                        color: const Color(0xff06B6D4).withOpacity(0.35),
                        strokeWidth: 9.0,
                      ),
                      Polyline(
                        points: [
                          LatLng(_currentDriverPosition!.latitude,
                              _currentDriverPosition!.longitude),
                          LatLng(_pickupLat, _pickupLng),
                        ],
                        color: const Color(0xff06B6D4),
                        strokeWidth: 4.0,
                        pattern:
                            StrokePattern.dashed(segments: const [8.0, 6.0]),
                      ),
                    ],

                    // Segment 2: Customer to Destination (Orange Glow + Dashed Core)
                    if (_pickupLat != 0 &&
                        _pickupLng != 0 &&
                        hasDropoff) ...[
                      Polyline(
                        points: [
                          LatLng(_pickupLat, _pickupLng),
                          LatLng(_dropoffLat!, _dropoffLng!),
                        ],
                        color: const Color(0xffF97316).withOpacity(0.35),
                        strokeWidth: 9.0,
                      ),
                      Polyline(
                        points: [
                          LatLng(_pickupLat, _pickupLng),
                          LatLng(_dropoffLat!, _dropoffLng!),
                        ],
                        color: const Color(0xffF97316),
                        strokeWidth: 4.0,
                        pattern:
                            StrokePattern.dashed(segments: const [10.0, 6.0]),
                      ),
                    ],
                  ],
                ),

                // Markers Layer
                MarkerLayer(
                  markers: [
                    // 1. Driver Current Location Marker (Cyan)
                    if (hasDriver)
                      Marker(
                        point: LatLng(_currentDriverPosition!.latitude,
                            _currentDriverPosition!.longitude),
                        width: 115,
                        height: 40,
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xff0B0E14).withOpacity(0.92),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xff06B6D4), width: 1.6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xff06B6D4).withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.navigation_rounded,
                                  color: Color(0xff06B6D4), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'موقعك (الكابتن)',
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

                    // 2. Customer Pickup Marker (Emerald Green)
                    if (_pickupLat != 0 && _pickupLng != 0)
                      Marker(
                        point: LatLng(_pickupLat, _pickupLng),
                        width: 120,
                        height: 40,
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xff0B0E14).withOpacity(0.92),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xff10B981), width: 1.6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xff10B981).withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_pin_circle_rounded,
                                  color: Color(0xff10B981), size: 15),
                              SizedBox(width: 4),
                              Text(
                                'العميل (الركوب)',
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

                    // 3. Dropoff Destination Marker (Orange)
                    if (hasDropoff)
                      Marker(
                        point: LatLng(_dropoffLat!, _dropoffLng!),
                        width: 120,
                        height: 40,
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xff0B0E14).withOpacity(0.92),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xffF97316), width: 1.6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffF97316).withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.flag_rounded,
                                  color: Color(0xffF97316), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'الوجهة (الوصول)',
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
            ),

            // 2. Top Header Bar (Glassmorphic Dark) - Hides on map touch
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
                          color: const Color(0xff121620).withOpacity(0.92),
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
                                  color: Colors.white, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'استعراض تفاصيل المسافات والمسار',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'طلب العميل: $_customerName',
                                    style: const TextStyle(
                                      color: Color(0xff94A3B8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Fare Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xffF97316)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xffF97316)
                                        .withOpacity(0.4)),
                              ),
                              child: Text(
                                '${_fareEstimate.toStringAsFixed(0)} ج.م',
                                style: const TextStyle(
                                  color: Color(0xffF97316),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
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
              top: 110,
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
                      const SizedBox(height: 8),
                      if (hasDropoff) ...[
                        _mapFloatingButton(
                          icon: Icons.flag_rounded,
                          color: const Color(0xffF97316),
                          tooltip: 'الوجهة',
                          onTap: _centerOnDropoff,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (hasDriver)
                        _mapFloatingButton(
                          icon: Icons.my_location_rounded,
                          color: const Color(0xff06B6D4),
                          tooltip: 'موقعي',
                          onTap: _centerOnDriver,
                        ),
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

                      // Two Primary Distance Cards Side-By-Side
                      Row(
                        children: [
                          // Box 1: Distance to Customer (المسافة للعميل)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xff0B0E14),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xff06B6D4)
                                      .withOpacity(0.4),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xff06B6D4)
                                              .withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.near_me_rounded,
                                          size: 14,
                                          color: Color(0xff06B6D4),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          'المسافة للعميل',
                                          style: TextStyle(
                                            color: Color(0xff94A3B8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    hasDriver
                                        ? '${_distanceToCustomerKm.toStringAsFixed(1)} كم'
                                        : (_isLoadingLocation ? 'جاري الحساب..' : 'غير محدد'),
                                    style: const TextStyle(
                                      color: Color(0xff06B6D4),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    hasDriver
                                        ? 'الوصول: ~$_minutesToCustomer دقيقة'
                                        : 'تحديد موقعك..',
                                    style: const TextStyle(
                                      color: Color(0xff64748B),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Box 2: Distance from Customer to Destination (من العميل للوجهة)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xff0B0E14),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xffF97316)
                                      .withOpacity(0.4),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xffF97316)
                                              .withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.flag_rounded,
                                          size: 14,
                                          color: Color(0xffF97316),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          'من العميل للوجهة',
                                          style: TextStyle(
                                            color: Color(0xff94A3B8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_distanceCustomerToDropoffKm.toStringAsFixed(1)} كم',
                                    style: const TextStyle(
                                      color: Color(0xffF97316),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'مدة الرحلة: ~$_minutesForTrip دقيقة',
                                    style: const TextStyle(
                                      color: Color(0xff64748B),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Route Addresses Strip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xff161B26),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xff1E293B)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.circle,
                                    color: Color(0xff10B981), size: 10),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'الركوب: $_pickupAddress',
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
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Color(0xffF97316), size: 12),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'الوصول: $_dropoffAddress',
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
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.alt_route_rounded,
                                    color: Color(0xff94A3B8), size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'إجمالي المسار التقديري: ${_totalDistanceKm.toStringAsFixed(1)} كم',
                                    style: const TextStyle(
                                      color: Color(0xffF97316),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Bottom Action: Submit Offer (Driver can only send offers, customer accepts)
                      if (widget.onSubmitOffer != null)
                        if (widget.isOfferSent)
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xff161B26),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xffF59E0B)
                                      .withOpacity(0.6)),
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.hourglass_top_rounded,
                                    color: Color(0xffF59E0B), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'تم إرسال عرضك • في انتظار موافقة العميل ⏳',
                                  style: TextStyle(
                                    color: Color(0xffF59E0B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          PressableScale(
                            onTap: _showOfferBottomSheet,
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xffF97316),
                                    Color(0xffEA580C)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xffF97316)
                                        .withOpacity(0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'تقديم عرض سعر للعميل (${_fareEstimate.toStringAsFixed(0)} ج.م) 🚀',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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

  Widget _mapFloatingButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    String? tooltip,
  }) {
    return Container(
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
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
