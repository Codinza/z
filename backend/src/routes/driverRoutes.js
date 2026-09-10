import express from 'express';
import { driverController } from '../controllers/driverController.js';

export function driverRoutes() {
  const router = express.Router();

  router.get('/', driverController.listDrivers.bind(driverController));
  router.get('/:id', driverController.getDriverById.bind(driverController));

  router.get('/:id/wallet', driverController.getWallet.bind(driverController));
  router.post('/:id/recharge', driverController.recharge.bind(driverController));
  router.post('/:id/wallet/checkout', driverController.createWalletCheckout.bind(driverController));
  router.post('/:id/wallet/top-up-request', driverController.createTopUpRequest.bind(driverController));
  router.get('/:id/history', driverController.getHistory.bind(driverController));

  return router;
}
