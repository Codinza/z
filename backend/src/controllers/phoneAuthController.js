import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../db/prisma.js';
import { env } from '../config/env.js';
import { issueOtp, verifyOtp } from '../services/otpService.js';
import { normalizePhone, isValidEgyptianMobile, maskPhone } from '../utils/phone.js';
import logger from '../utils/logger.js';

const PURPOSE = 'LOGIN';
const CODE_ONLY_ROLES = ['admin', 'super_admin'];
// Customers sign in with the phone alone; admins must also prove the number
// with a WhatsApp code. Captains/companies have their own apps.
const isAllowedRole = (role) => role === 'customer' || CODE_ONLY_ROLES.includes(role);
const DEFAULT_CUSTOMER_NAME = 'عميل Zoon';

function generateTokens(user) {
  const accessToken = jwt.sign(
    { id: user.id, role: user.role, email: user.email },
    env.jwtSecret,
    { expiresIn: '7d' }
  );
  const refreshToken = jwt.sign({ id: user.id }, env.jwtRefreshSecret, {
    expiresIn: '30d',
  });
  return { accessToken, refreshToken };
}

function whatsappErrorMessage(error) {
  const detail = error?.whatsappDetail || error?.message || '';
  if (/token|oauth|session|190/i.test(detail)) {
    return 'تعذّر إرسال الكود الآن. حاول بعد شوية.';
  }
  if (/not in|allowed list|131030|recipient/i.test(detail)) {
    return 'الرقم ده مش متاح له الإرسال على واتساب حاليًا.';
  }
  return 'تعذّر إرسال الكود على واتساب. حاول مرة أخرى.';
}

function otpFailure(result) {
  switch (result.reason) {
    case 'INVALID_FORMAT':
      return { status: 400, body: { error: 'الكود لازم يكون 6 أرقام' } };
    case 'EXPIRED':
      return {
        status: 410,
        body: { error: 'انتهت صلاحية الكود. اطلب كود جديد.', expired: true },
      };
    case 'TOO_MANY_ATTEMPTS':
      return {
        status: 429,
        body: { error: 'محاولات كتير غلط. اطلب كود جديد.', expired: true },
      };
    default:
      return {
        status: 400,
        body: { error: 'الكود غير صحيح', attemptsLeft: result.attemptsLeft },
      };
  }
}

function sessionPayload(user, isNew) {
  const tokens = generateTokens(user);
  return {
    message: isNew ? 'تم إنشاء الحساب' : 'تم تسجيل الدخول',
    isNew,
    user: {
      id: user.id,
      name: user.name,
      phone: user.phone,
      email: user.email,
      role: user.role,
      phoneVerified: true,
      driverStatus: null,
      vehicleCategory: null,
      driverId: null,
      walletBalance: null,
    },
    driver: null,
    ...tokens,
  };
}

/** POST /api/auth/phone/start  { phone } — sends a login/sign-up code. */
export const startPhoneSignIn = async (req, res) => {
  try {
    const { phone } = req.body || {};
    if (!phone) {
      return res.status(400).json({ error: 'رقم الموبايل مطلوب' });
    }
    const normalizedPhone = normalizePhone(phone);
    if (!isValidEgyptianMobile(normalizedPhone)) {
      return res.status(400).json({
        error: 'رقم الموبايل غير صحيح. اكتب رقم مصري مثل 01xxxxxxxxx',
      });
    }

    const existing = await prisma.user.findUnique({
      where: { phone: normalizedPhone },

    });
    if (existing && !isAllowedRole(existing.role)) {
      return res.status(403).json({
        error: 'الرقم ده مسجل كحساب كابتن أو شركة. استخدم التطبيق الخاص بيه.',
      });
    }

    // Already-registered customers sign straight in, no code.
    if (existing && existing.role === 'customer') {
      return res.json(sessionPayload(existing, false));
    }

    const otp = await issueOtp({ phone: normalizedPhone, purpose: PURPOSE });
    res.json({
      message: 'تم إرسال الكود',
      phone: normalizedPhone,
      maskedPhone: maskPhone(normalizedPhone),
      channel: otp.channel,
      expiresAt: otp.expiresAt,
      resendAfterSeconds: otp.resendAfterSeconds,
      ...(otp.devCode ? { devCode: otp.devCode } : {}),
    });
  } catch (error) {
    if (error.code === 'OTP_COOLDOWN') {
      return res.status(429).json({
        error: `استنى ${error.retryAfterSeconds} ثانية قبل ما تطلب كود جديد.`,
        retryAfterSeconds: error.retryAfterSeconds,
      });
    }
    logger.error('Phone sign-in start failed', {
      error: error.message,
      stack: error.stack,
    });
    res.status(503).json({ error: whatsappErrorMessage(error) });
  }
};

/** POST /api/auth/phone/verify  { phone, code } — signs in, creating the customer if new. */
export const verifyPhoneSignIn = async (req, res) => {
  try {
    const { phone, code } = req.body || {};
    if (!phone || !code) {
      return res.status(400).json({ error: 'رقم الموبايل والكود مطلوبين' });
    }
    const normalizedPhone = normalizePhone(phone);
    if (!isValidEgyptianMobile(normalizedPhone)) {
      return res.status(400).json({ error: 'رقم الموبايل غير صحيح' });
    }

    const existing = await prisma.user.findUnique({
      where: { phone: normalizedPhone },
    });
    if (existing && !isAllowedRole(existing.role)) {
      return res.status(403).json({
        error: 'الرقم ده مسجل كحساب كابتن أو شركة. استخدم التطبيق الخاص بيه.',
      });
    }

    const result = await verifyOtp({
      phone: normalizedPhone,
      code,
      purpose: PURPOSE,
    });
    if (!result.ok) {
      const { status, body } = otpFailure(result);
      return res.status(status).json(body);
    }

    let user = existing;
    let isNew = false;
    if (!user) {
      const randomPassword = crypto.randomBytes(24).toString('hex');
      user = await prisma.user.create({
        data: {
          name: DEFAULT_CUSTOMER_NAME,
          phone: normalizedPhone,
          password: await bcrypt.hash(randomPassword, 12),
          role: 'customer',
          phoneVerified: true,
        },
      });
      isNew = true;
    } else if (!user.phoneVerified) {
      user = await prisma.user.update({
        where: { id: user.id },
        data: { phoneVerified: true },
      });
    }

    const tokens = generateTokens(user);
    res.json({
      message: isNew ? 'تم إنشاء الحساب' : 'تم تسجيل الدخول',
      isNew,
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        role: user.role,
        phoneVerified: true,
        driverStatus: null,
        vehicleCategory: null,
        driverId: null,
        walletBalance: null,
      },
      driver: null,
      ...tokens,
    });
  } catch (error) {
    if (error?.code === 'P2002') {
      return res.status(409).json({ error: 'الرقم ده مسجل بالفعل. جرّب تاني.' });
    }
    logger.error('Phone sign-in verify failed', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: 'تعذّر تسجيل الدخول. حاول مرة أخرى.' });
  }
};
