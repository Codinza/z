import 'dart:async';
import 'dart:math' as math;

import 'package:app_links/app_links.dart';
import 'package:latlong2/latlong.dart';

class LocationDeepLinkService {
  LocationDeepLinkService._();

  static final instance = LocationDeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  final StreamController<LatLng> _locationController =
      StreamController<LatLng>.broadcast();
  StreamSubscription<Uri>? _subscription;
  LatLng? _pendingLocation;

  Stream<LatLng> get locations => _locationController.stream;

  Future<void> initialize() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      _acceptUri(initialUri);
    } catch (_) {}

    _subscription = _appLinks.uriLinkStream.listen(_acceptUri);
  }

  LatLng? consumeLocation() {
    final location = _pendingLocation;
    _pendingLocation = null;
    return location;
  }

  void _acceptUri(Uri? uri) {
    final location = _parseLocation(uri);
    if (location == null) return;
    _pendingLocation = location;
    if (!_locationController.isClosed) {
      _locationController.add(location);
    }
  }

  LatLng? _parseLocation(Uri? uri) {
    if (uri == null) return null;

    final rawValues = <String>[
      if (uri.scheme.toLowerCase() == 'geo') uri.path,
      uri.queryParameters['q'] ?? '',
      uri.queryParameters['query'] ?? '',
      uri.queryParameters['destination'] ?? '',
      uri.queryParameters['ll'] ?? '',
      uri.toString(),
    ];

    for (final raw in rawValues) {
      final match = RegExp(
        r'(-?\d{1,3}(?:\.\d+)?)\s*[,;]\s*(-?\d{1,3}(?:\.\d+)?)',
      ).firstMatch(Uri.decodeFull(raw));
      if (match == null) continue;

      final latitude = double.tryParse(match.group(1)!);
      final longitude = double.tryParse(match.group(2)!);
      if (latitude == null || longitude == null) continue;
      if (latitude.abs() > 90 || longitude.abs() > 180) continue;
      if (latitude.abs() < math.pow(10, -6) &&
          longitude.abs() < math.pow(10, -6)) {
        continue;
      }
      return LatLng(latitude, longitude);
    }
    return null;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _locationController.close();
  }
}
