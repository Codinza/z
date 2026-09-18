import { Router } from 'express';
import {
  getPendingDrivers,
  getAllDrivers,
  updateDriverStatus,
  adjustDriverWallet,
  approveDriver,
  rejectDriver,
  getStats,
  getAllOrders,
  adminAcceptOrder,
  adminRejectOrder,
  adminSendCounterOffer,
  getTopUpRequests,
  reviewTopUpRequest,
  getAllCustomers,
  getFinancesSummary,
  getSupportTickets,
  updateSupportTicket,
} from '../controllers/adminController.js';

const router = Router();

export const adminRoutes = () => {
  // Stats & Dashboard
  router.get('/stats', getStats);
  router.get('/finances', getFinancesSummary);

  // Drivers Management
  router.get('/drivers', getAllDrivers);
  router.get('/drivers/pending', getPendingDrivers);
  router.patch('/drivers/:id/status', updateDriverStatus);
  router.post('/drivers/:id/wallet', adjustDriverWallet);
  router.post('/drivers/:id/approve', approveDriver);
  router.post('/drivers/:id/reject', rejectDriver);

  // Top-Up Requests & Wallets
  router.get('/driver-top-ups', getTopUpRequests);
  router.post('/driver-top-ups/:id/review', reviewTopUpRequest);

  // Customers Directory
  router.get('/customers', getAllCustomers);

  // Support & Helpdesk
  router.get('/support', getSupportTickets);
  router.patch('/support/:id', updateSupportTicket);

  // Orders Management
  router.get('/orders', getAllOrders);
  router.post('/orders/:orderId/accept', adminAcceptOrder);
  router.post('/orders/:orderId/reject', adminRejectOrder);
  router.post('/orders/:orderId/offer', adminSendCounterOffer);

  return router;
};
