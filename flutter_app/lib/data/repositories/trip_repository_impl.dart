import '../../domain/entities/trip.dart';
import '../../domain/repositories/trip_repository.dart';
import '../datasources/trip_remote_data_source.dart';

class TripRepositoryImpl implements TripRepository {
  TripRepositoryImpl(this._dataSource);

  final TripRemoteDataSource _dataSource;

  @override
  Future<Trip> requestTrip({
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final response = await _dataSource.requestTrip(
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
    );

    final data = response.data['ride'] ?? response.data['trip'];
    if (data == null) {
      throw const FormatException('Trip response payload was missing the ride object.');
    }

    return _buildTripFromMap(data);
  }

  @override
  Future<Trip> getTripById(String id) async {
    final response = await _dataSource.getTripById(id);
    final data = response.data['trip'] ?? response.data['ride'];
    if (data == null) {
      throw const FormatException('Trip lookup payload was invalid.');
    }

    return _buildTripFromMap(data);
  }

  @override
  Future<List<Trip>> getTripHistory() async {
    final response = await _dataSource.getTripHistory();
    final trips = response.data['rides'] as List<dynamic>? ?? response.data['history'] as List<dynamic>? ?? const <dynamic>[];
    return trips.map((item) => _buildTripFromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<Trip> updateTripStatus(String id, String status) async {
    final response = await _dataSource.updateTripStatus(id, status);
    final data = response.data['ride'] ?? response.data['trip'];
    if (data == null) {
      throw const FormatException('Trip status update payload was invalid.');
    }

    return _buildTripFromMap(data);
  }

  @override
  Future<Trip> cancelTrip(String id) async {
    final response = await _dataSource.cancelTrip(id);
    final data = response.data['ride'] ?? response.data['trip'];
    if (data == null) {
      throw const FormatException('Trip cancellation payload was invalid.');
    }

    return _buildTripFromMap(data);
  }

  @override
  Future<Trip> submitRating(String id, int score, String comment) async {
    final response = await _dataSource.submitRating(id, score, comment);
    final data = response.data['ride'] ?? response.data['trip'];
    if (data == null) {
      throw const FormatException('Trip rating payload was invalid.');
    }

    return _buildTripFromMap(data);
  }

  Trip _buildTripFromMap(Map<String, dynamic> data) {
    return Trip(
      id: data['id'] as String? ?? '',
      pickupAddress: data['pickupAddress'] as String? ?? '',
      dropoffAddress: data['dropoffAddress'] as String? ?? '',
      status: (data['status'] as String? ?? 'pending').toLowerCase(),
      fareEstimate: (data['fareEstimate'] as num? ?? 0).toDouble(),
      driverName: data['driverName'] as String? ?? 'Driver Dummy',
      driverPhone: data['driverPhone'] as String? ?? '+966500000000',
      userName: data['userName'] as String? ?? 'User Dummy',
      userPhone: data['userPhone'] as String? ?? '+966500000001',
      distanceKm: (data['distanceKm'] as num? ?? 0).toDouble(),
      durationMinutes: data['durationMinutes'] as int? ?? 0,
      remainingDistanceKm: (data['remainingDistanceKm'] as num? ?? 0).toDouble(),
      remainingMinutes: data['remainingMinutes'] as int? ?? 0,
      finalFare: (data['finalFare'] as num? ?? 0).toDouble(),
      createdAt: data['createdAt'] != null ? DateTime.tryParse(data['createdAt'] as String) : null,
      updatedAt: data['updatedAt'] != null ? DateTime.tryParse(data['updatedAt'] as String) : null,
    );
  }
}
