import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.title = 'اختر الموقع',
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _selectedLocation != null
                ? () => Navigator.pop(context, _selectedLocation)
                : null,
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: widget.initialLocation ?? const LatLng(30.80, 29.60), // Borg El Arab New, Egypt
          initialZoom: 14.0,
          onTap: _onMapTap,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.rideflow',
            tileProvider: CancellableNetworkTileProvider(),
          ),
          if (_selectedLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _selectedLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_on,
                    size: 40,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedLocation != null) {
            _mapController.move(_selectedLocation!, 16.0);
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
