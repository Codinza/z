import { Router } from 'express';
import {
  getPendingDrivers,
  getAllDrivers,
  updateDriverStatus,
  adjustDriverWallet,
  approveDriver,
  rejectDriver,
  createApprovedDriver,
  deleteDriver,
  getStats,
  getAllOrders,
  adminAcceptOrder,
  adminRejectOrder,
  adminSendCounterOffer,
  adminStartDelivery,
  adminCompleteOrder,
  getTopUpRequests,
  reviewTopUpRequest,
  getAllCustomers,
  deleteCustomer,
  getFinancesSummary,
  getSupportTickets,
  updateSupportTicket,
  getPendingCompanies,
  approveCompany,
  rejectCompany,
  getAllCompanies,
} from '../controllers/adminController.js';

export const adminRoutes = () => {
  const router = Router();

  // Stats & Dashboard
  router.get('/stats', getStats);
  router.get('/finances', getFinancesSummary);

  // Drivers Management
  router.get('/drivers', getAllDrivers);
  router.get('/drivers/pending', getPendingDrivers);
  router.post('/drivers/create', createApprovedDriver);
  router.patch('/drivers/:id/status', updateDriverStatus);
  router.post('/drivers/:id/wallet', adjustDriverWallet);
  router.post('/drivers/:id/approve', approveDriver);
  router.post('/drivers/:id/reject', rejectDriver);
  router.delete('/drivers/:id', deleteDriver);

  // Companies Management
  router.get('/companies', getAllCompanies);
  router.get('/companies/pending', getPendingCompanies);
  router.post('/companies/:id/approve', approveCompany);
  router.post('/companies/:id/reject', rejectCompany);

  // Top-Up Requests & Wallets
  router.get('/driver-top-ups', getTopUpRequests);
  router.post('/driver-top-ups/:id/review', reviewTopUpRequest);

  // Customers Directory
  router.get('/customers', getAllCustomers);
  router.delete('/customers/:id', deleteCustomer);

  // Support & Helpdesk
  router.get('/support', getSupportTickets);
  router.patch('/support/:id', updateSupportTicket);

  // Orders Management
  router.get('/orders', getAllOrders);
  router.post('/orders/:orderId/accept', adminAcceptOrder);
  router.post('/orders/:orderId/reject', adminRejectOrder);
  router.post('/orders/:orderId/offer', adminSendCounterOffer);
  router.post('/orders/:orderId/start-delivery', adminStartDelivery);
  router.post('/orders/:orderId/complete', adminCompleteOrder);

  return router;
};
