import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/network/api_client.dart';
import '../../data/datasources/trip_remote_data_source.dart';
import '../../data/repositories/trip_repository_impl.dart';
import '../payment/payment_method_screen.dart';
import '../payment/payment_confirmation_screen.dart';

class MapTripScreen extends StatefulWidget {
  const MapTripScreen({super.key});

  @override
  State<MapTripScreen> createState() => _MapTripScreenState();
}

class _MapTripScreenState extends State<MapTripScreen> {
  late final TextEditingController pickupController;
  late final TextEditingController dropoffController;
  final MapController _mapController = MapController();

  LatLng? currentLocation;
  LatLng? pickupLocation;
  LatLng? dropoffLocation;
  List<Marker> markers = [];
  List<Polyline> polylines = [];
  bool isLoading = false;

  double? distanceKm;
  int? durationMinutes;
  double? estimateFare;

  @override
  void initState() {
    super.initState();
    pickupController = TextEditingController(text: 'ميدان التحرير');
    dropoffController = TextEditingController(text: 'أهرامات الجيزة');
  }

  @override
  void dispose() {
    pickupController.dispose();
    dropoffController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    final location = LatLng(position.latitude, position.longitude);

    setState(() {
      currentLocation = location;
      pickupLocation = location;
      pickupController.text = 'Current Location';
    });

    _mapController.move(location, 14);

    _updateMapMarkers();
  }

  void _updateMapMarkers() {
    final newMarkers = <Marker>[];

    if (pickupLocation != null) {
      newMarkers.add(
        Marker(
          point: pickupLocation!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.green, size: 32),
        ),
      );
    }

    if (dropoffLocation != null) {
      newMarkers.add(
        Marker(
          point: dropoffLocation!,
          width: 40,
          height: 40,
          child: const Icon(Icons.flag, color: Colors.red, size: 32),
        ),
      );
    }

    markers = newMarkers;
  }

  void _buildRoute() {
    final pickup = pickupLocation ?? currentLocation ?? const LatLng(30.0444, 31.2357);
    final dropoff = dropoffLocation ?? const LatLng(29.9792, 31.1342);

    final calculatedDistance = _calculateDistanceKm(pickup, dropoff);
    final routeMinutes = (calculatedDistance / 30 * 60).round();
    final fare = (calculatedDistance * 4) + 3;

    setState(() {
      distanceKm = calculatedDistance;
      durationMinutes = routeMinutes;
      estimateFare = fare;
      polylines = [
        Polyline(
          points: [pickup, dropoff],
          color: Colors.deepPurple,
          strokeWidth: 5,
        ),
      ];
    });

    _updateMapMarkers();
  }

  double _calculateDistanceKm(LatLng start, LatLng end) {
    const earthRadiusKm = 6371.0;
    final startLat = start.latitude * pi / 180;
    final endLat = end.latitude * pi / 180;
    final deltaLat = (end.latitude - start.latitude) * pi / 180;
    final deltaLng = (end.longitude - start.longitude) * pi / 180;

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(startLat) * cos(endLat) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return double.parse((earthRadiusKm * c).toStringAsFixed(2));
  }

  Future<void> _requestTrip() async {
    if (pickupLocation == null || dropoffLocation == null) {
      return;
    }

    // 1. Select Payment Method
    final selectedMethod = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const PaymentMethodScreen(),
      ),
    );

    if (selectedMethod == null) return; // User canceled

    setState(() => isLoading = true);

    try {
      final repository = TripRepositoryImpl(
        TripRemoteDataSource(ApiClient()),
      );

      final trip = await repository.requestTrip(
        pickupAddress: pickupController.text,
        dropoffAddress: dropoffController.text,
        pickupLat: pickupLocation!.latitude,
        pickupLng: pickupLocation!.longitude,
        dropoffLat: dropoffLocation!.latitude,
        dropoffLng: dropoffLocation!.longitude,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trip requested successfully: ${trip.id}')),
      );

      // 2. Mocking Trip Completion for Phase 5 to show Payment Confirmation
      // In a real flow, this happens after the driver ends the trip.
      if (estimateFare != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentConfirmationScreen(
              tripId: trip.id,
              amount: estimateFare!,
              method: selectedMethod,
            ),
          ),
        );
      }

    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create trip: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = pickupLocation ?? currentLocation ?? const LatLng(30.0444, 31.2357);
    final dropoff = dropoffLocation ?? const LatLng(29.9792, 31.1342);
    return Scaffold(
      appBar: AppBar(title: const Text('RideFlow Maps')),
      body: Stack(
        children: [
          FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(30.0444, 31.2357),
                initialZoom: 13,
                interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.zoon.rideflow',
                  tileProvider: CancellableNetworkTileProvider(),
                ),
                MarkerLayer(markers: markers),
                PolylineLayer(polylines: polylines),
              ],
            ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: pickupController,
                    decoration: const InputDecoration(
                      hintText: 'Pickup location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: dropoffController,
                    decoration: const InputDecoration(
                      hintText: 'Destination',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              pickupLocation = pickup;
                              dropoffLocation = dropoff;
                            });
                            _updateMapMarkers();
                            _buildRoute();
                          },
                          icon: const Icon(Icons.route),
                          label: const Text('Show Route'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loadCurrentLocation,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Current Location'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pickup: ${pickupController.text}', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text('Dropoff: ${dropoffController.text}', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text('Distance: ${distanceKm ?? 0.0} km')),
                        Expanded(child: Text('Time: ${durationMinutes ?? 0} min')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text('Estimated Fare: ${estimateFare?.toStringAsFixed(2) ?? '0.00'}')),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isLoading ? null : _requestTrip,
                            icon: isLoading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.local_taxi),
                            label: const Text('Request Trip'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
