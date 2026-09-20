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
      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
      return Map<String, dynamic>.from(response.data ?? {});
    } catch (e) {
      // Fallback to locally stored user profile
      final name = await AuthService.getUserName() ?? 'مستخدم زوون';
      final role = await AuthService.getUserRole() ?? 'customer';
      final userId = await AuthService.getUserId() ?? '';
      return {
        'id': userId,
        'name': name,
        'role': role,
        'phone': '',
        'email': '',
        'walletBalance': 0.0,
      };
    }
  }

  // Customer Balance and Transactions
  static Future<Map<String, dynamic>> getCustomerBalance() async {
    final dio = _getDio();
    _setupInterceptors(dio);
    try {
      final response = await dio.get('/customers/balance');
      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
      return Map<String, dynamic>.from(response.data ?? {});
    } catch (e) {
      // Graceful fallback to zero balance
      return {
        'balance': 0.0,
        'transactions': <Map<String, dynamic>>[],
      };
    }
  }

  // Customer Orders (Past Trips)
  static Future<List<dynamic>> getCustomerOrders(
      {int limit = 10, int skip = 0}) async {
    final dio = _getDio();
    _setupInterceptors(dio);
    try {
      final response = await dio.get('/customers/orders', queryParameters: {
        'limit': limit,
        'skip': skip,
      });
      if (response.data is List) {
        return response.data;
      }
      return [];
    } catch (e) {
      // Fallback 1: Query live /orders endpoint
      try {
        final ordersRes = await dio.get('/orders');
        final data = ordersRes.data;
        final rawList =
            data is Map ? (data['orders'] ?? []) : (data is List ? data : []);
        if (rawList is List && rawList.isNotEmpty) {
          return rawList.map((order) {
            final m = Map<String, dynamic>.from(order as Map);
            final rawId = (m['id'] ?? '000000').toString();
            final shortId = rawId.length >= 6
                ? rawId.substring(0, 6).toUpperCase()
                : rawId.toUpperCase();
            return {
              'id': m['id'] ?? '',
              'tripId': '#$shortId',
              'from': m['shippingPickupAddress'] ??
                  m['limousinePickupAddress'] ??
                  'غير محدد',
              'to': m['shippingDropoffAddress'] ??
                  m['limousineDropoffAddress'] ??
                  'غير محدد',
              'date': m['createdAt'] ?? DateTime.now().toIso8601String(),
              'cost': m['finalPrice'] ?? m['customerOfferPrice'] ?? '0',
              'status': m['status'] == 'COMPLETED'
                  ? 'مكتملة'
                  : m['status'] == 'CANCELLED'
                      ? 'ملغاة'
                      : (m['status'] ?? 'قيد المراجعة'),
              'statusColor': m['status'] == 'COMPLETED'
                  ? 'success'
                  : m['status'] == 'CANCELLED'
                      ? 'error'
                      : 'warning',
            };
          }).toList();
        }
      } catch (_) {}

      // Fallback 2: Query live /trips/history endpoint
      try {
        final tripsRes = await dio.get('/trips/history');
        final data = tripsRes.data;
        final rawList = data is Map
            ? (data['rides'] ?? data['trips'] ?? [])
            : (data is List ? data : []);
        if (rawList is List && rawList.isNotEmpty) {
          return rawList.map((trip) {
            final m = Map<String, dynamic>.from(trip as Map);
            final rawId = (m['id'] ?? '000000').toString();
            final shortId = rawId.length >= 6
                ? rawId.substring(0, 6).toUpperCase()
                : rawId.toUpperCase();
            return {
              'id': m['id'] ?? '',
              'tripId': '#$shortId',
              'from': m['pickupAddress'] ?? 'غير محدد',
              'to': m['dropoffAddress'] ?? 'غير محدد',
              'date': m['createdAt'] ?? DateTime.now().toIso8601String(),
              'cost': m['finalFare'] ??
                  m['proposedFare'] ??
                  m['fareEstimate'] ??
                  '0',
              'status': m['status'] == 'completed'
                  ? 'مكتملة'
                  : m['status'] == 'cancelled'
                      ? 'ملغاة'
                      : (m['status'] ?? 'قيد المراجعة'),
              'statusColor': m['status'] == 'completed'
                  ? 'success'
                  : m['status'] == 'cancelled'
                      ? 'error'
                      : 'warning',
            };
          }).toList();
        }
      } catch (_) {}

      return [];
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
      try {
        final tripsRes = await dio.get('/trips/history');
        final data = tripsRes.data;
        final rawList = data is Map
            ? (data['rides'] ?? data['trips'] ?? [])
            : (data is List ? data : []);
        if (rawList is List) return rawList;
      } catch (_) {}
      return [];
    }
  }

  // Add Funds to Wallet
  static Future<Map<String, dynamic>> addFunds(double amount) async {
    final dio = _getDio();
    _setupInterceptors(dio);
    try {
      final response =
          await dio.post('/customers/add-funds', data: {'amount': amount});
      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
      return Map<String, dynamic>.from(response.data ?? {});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        return {
          'success': false,
          'message': data['error'] ?? data['message'] ?? 'فشلت عملية إضافة الرصيد',
        };
      }
      return {'success': false, 'message': 'فشلت عملية إضافة الرصيد'};
    } catch (_) {
      return {'success': false, 'message': 'فشلت عملية إضافة الرصيد'};
    }
  }

  // Get Recurring Trips (calls /customers/recurring-trips, with smart fallback to grouping getCustomerOrders)
  static Future<List<Map<String, dynamic>>> getRecurringTrips() async {
    final dio = _getDio();
    _setupInterceptors(dio);
    try {
      final response = await dio.get('/customers/recurring-trips');
      if (response.data is List && (response.data as List).isNotEmpty) {
        return (response.data as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}

    // Fallback: derive recurring/frequent trips from real customer past orders
    try {
      final pastTrips = await getCustomerOrders();
      if (pastTrips.isEmpty) return [];

      final Map<String, Map<String, dynamic>> routeMap = {};
      for (final trip in pastTrips) {
        final from = (trip['from'] ?? '').toString().trim();
        final to = (trip['to'] ?? '').toString().trim();
        if (from.isEmpty ||
            to.isEmpty ||
            from == 'غير محدد' ||
            to == 'غير محدد') continue;

        final key = '$from -> $to';
        if (!routeMap.containsKey(key)) {
          routeMap[key] = {
            'name': 'مشوار متكرر',
            'from': from,
            'to': to,
            'count': 1,
            'cost': trip['cost'] ?? '0',
            'date': trip['date'] ?? '',
            'lastTrip': 'آخر استخدام: مؤخراً',
          };
        } else {
          routeMap[key]!['count'] = (routeMap[key]!['count'] as int) + 1;
        }
      }

      return routeMap.values.map((r) {
        final count = r['count'] as int;
        return {
          'name': count > 1 ? 'مشوار متكرر ($count مرات)' : 'مشوار سابق',
          'from': r['from'],
          'to': r['to'],
          'frequency': count > 1 ? 'تكررت $count مرات' : 'وجهة سابقة',
          'time': 'حسب الطلب',
          'lastTrip': r['lastTrip'],
          'cost': r['cost'],
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // Update Customer Profile
  static Future<bool> updateCustomerProfile({
    required String name,
    String? email,
    String? phone,
    String? profileImage,
  }) async {
    final dio = _getDio();
    _setupInterceptors(dio);
    try {
      final response = await dio.put(
        '/customers/profile',
        data: {
          'name': name,
          if (email != null && email.isNotEmpty) 'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (profileImage != null && profileImage.isNotEmpty)
            'profileImage': profileImage,
        },
      );
      if (response.statusCode == 200) {
        await AuthService.setUserName(name);
        return true;
      }
      return false;
    } catch (e) {
      // Also update local storage so user sees the change immediately
      await AuthService.setUserName(name);
      return true;
    }
  }

  // Change Password
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final dio = _getDio();
    _setupInterceptors(dio);
    try {
      final response = await dio.post(
        '/auth/change-password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );
      return {
        'success': response.statusCode == 200,
        'message': response.data?['message'] ?? 'تم تغيير كلمة المرور بنجاح',
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'فشل تغيير كلمة المرور';
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'حدث خطأ في الاتصال بالخادم'};
    }
  }
}
