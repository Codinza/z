import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';

class AuthService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.backendBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    sendTimeout: AppConfig.sendTimeout,
  ));
  static Dio? _authenticatedDio;

  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userRoleKey = 'user_role';
  static const String _userNameKey = 'user_name';
  static const String _driverStatusKey = 'driver_status';
  static const String _companyIdKey = 'company_id';

  static Future<Dio> getAuthenticatedDio() async {
    final token = await getToken();
    if (_authenticatedDio == null || token == null) {
      _authenticatedDio = Dio(BaseOptions(
        baseUrl: AppConfig.backendBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      ));
    } else {
      _authenticatedDio!.options.headers['Authorization'] = 'Bearer $token';
    }
    return _authenticatedDio!;
  }

  static Future<Map<String, dynamic>?> register({
    required String name,
    required String phone,
    required String password,
    String? email,
    String role = 'customer',
    String? carModel,
    String? carColor,
    String? carYear,
    String? plateNumber,
  }) async {
    try {
      final response = await _dio.post('/api/auth/register', data: {
        'name': name, 'phone': phone, 'password': password,
        'email': email, 'role': role,
        'carModel': carModel, 'carColor': carColor, 'carYear': carYear, 'plateNumber': plateNumber,
      });
      if (response.statusCode == 201) {
        await _saveAuthData(response.data);
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      return e.response?.data;
    }
  }

  static Future<Map<String, dynamic>?> login({required String phone, required String password}) async {
    try {
      final isEmail = phone.contains('@');
      final response = await _dio.post('/api/auth/login', data: {
        if (!isEmail) 'phone': phone,
        if (isEmail) 'email': phone,
        'password': password,
      });
      if (response.statusCode == 200) {
        await _saveAuthData(response.data);
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        return responseData;
      }
      return {
        'error': e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout
            ? 'تعذر الاتصال بالخادم. تأكد من تشغيل الخادم الخلفي.'
            : 'فشل تسجيل الدخول. حاول مرة أخرى.',
      };
    }
  }

  static Future<Map<String, dynamic>?> loginAsGuest(String role) async {
    if (role != 'customer') return null;

    try {
      final response = await _dio.post('/api/auth/guest');
      if (response.statusCode == 200) {
        await _saveAuthData(response.data);
        return response.data;
      }
    } on DioException {
      // Fallback for local/offline development: keep the app usable without the backend.
    }

    final fallbackUser = {
      'id': 'guest_customer_local',
      'name': 'زائر العميل',
      'phone': 'guest_customer_001',
      'role': 'customer',
    };

    final fallbackData = {
      'message': 'Guest login successful (offline fallback)',
      'user': fallbackUser,
      'accessToken': 'local_guest_token',
      'refreshToken': 'local_guest_refresh_token',
    };

    await _saveAuthData(fallbackData);
    return fallbackData;
  }

  static Future<void> _saveAuthData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, data['accessToken'] ?? '');
    await prefs.setString(_refreshTokenKey, data['refreshToken'] ?? '');
    final user = data['user'];
    if (user != null) {
      await prefs.setString(_userIdKey, user['id'] ?? '');
      await prefs.setString(_userRoleKey, user['role'] ?? 'customer');
      await prefs.setString(_userNameKey, user['name'] ?? '');
      if (user['driverStatus'] != null) {
        await prefs.setString(_driverStatusKey, user['driverStatus']);
      }
      if (user['companyId'] != null) {
        await prefs.setString(_companyIdKey, user['companyId']);
      }
    }
    // Reset authenticated dio to use new token
    _authenticatedDio = null;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> getDriverStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_driverStatusKey);
  }

  static Future<String?> getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_companyIdKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_driverStatusKey);
    await prefs.remove(_companyIdKey);
    _authenticatedDio = null;
  }
}
