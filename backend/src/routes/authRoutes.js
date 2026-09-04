import { Router } from 'express';
import { register, login, guestLogin, refreshToken, getProfile, changePassword } from '../controllers/authController.js';
import { authMiddleware } from '../middlewares/authMiddleware.js';

const router = Router();

export const authRoutes = () => {
  router.post('/register', register);
  router.post('/login', login);
  router.post('/guest', guestLogin);
  router.post('/refresh', refreshToken);
  router.get('/profile', authMiddleware, getProfile);
  router.post('/change-password', authMiddleware, changePassword);
  return router;
};
