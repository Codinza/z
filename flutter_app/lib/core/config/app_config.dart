import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _productionBackendUrl =
      'https://zoon-api.onrender.com';

  static String get backendBaseUrl {
    const envUrl = String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: _productionBackendUrl,
    );

    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    return _productionBackendUrl;
  }

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Render free plan can take ~30s to wake up (cold start)
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Retry settings for failed requests (e.g. server waking up)
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}
