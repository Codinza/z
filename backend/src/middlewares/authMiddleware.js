import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

export const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, env.jwtSecret);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};

export const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user || (!roles.includes(req.user.role) && req.user.role !== 'super_admin')) {
      return res.status(403).json({ error: 'Access denied: insufficient permissions' });
    }
    next();
  };
};

// Middleware to mask sensitive customer data
export const maskSensitiveData = (req, res, next) => {
  req.maskCustomerPhone = (customer, shouldMask = true) => {
    if (!shouldMask || !customer.phone) return customer;
    return {
      ...customer,
      phone: customer.phone.slice(0, 3) + '****' + customer.phone.slice(-2),
    };
  };
  next();
};

// Middleware to check company access to orders
export const requireCompanyOrderAccess = async (req, res, next) => {
  const { orderId } = req.params;
  
  if (!req.user.companyId) {
    return res.status(403).json({ error: 'Company access required' });
  }
  
  // The order check will be done in the controller
  req.requiredCompanyId = req.user.companyId;
  next();
};
