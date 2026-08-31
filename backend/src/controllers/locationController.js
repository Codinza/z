import { locationService } from '../services/locationService.js';

class LocationController {
  async updateDriverLocation(req, res) {
    try {
      const location = await locationService.updateDriverLocation(req.params.driverId, req.body);
      return res.status(200).json({ message: 'Driver location updated', location });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }

  async listDriverLocations(_, res) {
    return res.json({ locations: await locationService.listDriverLocations() });
  }
}

export const locationController = new LocationController();
