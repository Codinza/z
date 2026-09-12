import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../../core/network/api_client.dart';
import '../../core/services/notification_service.dart';
import '../../core/config/app_config.dart';
import 'active_trip_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

class WaitingForOffersScreen extends StatefulWidget {
  final String tripId;
  final double pickupLat;
  final double pickupLng;
  final double estimateFare;

  const WaitingForOffersScreen({
    super.key,
    required this.tripId,
    required this.pickupLat,
    required this.pickupLng,
    required this.estimateFare,
  });

  @override
  State<WaitingForOffersScreen> createState() => _WaitingForOffersScreenState();
}

class _WaitingForOffersScreenState extends State<WaitingForOffersScreen> {
  socket_io.Socket? _socket;
  final List<Map<String, dynamic>> _offers = [];
  bool _isAccepting = false;
  bool _isAccepted = false;
  double? _acceptedAmount;
  double? _actualEstimateFare;
  String _tripStatus = 'pending';
  Timer? _locationTimer;
  List<LatLng> _driverLocations = [];

  @override
  void initState() {
    super.initState();
    _initSocket();
    _fetchExistingOffers();
    _fetchDriverLocations();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchDriverLocations());
  }

  Future<void> _fetchDriverLocations() async {
    if (!mounted || _isAccepted) return;
    try {
      final response = await ApiClient().dio.get('/api/locations');
      if (response.statusCode == 200 && response.data['locations'] != null) {
        final List<dynamic> locations = response.data['locations'];
        if (mounted) {
          setState(() {
            _driverLocations = locations.map((loc) => LatLng(
              (loc['lat'] as num).toDouble(),
              (loc['lng'] as num).toDouble(),
            )).toList();
          });
        }
      }
    } catch (e) {
      // Ignore errors for location updates
    }
  }

  Future<void> _fetchExistingOffers() async {
    try {
      final response = await ApiClient().dio.get('/api/trips/${widget.tripId}');
      debugPrint('Fetch trip response: ${response.data}');
      if (response.statusCode == 200 && response.data['trip'] != null) {
        final tripData = response.data['trip'];
        final status = tripData['status'] ?? 'pending';
        
        if (mounted) {
          if (status == 'accepted' || status == 'driver_arriving' || status == 'driver_arrived' || status == 'started' || status == 'start') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ActiveTripScreen(
                  tripId: widget.tripId,
                  pickupLat: widget.pickupLat,
                  pickupLng: widget.pickupLng,
                ),
              ),
            );
            return;
          }
          
          if (tripData['offers'] != null) {
            final List<dynamic> offers = tripData['offers'];
            setState(() {
              _actualEstimateFare = (tripData['fareEstimate'] as num?)?.toDouble();
              _offers.clear();
              for (var offer in offers) {
                _offers.add({
                  'rideId': widget.tripId,
                  'driverId': offer['driverId'],
                  'offerAmount': offer['offerAmount'],
                  'timestamp': offer['timestamp'],
                });
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تم استرجاع ${offers.length} عروض سابقة!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('لا توجد عروض سابقة محفوظة لهذه الرحلة')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل العثور على بيانات الرحلة')),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch existing offers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء جلب العروض: $e')),
        );
      }
    }
  }

  void _initSocket() {
    _socket = socket_io.io(AppConfig.backendBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    _socket!.connect();

    _socket!.on('driver_offer', (data) {
      if (data['rideId'] == widget.tripId) {
        if (mounted && !_isAccepted) {
          setState(() {
            _offers.add(data);
          });
          NotificationService().showNotification(
            id: 3,
            title: 'عرض جديد من كابتن! 💰',
            body: 'كابتن يعرض ${data['offerAmount'] ?? data['fareEstimate']} ج.م',
          );
        }
      }
    });

    // Listen for status changes (in case another device accepts or driver changes status)
    _socket!.on('trip_status_changed', _handleStatusChange);
  }

  void _handleStatusChange(dynamic data) {
    if (data['rideId'] != widget.tripId) return;
    if (!mounted) return;

    final status = data['status'];
    setState(() {
      _tripStatus = status;
    });

    NotificationService().showNotification(
      id: 4,
      title: 'تحديث حالة الرحلة',
      body: _getArabicStatus(status),
    );

    if (status == 'accepted' || status == 'driver_arriving' || status == 'driver_arrived' || status == 'started' || status == 'start') {
      // If not already on the accepted screen, navigate
      if (!_isAccepted) {
        setState(() {
          _isAccepted = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

  Future<void> _acceptDriverOffer(String driverId, dynamic offerAmount) async {
    setState(() => _isAccepting = true);
    try {
      final response = await ApiClient().dio.post(
        '/api/trips/${widget.tripId}/accept',
        data: {
          'driverId': driverId,
          'offerAmount': offerAmount,
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _isAccepted = true;
          _isAccepting = false;
          _acceptedAmount = (offerAmount as num?)?.toDouble();
          _tripStatus = 'accepted';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول العرض! في انتظار تحرك الكابتن...')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting offer: ${e.response?.data ?? e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting offer: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  String _getArabicStatus(String status) {
    switch (status) {
      case 'accepted': return 'تم القبول (في انتظار تحرك الكابتن)';
      case 'driver_arriving': return 'الكابتن في الطريق إليك';
      case 'driver_arrived': return 'الكابتن وصل وهو بالخارج';
      case 'started': return 'بدأت الرحلة';
      case 'completed': return 'انتهت الرحلة';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isAccepted ? 'حالة الرحلة' : 'انتظار السائقين'),
          backgroundColor: _isAccepted ? Colors.green : Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isAccepted ? _buildAcceptedView() : _buildSearchingView(),
        ),
      ),
    );
  }

  Widget _buildAcceptedView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Icon(Icons.check_circle, size: 80, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'تم قبول الكابتن!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 12),
                Text(
                  _getArabicStatus(_tripStatus),
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                if (_acceptedAmount != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'السعر المتفق عليه: ${_acceptedAmount!.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActiveTripScreen(
                            tripId: widget.tripId,
                            pickupLat: widget.pickupLat,
                            pickupLng: widget.pickupLng,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('تتبع الكابتن على الخريطة', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(widget.pickupLat, widget.pickupLng),
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.zoon.app',
                  tileProvider: CancellableNetworkTileProvider(),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.pickupLat, widget.pickupLng),
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on, color: Colors.blue, size: 50),
                    ),
                    ..._driverLocations.map((loc) => Marker(
                      point: loc,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.local_taxi, color: Colors.amber, size: 40),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'جاري البحث عن كابتن...',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'السعر المقترح: ${(_actualEstimateFare ?? widget.estimateFare).toStringAsFixed(2)} ج.م',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'العروض المقدمة:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 5,
          child: _offers.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد عروض حتى الآن، يرجى الانتظار...',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  itemCount: _offers.length,
                  itemBuilder: (context, index) {
                    final offer = _offers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.local_taxi),
                        ),
                        title: const Text('كابتن متاح'),
                        subtitle: Text('يعرض ${offer['offerAmount']} ج.م'),
                        trailing: _isAccepting
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: () => _acceptDriverOffer(
                                    offer['driverId'], offer['offerAmount']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('قبول'),
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
