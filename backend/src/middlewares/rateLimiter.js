import rateLimit from 'express-rate-limit';
import logger from '../utils/logger.js';

// General rate limiter for all routes
export const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.',
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
      error: 'Too many requests from this IP, please try again later.',
    });
  },
});

// Strict rate limiter for authentication routes
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 requests per windowMs
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