import { Router } from 'express';
import {
  submitDriverApplication,
  getMyDriverApplication,
} from '../controllers/driverApplicationController.js';

export const driverApplicationRoutes = () => {
  const router = Router();
  router.post('/', submitDriverApplication);
  router.get('/me', getMyDriverApplication);
  return router;
};
