import express from 'express';
import { locationController } from '../controllers/locationController.js';

export function locationRoutes() {
  const router = express.Router();

  router.get('/', locationController.listDriverLocations.bind(locationController));
  router.put('/:driverId', locationController.updateDriverLocation.bind(locationController));

  return router;
}
