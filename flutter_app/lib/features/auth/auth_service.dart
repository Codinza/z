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
  static const String _userPhoneKey = 'user_phone';
  static const String _driverStatusKey = 'driver_status';
  static const String _companyIdKey = 'company_id';
  static const String _vehicleCategoryKey = 'vehicle_category';
  static const String _driverProfileIdKey = 'driver_profile_id';
  /// Phone waiting for OTP — blocks login until verify succeeds (client gate
  /// while legacy servers still issue tokens without phoneVerified).
  static const String _pendingOtpPhoneKey = 'pending_otp_phone';

  /// Normalize Egyptian mobiles for comparison (01xxxxxxxxx).
  static String normalizePhoneKey(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('20') && digits.length >= 12) {
      digits = digits.substring(2);
    }
    if (digits.length == 10 && digits.startsWith('1')) {
      digits = '0$digits';
    }
    return digits;
  }

  static Future<void> markPhoneAwaitingOtp(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final key = normalizePhoneKey(phone);
    if (key.isEmpty) return;
    await prefs.setString(_pendingOtpPhoneKey, key);
    // Drop any accidental session so leaving OTP cannot keep the user signed in.
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    _authenticatedDio = null;
  }

  static Future<void> clearPhoneAwaitingOtp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingOtpPhoneKey);
  }

  static Future<bool> isPhoneAwaitingOtp(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_pendingOtpPhoneKey);
    if (pending == null || pending.isEmpty) return false;
    return pending == normalizePhoneKey(phone);
  }

  static Future<bool> hasPendingOtpGate() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_pendingOtpPhoneKey);
    return pending != null && pending.isNotEmpty;
  }

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
    String? vehicleCategory,
  }) async {
    try {
      final response = await _dio.post('/api/auth/register', data: {
        'name': name, 'phone': phone, 'password': password,
        'email': email?.trim().isEmpty == true ? null : email?.trim(), 'role': role,
        'carModel': carModel, 'carColor': carColor, 'carYear': carYear, 'plateNumber': plateNumber,
        if (role == 'driver')
          'vehicleCategory': vehicleCategory == 'motorcycle' ? 'motorcycle' : 'car',
      });
      if (response.statusCode == 201) {
        final data = Map<String, dynamic>.from(response.data as Map);
        // Never open a session from /register — even if a legacy server returns
        // tokens. OTP confirmation is the only path that may save auth data.
        data.remove('accessToken');
        data.remove('refreshToken');
        data['requiresVerification'] = true;
        data['phone'] ??= phone;
        await markPhoneAwaitingOtp((data['phone'] ?? phone).toString());
        return data;
      }
      return null;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map) {
        return Map<String, dynamic>.from(responseData);
      }
      return {
        'error': e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout
            ? 'تعذر الاتصال بالخادم. تأكد من اتصال الإنترنت وحاول مرة أخرى.'
            : 'فشل إنشاء الحساب. حاول مرة أخرى.',
      };
    }
  }

  static Future<Map<String, dynamic>?> verifyPhone({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _dio.post('/api/auth/verify-phone', data: {
        'phone': phone,
        'code': code,
      });
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(response.data as Map);
        await clearPhoneAwaitingOtp();
        await _saveAuthData(data);
        return data;
      }
      return null;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map) {
        return Map<String, dynamic>.from(responseData);
      }
      return {
        'error': e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout
            ? 'تعذر الاتصال بالخادم. تأكد من اتصال الإنترنت وحاول مرة أخرى.'
            : 'فشل تأكيد رقم الموبايل. حاول مرة أخرى.',
      };
    }
  }

  static Future<Map<String, dynamic>?> resendVerificationCode({
    required String phone,
  }) async {
    try {
      final response = await _dio.post('/api/auth/resend-code', data: {
        'phone': phone,
      });
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return null;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map) {
        return Map<String, dynamic>.from(responseData);
      }
      return {
        'error': e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout
            ? 'تعذر الاتصال بالخادم. تأكد من اتصال الإنترنت وحاول مرة أخرى.'
            : 'فشل إرسال الكود. حاول مرة أخرى.',
      };
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
        final data = Map<String, dynamic>.from(response.data as Map);
        final responsePhone = data['user']?['phone']?.toString() ?? '';
        final verifiedFlag = data['user']?['phoneVerified'];
        final explicitlyUnverified = verifiedFlag == false;
        final gated = (!isEmail && await isPhoneAwaitingOtp(phone)) ||
            await isPhoneAwaitingOtp(responsePhone);
        if (explicitlyUnverified || gated) {
          // Legacy servers may return tokens before phoneVerified — do not
          // open a session until OTP succeeds on this device.
          data.remove('accessToken');
          data.remove('refreshToken');
          data['requiresVerification'] = true;
          data['phone'] = responsePhone.isNotEmpty ? responsePhone : phone;
          data['error'] =
              'لازم تأكد رقم الموبايل بالكود قبل الدخول. اطلب الكود من الشاشة التالية.';
          await markPhoneAwaitingOtp(data['phone'].toString());
          return data;
        }
        await _saveAuthData(data);
        return data;
      }
      return null;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map) {
        final data = Map<String, dynamic>.from(responseData);
        if (data['requiresVerification'] == true) {
          final p = (data['phone'] ?? phone).toString();
          await markPhoneAwaitingOtp(p);
        }
        return data;
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
      'accessToken': '',
      'refreshToken': '',
    };

    await _saveAuthData(fallbackData);
    return fallbackData;
  }

  static Future<Map<String, dynamic>?> registerCompany({
    required String companyName,
    required String companyType,
    required String contactPerson,
    required String phone,
    required String password,
    String? email,
    String? address,
  }) async {
    try {
      final response = await _dio.post('/api/company/register', data: {
        'companyName': companyName,
        'companyType': companyType,
        'contactPerson': contactPerson,
        'phone': phone,
        'password': password,
        'email': email?.trim().isEmpty == true ? null : email?.trim(),
        'address': address ?? 'العنوان الافتراضي',
      });
      if (response.statusCode == 201 || response.statusCode == 200) {
        await _saveAuthData(response.data);
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        return responseData;
      }
      return {'error': 'فشل التسجيل: ${e.message}'};
    }
  }

  static Future<Map<String, dynamic>?> loginCompany({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/api/company/login', data: {
        'phone': phone,
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
            : 'فشل تسجيل الدخول. تأكد من البيانات.',
      };
    }
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
      if (user['phone'] != null) {
        await prefs.setString(_userPhoneKey, user['phone'].toString());
      }
      if (user['driverStatus'] != null) {
        await prefs.setString(_driverStatusKey, user['driverStatus']);
      } else if (user['role'] == 'driver') {
        // Default to pending for drivers when status is not provided
        await prefs.setString(_driverStatusKey, 'pending');
      }
      final category = user['vehicleCategory'] ??
          data['driver']?['vehicleCategory'] ??
          (user['role'] == 'driver' ? 'car' : null);
      if (category != null) {
        await prefs.setString(_vehicleCategoryKey, category.toString());
      }
      final driverProfileId = user['driverId']?.toString() ??
          data['driver']?['id']?.toString();
      if (driverProfileId != null && driverProfileId.isNotEmpty) {
        await prefs.setString(_driverProfileIdKey, driverProfileId);
      }
      if (user['companyId'] != null) {
        await prefs.setString(_companyIdKey, user['companyId']);
      }
    }
    final company = data['company'];
    if (company != null && company['id'] != null) {
      await prefs.setString(_companyIdKey, company['id']);
      if (user == null || prefs.getString(_userRoleKey) == null) {
        await prefs.setString(_userRoleKey, 'company');
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
    final name = prefs.getString(_userNameKey);
    if (name != null &&
        name.isNotEmpty &&
        name != 'a' &&
        name != 'User Dummy') {
      return name;
    }
    return null;
  }

  static Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
  }

  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_userPhoneKey);
    if (phone != null &&
        phone.isNotEmpty &&
        !phone.contains('96650000000') &&
        !phone.contains('dummy')) {
      return phone;
    }
    return null;
  }

  static Future<void> setUserPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPhoneKey, phone);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> getDriverProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_driverProfileIdKey);
    if (id != null && id.isNotEmpty) return id;
    return null;
  }

  static Future<void> setDriverProfileId(String id) async {
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_driverProfileIdKey, id);
  }

  static Future<String?> getDriverStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_driverStatusKey);
  }

  static Future<String> getVehicleCategory() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_vehicleCategoryKey);
    return value == 'motorcycle' ? 'motorcycle' : 'car';
  }

  static Future<void> setVehicleCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _vehicleCategoryKey,
      category == 'motorcycle' ? 'motorcycle' : 'car',
    );
  }

  /// Fetches the latest driver status from the backend and updates local storage.
  /// Returns the refreshed status string, or null on failure.
  static Future<String?> refreshDriverStatus() async {
    try {
      final dio = await getAuthenticatedDio();
      final response = await dio.get('/api/auth/profile');
      if (response.statusCode == 200) {
        final data = response.data;
        final driverInfo = data['driverInfo'];
        if (driverInfo != null && driverInfo['status'] != null) {
          final status = driverInfo['status'] as String;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_driverStatusKey, status);
          final category = driverInfo['vehicleCategory']?.toString();
          if (category != null && category.isNotEmpty) {
            await prefs.setString(
              _vehicleCategoryKey,
              category == 'motorcycle' ? 'motorcycle' : 'car',
            );
          }
          return status;
        }
      }
    } catch (_) {
      // Silently fail - return cached status
    }
    return getDriverStatus();
  }

  static Future<String?> getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_companyIdKey);
  }

  static bool _looksLikeJwt(String token) {
    final normalized = token.trim();
    return normalized.isNotEmpty && normalized.split('.').length == 3;
  }

  static Future<bool> isLoggedIn() async {
    if (await hasPendingOtpGate()) {
      // Incomplete OTP must never count as a signed-in session.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
      _authenticatedDio = null;
      return false;
    }
    final token = await getToken();
    return token != null && token.isNotEmpty && _looksLikeJwt(token);
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
    await prefs.remove(_vehicleCategoryKey);
    await prefs.remove(_driverProfileIdKey);
    _authenticatedDio = null;
  }

  /// Permanently anonymizes the signed-in account (Google Play requirement).
  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final dio = await getAuthenticatedDio();
      final response = await dio.post('/api/auth/delete-account');
      await logout();
      return {
        'success': response.statusCode == 200,
        'message': response.data is Map
            ? (response.data['message']?.toString() ?? 'تم حذف الحساب')
            : 'تم حذف الحساب',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data is Map
            ? (e.response!.data['error']?.toString() ?? 'فشل حذف الحساب')
            : 'فشل حذف الحساب',
      };
    } catch (_) {
      return {'success': false, 'message': 'فشل حذف الحساب'};
    }
  }
}
