
class AppConfig {
  static const String _productionBackendUrl = 'https://zoon-api.onrender.com';

  // Keep the local URL only as an override for debugging, but production builds
  // should default to the live backend instead of the developer machine.
  static const String _localBackendUrl = 'http://192.168.100.6:4000';

  static String get localBackendUrl => _localBackendUrl;

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

  /// Render free plan can take ~30s to wake up (cold start)
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Retry settings for failed requests (e.g. server waking up)
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}
