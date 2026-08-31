import 'package:flutter/material.dart';

class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = [
      'ride_2026_001 · Completed · 9.2 km',
      'ride_2026_002 · Completed · 6.1 km',
      'ride_2026_003 · Cancelled · 0 km',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Previous Trips')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(history[index]),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }
}
