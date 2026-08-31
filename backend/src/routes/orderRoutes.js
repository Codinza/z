import { Router } from 'express';
import {
  createLimousineOrder,
  createShippingOrder,
  getCustomerOrders,
  getOrderDetails,
  approveCustomerPrice,
  rejectCustomerPrice,
  confirmOrder,
  completeOrder,
  cancelOrder,
} from '../controllers/orderController.js';
import { authMiddleware, requireRole } from '../middlewares/authMiddleware.js';

export const orderRoutes = () => {
  const router = Router();

  // Create order routes
  router.post('/limousine', async (req, res) => {
    await authMiddleware(req, res, async () => {
      await createLimousineOrder(req, res);
    });
  });

  router.post('/shipping', async (req, res) => {
    await authMiddleware(req, res, async () => {
      await createShippingOrder(req, res);
    });
  });

  // Get customer orders
  router.get('/', async (req, res) => {
    await authMiddleware(req, res, async () => {
      await getCustomerOrders(req, res);
    });
  });

  // Get order details
  router.get('/:id', async (req, res) => {
    await authMiddleware(req, res, async () => {
      await getOrderDetails(req, res);
    });
  });

  // Approve price
  router.post('/:id/approve-price', async (req, res) => {
    await authMiddleware(req, res, async () => {
      await approveCustomerPrice(req, res);
    });
  });

  // Reject price
  router.post('/:id/reject-price', async (req, res) => {
    await authMiddleware(req, res, async () => {
      await rejectCustomerPrice(req, res);
    });
  });

  // Confirm order
  router.post('/:id/confirm', async (req, res) => {
    await authMiddleware(req, res, async () => {
      await confirmOrder(req, res);
    });
  });

  // Complete order
  router.post('/:id/complete', async (req, res) => {
    await authMiddleware(req, res, async () => {
      await completeOrder(req, res);
    });
  });

  // Cancel order
  router.post('/:id/cancel', async (req, res) => {
    await authMiddleware(req, res, async () => {
      await cancelOrder(req, res);
    });
  });

  return router;
};
