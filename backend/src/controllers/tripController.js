import { tripService } from '../services/tripService.js';

class TripController {
  async listTrips(req, res) {
    const rides = await tripService.listTrips();
    return res.json({ rides });
  }

  async getTripHistory(req, res) {
    const rides = await tripService.getTripHistory();
    return res.json({ rides });
  }

  async getTripById(req, res) {
    const trip = await tripService.getTripById(req.params.id);
    if (!trip) {
      return res.status(404).json({ message: 'Trip not found' });
    }
    return res.json({ trip });
  }

  async requestTrip(req, res) {
    try {
      const payload = { ...req.body, userId: req.user?.id };
      const trip = await tripService.createTripRequest(payload);
      return res.status(201).json({ message: 'Trip requested successfully', ride: trip });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }

  async assignDriver(req, res) {
    try {
      const assignment = await tripService.assignDriver(req.params.id);
      return res.status(200).json({ message: 'Driver assigned successfully', assignment });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }

  async acceptTrip(req, res) {
    try {
      const { driverId, offerAmount } = req.body;
      const result = await tripService.acceptTrip(req.params.id, driverId, offerAmount);
      return res.status(200).json({ message: 'Driver accepted trip', ...result });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }

  async rejectTrip(req, res) {
    try {
      const ride = await tripService.rejectTrip(req.params.id, req.body.driverId);
      return res.status(200).json({ message: 'Driver rejected trip', ride });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }

  async driverArriving(req, res) {
    try {
      const result = await tripService.updateTripStatus(req.params.id, 'driver_arriving');
      return res.status(200).json({ message: 'Driver is arriving', ride: result });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }

  async driverArrived(req, res) {
    try {
      const result = await tripService.updateTripStatus(req.params.id, 'driver_arrived');
      return res.status(200).json({ message: 'Driver arrived', ride: result });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }

  async startTrip(req, res) {
    try {
      const result = await tripService.startTrip(req.params.id);
      return res.status(200).json({ message: 'Trip started', ...result });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }

  async cancelTrip(req, res) {
    try {
      const ride = await tripService.cancelTrip(req.params.id);
      return res.status(200).json({ message: 'Trip cancelled', ride });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }

  async completeTrip(req, res) {
    try {
      const result = await tripService.completeTrip(req.params.id);
      return res.status(200).json({ message: 'Trip completed', ...result });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }

  async updateTripStatus(req, res) {
    try {
      const ride = await tripService.updateTripStatus(req.params.id, req.body.status);
      return res.status(200).json({ message: 'Trip status updated', ride });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }

  async submitRating(req, res) {
    try {
      const ride = await tripService.submitRating(req.params.id, req.body.score, req.body.comment);
      return res.status(200).json({ message: 'Driver rating saved', ride });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }

  async submitDriverOffer(req, res) {
    try {
      const { driverId, offerAmount } = req.body;
      const result = await tripService.submitDriverOffer(req.params.id, driverId, offerAmount);
      return res.status(200).json({ message: 'Driver offer submitted', ...result });
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }
  }
}

export const tripController = new TripController();
