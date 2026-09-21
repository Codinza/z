import express from 'express';
import { driverController } from '../controllers/driverController.js';
import { requireRole, requireSelfDriver } from '../middlewares/authMiddleware.js';

export function driverRoutes() {
  const router = express.Router();

  router.get('/', requireRole('admin', 'super_admin'), driverController.listDrivers.bind(driverController));

  // Authenticated self routes (must be before /:id to avoid "me" collision issues)
  router.get('/me/wallet', requireSelfDriver, (req, res, next) => {
    req.params.id = req.user?.id;
    return driverController.getWallet(req, res, next);
  });
  router.post('/me/wallet/top-up-request', requireSelfDriver, (req, res, next) => {
    req.params.id = req.user?.id;
    return driverController.createTopUpRequest(req, res, next);
  });
  router.get('/me/history', requireSelfDriver, (req, res, next) => {
    req.params.id = req.user?.id;
    return driverController.getHistory(req, res, next);
  });

  router.get('/:id', requireSelfDriver, driverController.getDriverById.bind(driverController));
  router.get('/:id/wallet', requireSelfDriver, driverController.getWallet.bind(driverController));
  router.post('/:id/recharge', requireSelfDriver, driverController.recharge.bind(driverController));
  router.post('/:id/wallet/checkout', requireSelfDriver, driverController.createWalletCheckout.bind(driverController));
  router.post('/:id/wallet/top-up-request', requireSelfDriver, driverController.createTopUpRequest.bind(driverController));
  router.get('/:id/history', requireSelfDriver, driverController.getHistory.bind(driverController));
  router.get('/:id/ratings', requireSelfDriver, driverController.getRatings.bind(driverController));

  return router;
}
