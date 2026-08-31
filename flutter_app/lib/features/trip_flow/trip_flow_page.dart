import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class TripFlowPage extends StatefulWidget {
  const TripFlowPage({super.key});

  @override
  State<TripFlowPage> createState() => _TripFlowPageState();
}

class _TripFlowPageState extends State<TripFlowPage> {
  String status = 'Idle';
  String? rideId;

  Future<void> requestRide() async {
    final response = await http.post(
      Uri.parse('${AppConfig.backendBaseUrl}/api/trips/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pickupAddress': 'Riyadh Main Street',
        'dropoffAddress': 'King Fahd Road',
        'pickupLat': 24.7136,
        'pickupLng': 46.6753,
        'dropoffLat': 24.7517,
        'dropoffLng': 46.7161,
      }),
    );

    final data = jsonDecode(response.body);
    setState(() {
      rideId = data['ride']['id'];
      status = 'Ride requested';
    });
  }

  Future<void> assignDriver() async {
    if (rideId == null) return;
    await http.post(Uri.parse('${AppConfig.backendBaseUrl}/api/trips/$rideId/assign'));
    setState(() => status = 'Driver assigned');
  }

  Future<void> acceptRide() async {
    if (rideId == null) return;
    await http.post(Uri.parse('${AppConfig.backendBaseUrl}/api/trips/$rideId/accept'));
    setState(() => status = 'Driver accepted');
  }

  Future<void> startRide() async {
    if (rideId == null) return;
    await http.post(Uri.parse('${AppConfig.backendBaseUrl}/api/trips/$rideId/start'));
    setState(() => status = 'Ride in progress');
  }

  Future<void> completeRide() async {
    if (rideId == null) return;
    await http.post(Uri.parse('${AppConfig.backendBaseUrl}/api/trips/$rideId/complete'));
    setState(() => status = 'Ride completed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RideFlow Phase 1'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Current state: $status', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Ride ID: ${rideId ?? 'not created yet'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: requestRide,
              icon: const Icon(Icons.local_taxi),
              label: const Text('Request Ride'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: assignDriver,
              icon: const Icon(Icons.person_search),
              label: const Text('Assign Driver'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: acceptRide,
              icon: const Icon(Icons.check_circle),
              label: const Text('Accept Ride'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: startRide,
              icon: const Icon(Icons.directions_car),
              label: const Text('Start Ride'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: completeRide,
              icon: const Icon(Icons.flag),
              label: const Text('Complete Ride'),
            ),
          ],
        ),
      ),
    );
  }
}
