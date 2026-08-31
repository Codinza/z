import { Router } from 'express';
import {
  createPayment,
  createPaymobCheckout,
  getPaymentByTrip,
} from '../controllers/paymentController.js';

const router = Router();

export const paymentRoutes = () => {
  router.post('/', createPayment);
  router.post('/paymob/checkout', createPaymobCheckout);
  router.get('/:tripId', getPaymentByTrip);
  return router;
};
