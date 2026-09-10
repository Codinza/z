import { Router } from 'express';
import {
  getPendingDrivers,
  approveDriver,
  rejectDriver,
  getStats,
  getAllOrders,
  adminAcceptOrder,
  adminRejectOrder,
  adminSendCounterOffer,
  getTopUpRequests,
  reviewTopUpRequest,
} from '../controllers/adminController.js';

const router = Router();

export const adminRoutes = () => {
  // No auth middleware for now to allow easy testing
  router.get('/stats', getStats);
  router.get('/orders', getAllOrders);
  router.get('/drivers/pending', getPendingDrivers);
  router.post('/drivers/:id/approve', approveDriver);
  router.post('/drivers/:id/reject', rejectDriver);
  router.post('/orders/:orderId/accept', adminAcceptOrder);
  router.post('/orders/:orderId/reject', adminRejectOrder);
  router.post('/orders/:orderId/offer', adminSendCounterOffer);
  router.get('/driver-top-ups', getTopUpRequests);
  router.post('/driver-top-ups/:id/review', reviewTopUpRequest);

  return router;
};
