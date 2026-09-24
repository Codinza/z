import express from 'express';
import { tripController } from '../controllers/tripController.js';

export function tripRoutes() {
  const router = express.Router();

  router.get('/history', tripController.getTripHistory.bind(tripController));
  router.get('/', tripController.listTrips.bind(tripController));
  router.post('/request', tripController.requestTrip.bind(tripController));
  router.get('/:id', tripController.getTripById.bind(tripController));
  router.post('/:id/search', tripController.startDriverSearch.bind(tripController));
  router.post('/:id/assign', tripController.assignDriver.bind(tripController));
  router.post('/:id/accept', tripController.acceptTrip.bind(tripController));
  router.post('/:id/reject', tripController.rejectTrip.bind(tripController));
  router.post('/:id/driver-arriving', tripController.driverArriving.bind(tripController));
  router.post('/:id/driver-arrived', tripController.driverArrived.bind(tripController));
  router.post('/:id/start', tripController.startTrip.bind(tripController));
  router.post('/:id/cancel', tripController.cancelTrip.bind(tripController));
  router.post('/:id/complete', tripController.completeTrip.bind(tripController));
  router.patch('/:id/status', tripController.updateTripStatus.bind(tripController));
  router.post('/:id/rating', tripController.submitRating.bind(tripController));
  router.post('/:id/offer', tripController.submitDriverOffer.bind(tripController));
  router.get('/:id/offers', tripController.getTripOffers.bind(tripController));
  router.post('/:id/accept-offer', tripController.acceptDriverOffer.bind(tripController));

  return router;
}
