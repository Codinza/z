import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';

class PaymentService {
  static Future<Map<String, dynamic>?> createPaymobCheckout(
      String tripId, double amount, String method) async {
    try {
      final response = await ApiClient().dio.post(
        '/api/payments/paymob/checkout',
        data: {
          'tripId': tripId,
          'amount': amount,
          'paymentMethod': method,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } on DioException catch (error) {
      debugPrint('Paymob checkout error: ${error.response?.data ?? error.message}');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createPayment(String tripId, String userId, double amount, String method) async {
    try {
      final response = await ApiClient().dio.post(
        '/api/payments',
        data: {
          'tripId': tripId,
          'userId': userId,
          'amount': amount,
          'paymentMethod': method,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data;
      } else {
        debugPrint('Failed to create payment: ${response.data}');
        return null;
      }
    } on DioException catch (e) {
      debugPrint('Payment API error: ${e.response?.data ?? e.message}');
      return null;
    } catch (e) {
      debugPrint('Payment Unknown error: $e');
      return null;
    }
  }
}
