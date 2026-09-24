import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { prisma } from '../db/prisma.js';

export const authMiddleware = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, env.jwtSecret);
    req.user = decoded;

    // Block legacy tokens issued before the OTP gate (unverified phone).
    const role = String(decoded?.role || '');
    const isStaff = role === 'admin' || role === 'super_admin';
    if (decoded?.id && !isStaff) {
      const user = await prisma.user.findUnique({
        where: { id: decoded.id },
        select: { phoneVerified: true, phone: true },
      });
      const isGuest = user?.phone === 'guest_customer_001';
      if (user && !user.phoneVerified && !isGuest) {
        return res.status(403).json({
          error: 'رقم الموبايل غير مؤكد. أدخل كود التأكيد لتفعيل الحساب.',
          requiresVerification: true,
          phone: user.phone,
          maskedPhone: user.phone
            ? `${String(user.phone).slice(0, 3)}****${String(user.phone).slice(-2)}`
            : undefined,
        });
      }
    }

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

/**
 * Ensures the caller owns the driver resource identified by `:id`
 * (accepted as either Driver.id or User.id), or is an admin.
 */
export const requireSelfDriver = async (req, res, next) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    if (req.user.role === 'super_admin' || req.user.role === 'admin') {
      return next();
    }

    let targetId = req.params.id;
    if (!targetId || targetId === 'me') {
      targetId = req.user.id;
      req.params.id = targetId;
    }

    // Flutter commonly passes the authenticated user id as the driver path id.
    if (targetId === req.user.id) {
      return next();
    }

    const driver = await prisma.driver.findFirst({
      where: { OR: [{ id: targetId }, { userId: targetId }] },
      select: { userId: true },
    });

    if (driver && driver.userId === req.user.id) {
      return next();
    }

    return res.status(403).json({ error: 'Access denied: not your driver account' });
  } catch (_error) {
    return res.status(500).json({ error: 'Failed to verify driver access' });
  }
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
  if (!req.user.companyId) {
    return res.status(403).json({ error: 'Company access required' });
  }

  // The order check will be done in the controller
  req.requiredCompanyId = req.user.companyId;
  next();
};
