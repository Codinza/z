import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/config/app_config.dart';
import '../../domain/entities/trip.dart';
import 'trip_details_screen.dart';
import 'trip_history_screen.dart';

class TripManagementScreen extends StatefulWidget {
  const TripManagementScreen({super.key});

  @override
  State<TripManagementScreen> createState() => _TripManagementScreenState();
}

class _TripManagementScreenState extends State<TripManagementScreen> {
  String _currentStatus = 'pending';
  double _remainingDistanceKm = 4.2;
  int _remainingMinutes = 12;
  bool _isLoading = false;
  Map<String, dynamic>? _currentTrip;

  final List<String> _statusOrder = const [
    'pending',
    'accepted',
    'driver_arriving',
    'driver_arrived',
    'started',
    'completed',
    'cancelled',
  ];

  final Trip _trip = const Trip(
    id: 'ride_demo_001',
    pickupAddress: 'Riyadh Main Street',
    dropoffAddress: 'King Fahd Road',
    status: 'pending',
    fareEstimate: 18.5,
    driverName: 'كابتن زوون',
    driverPhone: '01505175915',
    userName: 'أيمن',
    userPhone: '01273381289',
    distanceKm: 4.2,
    durationMinutes: 12,
    remainingDistanceKm: 4.2,
    remainingMinutes: 12,
    finalFare: 18.5,
  );

  @override
  void initState() {
    super.initState();
    _fetchLatestTrip();
  }

  Future<void> _fetchLatestTrip() async {
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
        
        if (rides.isNotEmpty) {
          final latestTrip = rides.first;
          setState(() {
            _currentTrip = latestTrip;
            _currentStatus = latestTrip['status'] ?? 'pending';
            _remainingDistanceKm = (latestTrip['remainingDistanceKm'] as num?)?.toDouble() ?? 4.2;
            _remainingMinutes = latestTrip['remainingMinutes'] ?? 12;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTripStatus(String newStatus) async {
    if (_currentTrip == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/trips/${_currentTrip!['id']}/$newStatus'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _currentTrip = data['ride'];
          _currentStatus = data['ride']['status'];
          _remainingDistanceKm = (data['ride']['remainingDistanceKm'] as num?)?.toDouble() ?? _remainingDistanceKm;
          _remainingMinutes = data['ride']['remainingMinutes'] ?? _remainingMinutes;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Trip status updated to $newStatus')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating trip: $e')),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.blue;
      case 'driver_arriving':
        return Colors.orange;
      case 'driver_arrived':
        return Colors.deepOrange;
      case 'started':
        return Colors.green;
      case 'completed':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.deepPurple;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'driver_arriving':
        return 'Driver Arriving';
      case 'driver_arrived':
        return 'Driver Arrived';
      case 'started':
        return 'Started';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  void _updateStatus(String newStatus) {
    _updateTripStatus(newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(_currentStatus);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Management'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Current Trip Status',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Chip(
                          label: Text(_statusLabel(_currentStatus)),
                          backgroundColor: statusColor.withOpacity(0.18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        'Trip ${_currentTrip?['id'] ?? _trip.id}',
                        key: ValueKey<String>(_currentStatus),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_currentTrip?['pickupAddress'] ?? _trip.pickupAddress} → ${_currentTrip?['dropoffAddress'] ?? _trip.dropoffAddress}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Remaining Distance'),
                              Text('${_remainingDistanceKm.toStringAsFixed(1)} km', style: Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Remaining Time'),
                              Text('$_remainingMinutes min', style: Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _statusOrder.map((status) {
                          final isSelected = _currentStatus == status;
                          return ChoiceChip(
                            label: Text(_statusLabel(status)),
                            selected: isSelected,
                            onSelected: (_) => _updateStatus(status),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _currentStatus == 'cancelled' || _currentStatus == 'completed' || _isLoading
                          ? null
                          : () {
                              _updateTripStatus('cancel');
                            },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel Trip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TripDetailsScreen(trip: _trip.copyWith(status: _currentStatus, remainingDistanceKm: _remainingDistanceKm, remainingMinutes: _remainingMinutes)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Trip Details'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TripHistoryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('Previous Trips'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
