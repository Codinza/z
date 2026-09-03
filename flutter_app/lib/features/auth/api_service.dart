import 'package:dio/dio.dart';
import '../../core/config/app_config.dart';
import 'auth_service.dart';

class ApiService {
  static Dio _getDio() {
    return Dio(
      BaseOptions(
        baseUrl: '${AppConfig.backendBaseUrl}/api',
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
      ),
    );
  }

  static void _setupInterceptors(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token to headers
          final token = await AuthService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Token expired, user needs to login again
            AuthService.logout();
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Customer Profile
  static Future<Map<String, dynamic>> getCustomerProfile() async {
    final dio = _getDio();
    _setupInterceptors(dio);
    try {
      final response = await dio.get('/customers/profile');
      return response.data ?? {};
    } catch (e) {
      throw Exception('Failed to load profile: $e');
    }
  }

  // Customer Balance and Transactions
  static Future<Map<String, dynamic>> getCustomerBalance() async {
    final dio = _getDio();
    _setupInterceptors(dio);
    try {
      final response = await dio.get('/customers/balance');
      return response.data ?? {};
    } catch (e) {
      throw Exception('Failed to load balance: $e');
    }
  }

  // Customer Orders (Past Trips)
  static Future<List<dynamic>> getCustomerOrders({int limit = 10, int skip = 0}) async {
    final dio = _getDio();
    _setupInterceptors(dio);
    try {
      final response = await dio.get('/customers/orders', queryParameters: {
        'limit': limit,
        'skip': skip,
      });
      return response.data ?? [];
    } catch (e) {
      throw Exception('Failed to load orders: $e');
    }
  }

  // Customer Trips History
  static Future<List<dynamic>> getTripsHistory() async {
    final dio = _getDio();
    _setupInterceptors(dio);
    try {
      final response = await dio.get('/customers/trips-history');
      return response.data ?? [];
    } catch (e) {
      throw Exception('Failed to load trips history: $e');
    }
  }

  // Add Funds to Wallet
  static Future<Map<String, dynamic>> addFunds(double amount) async {
    final dio = _getDio();
    _setupInterceptors(dio);
    try {
      final response = await dio.post('/customers/add-funds', data: {'amount': amount});
      return response.data ?? {};
    } catch (e) {
      throw Exception('Failed to add funds: $e');
    }
  }
}
