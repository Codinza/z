import express from 'express';
import { customerController } from '../controllers/customerController.js';
import { authMiddleware } from '../middlewares/authMiddleware.js';

export function customerRoutes() {
  const router = express.Router();

  // Get customer profile
  router.get('/profile', customerController.getProfile);

  // Get customer balance and transactions
  router.get('/balance', customerController.getBalance);

  // Get customer orders
  router.get('/orders', customerController.getOrders);

  // Get customer trips history
  router.get('/trips-history', customerController.getTripsHistory);

  // Add funds to wallet
  router.post('/add-funds', customerController.addFunds);

  return router;
}
