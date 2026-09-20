import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';

class AdminService {
  // ===================== DRIVERS =====================

  /// Get all drivers with optional status and search filters
  static Future<List<Map<String, dynamic>>> getAllDrivers({
    String? status,
    String? search,
  }) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final queryParams = <String, dynamic>{};
      if (status != null && status != 'ALL') queryParams['status'] = status;
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await dio.get('/api/admin/drivers', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data is Map) {
        final list = response.data['drivers'];
        if (list is List) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('AdminService.getAllDrivers error: $e');
      return [];
    }
  }

  /// Update driver status (approved, rejected, suspended, pending)
  static Future<bool> updateDriverStatus(String driverId, String status) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.patch(
        '/api/admin/drivers/$driverId/status',
        data: {'status': status},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('AdminService.updateDriverStatus error: $e');
      return false;
    }
  }

  /// Directly adjust driver wallet balance (credit or debit)
  static Future<bool> adjustDriverWallet(
    String driverId,
    double amount, {
    String? reason,
  }) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.post(
        '/api/admin/drivers/$driverId/wallet',
        data: {'amount': amount, 'reason': reason ?? 'تعديل يدوي من الإدارة'},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('AdminService.adjustDriverWallet error: $e');
      return false;
    }
  }

  /// Approve pending driver
  static Future<bool> approveDriver(String id) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.post('/api/admin/drivers/$id/approve');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('AdminService.approveDriver error: $e');
      return false;
    }
  }

  /// Reject driver
  static Future<bool> rejectDriver(String id) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.post('/api/admin/drivers/$id/reject');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('AdminService.rejectDriver error: $e');
      return false;
    }
  }

  /// Create a driver already approved (admin-only, no OTP)
  static Future<Map<String, dynamic>?> createApprovedDriver({
    required String name,
    required String phone,
    required String password,
    String? carModel,
    String? carColor,
    String? carYear,
    String? plateNumber,
    String vehicleCategory = 'car',
  }) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.post('/api/admin/drivers/create', data: {
        'name': name,
        'phone': phone,
        'password': password,
        'carModel': carModel,
        'carColor': carColor,
        'carYear': carYear,
        'plateNumber': plateNumber,
        'vehicleCategory': vehicleCategory,
      });
      if (response.statusCode == 201 && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return null;
    } catch (e) {
      debugPrint('AdminService.createApprovedDriver error: $e');
      if (e is DioException && e.response?.data is Map) {
        return Map<String, dynamic>.from(e.response!.data as Map);
      }
      return {'error': 'فشل إنشاء السائق'};
    }
  }

  // ===================== COMPANIES =====================

  static Future<List<Map<String, dynamic>>> getAllCompanies({
    String? status,
  }) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.get('/api/admin/companies');
      if (response.statusCode == 200 && response.data is Map) {
        final list = response.data['companies'];
        if (list is List) {
          var companies = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          if (status != null && status != 'ALL') {
            companies = companies
                .where((c) => (c['status']?.toString() ?? '') == status)
                .toList();
          }
          return companies;
        }
      }
      return [];
    } catch (e) {
      debugPrint('AdminService.getAllCompanies error: $e');
      return [];
    }
  }

  static Future<bool> approveCompany(String id) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.post('/api/admin/companies/$id/approve');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('AdminService.approveCompany error: $e');
      return false;
    }
  }

  static Future<bool> rejectCompany(String id) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.post('/api/admin/companies/$id/reject');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('AdminService.rejectCompany error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getPendingDrivers() async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.get('/api/admin/drivers/pending');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('AdminService.getPendingDrivers error: $e');
      return null;
    }
  }

  // ===================== FINANCES & TOP-UPS =====================

  /// Get financial aggregate summary
  static Future<Map<String, dynamic>> getFinancesSummary() async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.get('/api/admin/finances');
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }
      return {};
    } catch (e) {
      debugPrint('AdminService.getFinancesSummary error: $e');
      return {};
    }
  }

  /// Get driver wallet top-up requests
  static Future<List<Map<String, dynamic>>> getDriverTopUps() async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.get('/api/admin/driver-top-ups');
      if (response.statusCode == 200 && response.data is Map) {
        final list = response.data['requests'];
        if (list is List) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('AdminService.getDriverTopUps error: $e');
      return [];
    }
  }

  /// Review driver top-up request
  static Future<bool> reviewDriverTopUp(
    String id, {
    required bool approve,
    String? note,
  }) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final response = await dio.post(
        '/api/admin/driver-top-ups/$id/review',
        data: {'approve': approve, 'adminNote': note},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('AdminService.reviewDriverTopUp error: $e');
      return false;
    }
  }

  // ===================== CUSTOMERS =====================

  /// Get customers directory with search and order stats
  static Future<List<Map<String, dynamic>>> getAllCustomers({
    String? search,
  }) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await dio.get(
        '/api/admin/customers',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data is Map) {
        final list = response.data['customers'];
        if (list is List) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('AdminService.getAllCustomers error: $e');
      return [];
    }
  }

  // ===================== SUPPORT & TICKETS =====================

  /// Get support tickets with status filter and search
  static Future<Map<String, dynamic>> getSupportTickets({
    String? status,
    String? search,
  }) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final queryParams = <String, dynamic>{};
      if (status != null && status != 'ALL') queryParams['status'] = status;
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await dio.get(
        '/api/admin/support',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }
      return {'tickets': [], 'stats': {}};
    } catch (e) {
      debugPrint('AdminService.getSupportTickets error: $e');
      return {'tickets': [], 'stats': {}};
    }
  }

  /// Update support ticket status or record admin reply
  static Future<bool> updateSupportTicket(
    String ticketId, {
    String? status,
    String? adminReply,
  }) async {
    try {
      final dio = await AuthService.getAuthenticatedDio();
      final data = <String, dynamic>{};
      if (status != null) data['status'] = status;
      if (adminReply != null) data['adminReply'] = adminReply;

      final response = await dio.patch('/api/admin/support/$ticketId', data: data);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('AdminService.updateSupportTicket error: $e');
      return false;
    }
  }
}
