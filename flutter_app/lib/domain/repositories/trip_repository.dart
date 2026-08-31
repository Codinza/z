import '../entities/trip.dart';

abstract class TripRepository {
  Future<Trip> requestTrip({
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  });

  Future<Trip> getTripById(String id);

  Future<List<Trip>> getTripHistory();

  Future<Trip> updateTripStatus(String id, String status);

  Future<Trip> cancelTrip(String id);

  Future<Trip> submitRating(String id, int score, String comment);
}
