import { Router } from 'express';
import {
  register,
  login,
  guestLogin,
  refreshToken,
  getProfile,
  changePassword,
  verifyPhone,
  resendVerificationCode,
  deleteAccount,
} from '../controllers/authController.js';
import { authMiddleware } from '../middlewares/authMiddleware.js';
import { otpSendLimiter, otpVerifyLimiter } from '../middlewares/rateLimiter.js';

export const authRoutes = () => {
  const router = Router();

  router.post('/register', otpSendLimiter, register);
  router.post('/verify-phone', otpVerifyLimiter, verifyPhone);
  router.post('/resend-code', otpSendLimiter, resendVerificationCode);
  router.post('/login', login);
  router.post('/guest', guestLogin);
  router.post('/refresh', refreshToken);
  router.get('/profile', authMiddleware, getProfile);
  router.post('/change-password', authMiddleware, changePassword);
  router.post('/delete-account', authMiddleware, deleteAccount);
  return router;
};
