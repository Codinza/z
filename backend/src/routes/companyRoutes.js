import { Router } from 'express';
import {
  registerCompany,
  companyLogin,
  getCompanyDashboard,
  getCompanyOrders,
  reviewOrder,
  acceptOrder,
  rejectOrder,
  sendCounterOffer,
  startDelivery,
  completeDelivery,
} from '../controllers/companyController.js';
import { authMiddleware, requireRole } from '../middlewares/authMiddleware.js';

export const companyRoutes = () => {
  const router = Router();

  // Company authentication
  router.post('/register', registerCompany);
  router.post('/login', companyLogin);

  // Company dashboard
  router.get('/dashboard', async (req, res) => {
    await authMiddleware(req, res, async () => {
      if (!req.user?.companyId) {
        return res.status(403).json({ error: 'Company access required' });
      }
      await getCompanyDashboard(req, res);
    });
  });

  // Get company orders
  router.get('/orders', async (req, res) => {
    await authMiddleware(req, res, async () => {
      if (!req.user?.companyId) {
        return res.status(403).json({ error: 'Company access required' });
      }
      await getCompanyOrders(req, res);
    });
  });

  // Review order
  router.post('/orders/:orderId/review', async (req, res) => {
    await authMiddleware(req, res, async () => {
      if (!req.user?.companyId) {
        return res.status(403).json({ error: 'Company access required' });
      }
      await reviewOrder(req, res);
    });
  });

  // Accept order
  router.post('/orders/:orderId/accept', async (req, res) => {
    await authMiddleware(req, res, async () => {
      if (!req.user?.companyId) {
        return res.status(403).json({ error: 'Company access required' });
      }
      await acceptOrder(req, res);
    });
  });

  // Reject order
  router.post('/orders/:orderId/reject', async (req, res) => {
    await authMiddleware(req, res, async () => {
      if (!req.user?.companyId) {
        return res.status(403).json({ error: 'Company access required' });
      }
      await rejectOrder(req, res);
    });
  });

  // Send counter offer
  router.post('/orders/:orderId/offer', async (req, res) => {
    await authMiddleware(req, res, async () => {
      if (!req.user?.companyId) {
        return res.status(403).json({ error: 'Company access required' });
      }
      await sendCounterOffer(req, res);
    });
  });

  // Start delivery (CONFIRMED -> IN_PROGRESS)
  router.post('/orders/:orderId/start-delivery', async (req, res) => {
    await authMiddleware(req, res, async () => {
      if (!req.user?.companyId) {
        return res.status(403).json({ error: 'Company access required' });
      }
      await startDelivery(req, res);
    });
  });

  // Complete delivery (IN_PROGRESS -> COMPLETED)
  router.post('/orders/:orderId/complete', async (req, res) => {
    await authMiddleware(req, res, async () => {
      if (!req.user?.companyId) {
        return res.status(403).json({ error: 'Company access required' });
      }
      await completeDelivery(req, res);
    });
  });

  return router;
};
