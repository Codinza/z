import '../../domain/entities/trip.dart';

class TripModel extends Trip {
  const TripModel({
    required super.id,
    required super.pickupAddress,
    required super.dropoffAddress,
    required super.status,
    required super.fareEstimate,
    super.driverName,
    super.driverPhone,
    super.userName,
    super.userPhone,
    super.distanceKm,
    super.durationMinutes,
    super.remainingDistanceKm,
    super.remainingMinutes,
    super.finalFare,
    super.createdAt,
    super.updatedAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String,
      pickupAddress: json['pickupAddress'] as String? ?? '',
      dropoffAddress: json['dropoffAddress'] as String? ?? '',
      status: (json['status'] as String? ?? 'pending').toLowerCase(),
      fareEstimate: (json['fareEstimate'] as num? ?? 0).toDouble(),
      driverName: json['driverName'] as String? ?? 'Driver Dummy',
      driverPhone: json['driverPhone'] as String? ?? '+966500000000',
      userName: json['userName'] as String? ?? 'User Dummy',
      userPhone: json['userPhone'] as String? ?? '+966500000001',
      distanceKm: (json['distanceKm'] as num? ?? 0).toDouble(),
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      remainingDistanceKm: (json['remainingDistanceKm'] as num? ?? 0).toDouble(),
      remainingMinutes: json['remainingMinutes'] as int? ?? 0,
      finalFare: (json['finalFare'] as num? ?? 0).toDouble(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }
}
