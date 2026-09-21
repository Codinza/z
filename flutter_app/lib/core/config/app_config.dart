
class AppConfig {
  static const String _productionBackendUrl = 'https://z-production-acea.up.railway.app';

  // Keep the local URL only as an override for debugging
  static const String _localBackendUrl = 'http://192.168.100.6:4000';

  static String get localBackendUrl => _localBackendUrl;

  /// Public legal pages required by Google Play (must stay reachable over HTTPS).
  static String get privacyPolicyUrl => '$backendBaseUrl/privacy-policy';
  static String get accountDeletionUrl => '$backendBaseUrl/account-deletion';
  static String get termsUrl => '$backendBaseUrl/terms';

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
  static const Duration sendTimeout = Duration(seconds: 120);

  /// Retry settings for failed requests (e.g. server waking up)
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}
