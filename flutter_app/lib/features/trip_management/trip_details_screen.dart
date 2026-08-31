import 'package:flutter/material.dart';

import '../../domain/entities/trip.dart';
import 'trip_rating_screen.dart';

class TripDetailsScreen extends StatelessWidget {
  const TripDetailsScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trip ${trip.id}', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('Pickup: ${trip.pickupAddress}'),
                      const SizedBox(height: 4),
                      Text('Dropoff: ${trip.dropoffAddress}'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text(trip.status)),
                          Chip(label: Text('${trip.distanceKm.toStringAsFixed(1)} km')),
                          Chip(label: Text('${trip.remainingMinutes} min left')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Name: ${trip.userName}'),
                      Text('Phone: ${trip.userPhone}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Driver', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Name: ${trip.driverName}'),
                      Text('Phone: ${trip.driverPhone}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fare Summary', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Estimated Fare: ${trip.fareEstimate.toStringAsFixed(2)}'),
                      Text('Final Fare: ${trip.finalFare.toStringAsFixed(2)}'),
                      Text('Distance: ${trip.distanceKm.toStringAsFixed(1)} km'),
                      Text('Duration: ${trip.durationMinutes} min'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TripRatingScreen(tripId: trip.id),
                    ),
                  );
                },
                icon: const Icon(Icons.star_border),
                label: const Text('Rate Driver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
