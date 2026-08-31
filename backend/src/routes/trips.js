import express from 'express';
import {
  assignDriverToRide,
  acceptRide,
  completeRide,
  createRideRequest,
  getRideById,
  listRides,
  startRide,
} from '../services/rideService.js';

export function routeTripRequests(io) {
  const router = express.Router();

  router.get('/', (_, res) => {
    res.json({ rides: listRides() });
  });

  router.get('/:id', (req, res) => {
    const ride = getRideById(req.params.id);
    if (!ride) {
      return res.status(404).json({ message: 'Ride not found' });
    }
    return res.json({ ride });
  });

  router.post('/request', (req, res) => {
    try {
      const ride = createRideRequest(req.body, io);
      res.status(201).json({ message: 'Ride requested successfully', ride });
    } catch (error) {
      res.status(400).json({ message: error.message });
    }
  });

  router.post('/:id/assign', (req, res) => {
    try {
      const assignment = assignDriverToRide(req.params.id, io);
      res.status(200).json({ message: 'Driver assigned successfully', assignment });
    } catch (error) {
      res.status(400).json({ message: error.message });
    }
  });

  router.post('/:id/accept', (req, res) => {
    try {
      const result = acceptRide(req.params.id, io);
      res.status(200).json({ message: 'Driver accepted ride', ...result });
    } catch (error) {
      res.status(400).json({ message: error.message });
    }
  });

  router.post('/:id/start', (req, res) => {
    try {
      const result = startRide(req.params.id, io);
      res.status(200).json({ message: 'Ride started', ...result });
    } catch (error) {
      res.status(400).json({ message: error.message });
    }
  });

  router.post('/:id/complete', (req, res) => {
    try {
      const result = completeRide(req.params.id, io);
      res.status(200).json({ message: 'Ride completed', ...result });
    } catch (error) {
      res.status(400).json({ message: error.message });
    }
  });

  return router;
}
