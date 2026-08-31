import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

class TripRemoteDataSource {
  TripRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<Response> requestTrip({
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) {
    return _apiClient.dio.post(
      '/api/trips/request',
      data: {
        'pickupAddress': pickupAddress,
        'dropoffAddress': dropoffAddress,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropoffLat': dropoffLat,
        'dropoffLng': dropoffLng,
      },
    );
  }

  Future<Response> getTripById(String id) {
    return _apiClient.dio.get('/api/trips/$id');
  }

  Future<Response> getTripHistory() {
    return _apiClient.dio.get('/api/trips/history');
  }

  Future<Response> updateTripStatus(String id, String status) {
    return _apiClient.dio.patch(
      '/api/trips/$id/status',
      data: {'status': status},
    );
  }

  Future<Response> cancelTrip(String id) {
    return _apiClient.dio.post('/api/trips/$id/cancel');
  }

  Future<Response> submitRating(String id, int score, String comment) {
    return _apiClient.dio.post(
      '/api/trips/$id/rating',
      data: {'score': score, 'comment': comment},
    );
  }
}
