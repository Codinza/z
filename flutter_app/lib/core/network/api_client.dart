import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiClient {
  ApiClient()
      : _dio = Dio(BaseOptions(
          baseUrl: AppConfig.backendBaseUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          sendTimeout: AppConfig.sendTimeout,
        )) {
    // Retry interceptor for connection errors (handles Render cold starts)
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (_shouldRetry(error)) {
          final retryCount = error.requestOptions.extra['retryCount'] ?? 0;
          if (retryCount < AppConfig.maxRetries) {
            debugPrint(
                '[ApiClient] Retrying request (${retryCount + 1}/${AppConfig.maxRetries})...');
            await Future.delayed(
                AppConfig.retryDelay * (retryCount + 1)); // Exponential backoff
            error.requestOptions.extra['retryCount'] = retryCount + 1;
            try {
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
        }
        handler.next(error);
      },
    ));

    // Auth interceptor for JWT token injection and refresh
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final request = error.requestOptions;
          final prefs = await SharedPreferences.getInstance();
          final refreshToken = prefs.getString('refresh_token');

          if (refreshToken != null &&
              refreshToken.isNotEmpty &&
              request.extra['retried'] != true) {
            try {
              final refreshResponse = await Dio(
                BaseOptions(
                  baseUrl: AppConfig.backendBaseUrl,
                  connectTimeout: AppConfig.connectTimeout,
                  receiveTimeout: AppConfig.receiveTimeout,
                ),
              ).post('/api/auth/refresh',
                  data: {'refreshToken': refreshToken});
              final accessToken =
                  refreshResponse.data['accessToken'] as String?;
              final newRefreshToken =
                  refreshResponse.data['refreshToken'] as String?;
              if (accessToken != null && accessToken.isNotEmpty) {
                await prefs.setString('access_token', accessToken);
                if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
                  await prefs.setString('refresh_token', newRefreshToken);
                }
                request.headers['Authorization'] = 'Bearer $accessToken';
                request.extra['retried'] = true;
                return handler.resolve(await _dio.fetch(request));
              }
            } on DioException catch (refreshError) {
              request.extra['refresh_error'] = refreshError.type.name;
            }
          }

          await prefs.remove('access_token');
          await prefs.remove('refresh_token');
        }
        handler.next(error);
      },
    ));
  }

  final Dio _dio;
  Dio get dio => _dio;

  /// Check if this error type should trigger a retry
  bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.sendTimeout ||
        (error.type == DioExceptionType.unknown && error.error != null);
  }
}
