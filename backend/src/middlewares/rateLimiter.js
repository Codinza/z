import rateLimit from 'express-rate-limit';
import logger from '../utils/logger.js';

// General rate limiter for all routes
export const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 3000, // Accommodate real-time polling & shared mobile carrier IPs
  message: {
    error: 'Too many requests, please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn('Rate limit exceeded', {
      ip: req.ip,
      method: req.method,
      url: req.url,
    });
    res.status(429).json({
      error: 'Too many requests, please try again later.',
    });
  },
});

// Rate limiter for authentication routes
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 30, // Limit each IP to 30 requests per windowMs
  message: {
    error: 'Too many authentication attempts, please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn('Auth rate limit exceeded', {
      ip: req.ip,
      method: req.method,
      url: req.url,
    });
    res.status(429).json({
      error: 'Too many authentication attempts, please try again later.',
    });
  },
});

// OTP limits are enforced per phone number in otpService (resend cooldown +
// attempt cap). These IP limiters are only a coarse anti-abuse backstop, kept
// loose on purpose because Egyptian mobile carriers NAT many users onto one IP.

// Sending costs money, so this is the tighter of the two.
export const otpSendLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn('OTP send rate limit exceeded', {
      ip: req.ip,
      method: req.method,
      url: req.url,
    });
    res.status(429).json({
      error: 'عدد كبير من طلبات الكود. حاول بعد قليل.',
    });
  },
});

// Verifying is free and already capped at otpMaxAttempts per code.
export const otpVerifyLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn('OTP verify rate limit exceeded', {
      ip: req.ip,
      method: req.method,
      url: req.url,
    });
    res.status(429).json({
      error: 'عدد كبير من محاولات التأكيد. حاول بعد قليل.',
    });
  },
});

// Moderate rate limiter for sensitive operations
export const sensitiveLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // Limit each IP to 20 requests per windowMs
  message: {
    error: 'Too many requests on this endpoint, please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn('Sensitive operation rate limit exceeded', {
      ip: req.ip,
      method: req.method,
      url: req.url,
    });
    res.status(429).json({
      error: 'Too many requests on this endpoint, please try again later.',
    });
  },
});