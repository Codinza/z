class Trip {
  const Trip({
    required this.id,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.status,
    required this.fareEstimate,
    this.driverName = 'Driver Dummy',
    this.driverPhone = '+966500000000',
    this.userName = 'User Dummy',
    this.userPhone = '+966500000001',
    this.distanceKm = 0,
    this.durationMinutes = 0,
    this.remainingDistanceKm = 0,
    this.remainingMinutes = 0,
    this.finalFare = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String pickupAddress;
  final String dropoffAddress;
  final String status;
  final double fareEstimate;
  final String driverName;
  final String driverPhone;
  final String userName;
  final String userPhone;
  final double distanceKm;
  final int durationMinutes;
  final double remainingDistanceKm;
  final int remainingMinutes;
  final double finalFare;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Trip copyWith({
    String? id,
    String? pickupAddress,
    String? dropoffAddress,
    String? status,
    double? fareEstimate,
    String? driverName,
    String? driverPhone,
    String? userName,
    String? userPhone,
    double? distanceKm,
    int? durationMinutes,
    double? remainingDistanceKm,
    int? remainingMinutes,
    double? finalFare,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      status: status ?? this.status,
      fareEstimate: fareEstimate ?? this.fareEstimate,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      remainingDistanceKm: remainingDistanceKm ?? this.remainingDistanceKm,
      remainingMinutes: remainingMinutes ?? this.remainingMinutes,
      finalFare: finalFare ?? this.finalFare,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
