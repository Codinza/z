import { Router } from 'express';
import { getDirections } from '../controllers/mapsController.js';
import { authMiddleware } from '../middlewares/authMiddleware.js';

export const mapsRoutes = () => {
  const router = Router();

  router.get('/directions', authMiddleware, getDirections);

  return router;
};