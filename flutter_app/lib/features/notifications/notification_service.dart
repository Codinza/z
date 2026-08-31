import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      type: json['type'] ?? 'system',
      isRead: json['isRead'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class NotificationService {
  static Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final response = await ApiClient().dio.get('/api/notifications?userId=$userId');
      if (response.statusCode == 200) {
        List jsonResponse = response.data;
        return jsonResponse.map((n) => NotificationModel.fromJson(n)).toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error fetching notifications (API): ${e.response?.data ?? e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  static Future<bool> markAsRead(String id) async {
    try {
      final response = await ApiClient().dio.put('/api/notifications/$id/read');
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error marking notification read (API): ${e.response?.data ?? e.message}');
      return false;
    } catch (e) {
      debugPrint('Error marking notification read: $e');
      return false;
    }
  }
}
