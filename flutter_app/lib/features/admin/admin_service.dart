import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class AdminService {
  static Future<Map<String, dynamic>?> getPendingDrivers() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendBaseUrl}/api/admin/drivers/pending'),
      );
      if (response.statusCode == 200) {
        return {'data': []}; // Return empty for Dummy User mode
      }
      return null;
    } catch (e) {
      debugPrint('getPendingDrivers error: $e');
      return null;
    }
  }

  static Future<bool> approveDriver(String id) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/admin/drivers/$id/approve'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> rejectDriver(String id) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/admin/drivers/$id/reject'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
