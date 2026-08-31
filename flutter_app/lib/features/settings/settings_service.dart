import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';

class SettingsService {
  static Future<Map<String, String>> getPageContent(String pageId) async {
    try {
      final response = await ApiClient().dio.get('/api/settings/pages/$pageId');
      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'title': data['title'] ?? '',
          'content': data['content'] ?? '',
        };
      }
      return {'title': 'Error', 'content': 'Failed to load page content'};
    } on DioException catch (e) {
      debugPrint('Error fetching page content (API): ${e.response?.data ?? e.message}');
      return {'title': 'Error', 'content': 'Network error'};
    } catch (e) {
      debugPrint('Error fetching page content: $e');
      return {'title': 'Error', 'content': 'Network error'};
    }
  }

  static Future<bool> submitContactMessage(String name, String email, String message) async {
    try {
      final response = await ApiClient().dio.post(
        '/api/settings/contact',
        data: {'name': name, 'email': email, 'message': message},
      );
      return response.statusCode == 201;
    } on DioException catch (e) {
      debugPrint('Error submitting contact message (API): ${e.response?.data ?? e.message}');
      return false;
    } catch (e) {
      debugPrint('Error submitting contact message: $e');
      return false;
    }
  }
}
