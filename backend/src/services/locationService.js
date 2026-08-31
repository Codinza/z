import { locationRepository } from '../repositories/locationRepository.js';

class LocationService {
  async updateDriverLocation(driverId, payload) {
    const { lat, lng } = payload;
    if (lat == null || lng == null) {
      throw new Error('lat and lng are required');
    }

    return await locationRepository.updateDriverLocation(driverId, { lat, lng, isAvailable: true });
  }

  async listDriverLocations() {
    return await locationRepository.listLocations();
  }
}

export const locationService = new LocationService();
