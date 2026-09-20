import express from 'express';
import { driverController } from '../controllers/driverController.js';
import { requireRole, requireSelfDriver } from '../middlewares/authMiddleware.js';

export function driverRoutes() {
  const router = express.Router();

  router.get('/', requireRole('admin', 'super_admin'), driverController.listDrivers.bind(driverController));
  router.get('/:id', requireSelfDriver, driverController.getDriverById.bind(driverController));

  router.get('/:id/wallet', requireSelfDriver, driverController.getWallet.bind(driverController));
  // Free direct recharge is disabled — use top-up-request or Paymob checkout.
  router.post('/:id/recharge', requireSelfDriver, driverController.recharge.bind(driverController));
  router.post('/:id/wallet/checkout', requireSelfDriver, driverController.createWalletCheckout.bind(driverController));
  router.post('/:id/wallet/top-up-request', requireSelfDriver, driverController.createTopUpRequest.bind(driverController));
  router.get('/:id/history', requireSelfDriver, driverController.getHistory.bind(driverController));
  router.get('/:id/ratings', requireSelfDriver, driverController.getRatings.bind(driverController));

  return router;
}
