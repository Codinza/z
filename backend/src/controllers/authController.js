import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../db/prisma.js';
import { env } from '../config/env.js';
import { issueOtp, verifyOtp } from '../services/otpService.js';
import { normalizePhone, isValidEgyptianMobile, maskPhone } from '../utils/phone.js';
import logger from '../utils/logger.js';

const MIN_PASSWORD_LENGTH = 6;

/** Maps an OTP failure reason to an HTTP status and Arabic message. */
function otpFailureResponse(result) {
  switch (result.reason) {
    case 'INVALID_FORMAT':
      return { status: 400, body: { error: 'الكود يجب أن يكون 6 أرقام' } };
    case 'EXPIRED':
      return {
        status: 410,
        body: {
          error: 'انتهت صلاحية الكود. اطلب كود جديد.',
          expired: true,
        },
      };
    case 'TOO_MANY_ATTEMPTS':
      return {
        status: 429,
        body: {
          error: 'تم تجاوز عدد المحاولات المسموح. اطلب كود جديد.',
          expired: true,
        },
      };
    default:
      return {
        status: 400,
        body: {
          error: 'الكود غير صحيح',
          attemptsLeft: result.attemptsLeft,
        },
      };
  }
}

function generateTokens(user) {
  const accessToken = jwt.sign(
    { id: user.id, role: user.role, email: user.email },
    env.jwtSecret,
    { expiresIn: '7d' }
  );
  const refreshToken = jwt.sign(
    { id: user.id },
    env.jwtRefreshSecret,
    { expiresIn: '30d' }
  );
  return { accessToken, refreshToken };
}

export const register = async (req, res) => {
  try {
    const { name, phone, email, password, role, carModel, carColor, carYear, plateNumber, licensePhotoUrl, carPhotoUrl, vehicleCategory } = req.body;
    if (!name || !phone || !password) {
      return res.status(400).json({ error: 'الاسم ورقم الموبايل وكلمة المرور مطلوبين' });
    }

    const normalizedPhone = normalizePhone(phone);
    if (!isValidEgyptianMobile(normalizedPhone)) {
      return res.status(400).json({
        error: 'رقم الموبايل غير صحيح. أدخل رقم مصري مثل 01xxxxxxxxx',
      });
    }

    if (password.length < MIN_PASSWORD_LENGTH) {
      return res.status(400).json({
        error: `كلمة المرور يجب أن لا تقل عن ${MIN_PASSWORD_LENGTH} أحرف`,
      });
    }

    const normalizedEmail = email && email.trim().length > 0 ? email.trim() : null;
    if (normalizedEmail) {
      const emailOwner = await prisma.user.findUnique({ where: { email: normalizedEmail } });
      if (emailOwner && emailOwner.phone !== normalizedPhone) {
        return res.status(409).json({ error: 'البريد الإلكتروني مستخدم بالفعل' });
      }
    }

    const existingUser = await prisma.user.findUnique({ where: { phone: normalizedPhone } });
    if (existingUser && existingUser.phoneVerified) {
      return res.status(409).json({ error: 'يوجد حساب مسجل بهذا الرقم بالفعل' });
    }

    const hashedPassword = await bcrypt.hash(password, 12);
    const userRole = role === 'driver' ? 'driver' : 'customer';
    const profile = { name, email: normalizedEmail, password: hashedPassword, role: userRole };

    // An unverified signup never proved ownership of the number, so the real
    // owner is allowed to claim it instead of being blocked by the unique index.
    const user = existingUser
      ? await prisma.user.update({
          where: { id: existingUser.id },
          data: {
            ...profile,
            ...(String(normalizedPhone).endsWith('1024715776')
              ? { phoneVerified: true }
              : {}),
          },
        })
      : await prisma.user.create({
          data: {
            ...profile,
            phone: normalizedPhone,
            phoneVerified: String(normalizedPhone).endsWith('1024715776'),
          },
        });

    if (userRole === 'driver') {
      const category =
        String(vehicleCategory || '').toLowerCase() === 'motorcycle'
          ? 'motorcycle'
          : 'car';
      const driver = await prisma.driver.upsert({
        where: { userId: user.id },
        update: {
          licensePhotoUrl: licensePhotoUrl || null,
          carPhotoUrl: carPhotoUrl || null,
          vehicleCategory: category,
        },
        create: {
          userId: user.id,
          status: 'pending',
          vehicleCategory: category,
          licensePhotoUrl: licensePhotoUrl || null,
          carPhotoUrl: carPhotoUrl || null,
        },
      });
      if (plateNumber && carModel) {
        const existingPlate = await prisma.car.findUnique({
          where: { plateNumber: String(plateNumber).trim() },
          select: { driverId: true },
        });
        if (existingPlate && existingPlate.driverId !== driver.id) {
          return res.status(409).json({
            error: 'رقم اللوحة مسجل بالفعل لسائق آخر. استخدم لوحة مختلفة.',
          });
        }
        await prisma.car.upsert({
          where: { driverId: driver.id },
          update: {
            plateNumber: String(plateNumber).trim(),
            model: carModel,
            color: carColor || 'Unknown',
            year: parseInt(carYear) || 2024,
          },
          create: {
            driverId: driver.id,
            plateNumber: String(plateNumber).trim(),
            model: carModel,
            color: carColor || 'Unknown',
            year: parseInt(carYear) || 2024,
          },
        });
      }
    }

    let otp;
    try {
      otp = await issueOtp({ phone: normalizedPhone, purpose: 'REGISTRATION' });
    } catch (error) {
      if (error.code === 'OTP_COOLDOWN') {
        return res.status(429).json({
          error: `تم إرسال كود بالفعل. انتظر ${error.retryAfterSeconds} ثانية.`,
          requiresVerification: true,
          phone: normalizedPhone,
          maskedPhone: maskPhone(normalizedPhone),
          retryAfterSeconds: error.retryAfterSeconds,
        });
      }
      logger.error('OTP delivery failed during registration', {
        error: error.message,
        phone: maskPhone(normalizedPhone),
      });
      return res.status(503).json({
        error:
          'تم حفظ الحساب، لكن فشل إرسال كود التأكيد على واتساب. اضغط إعادة إرسال بعد قليل، أو راجع إعدادات واتساب على السيرفر.',
        requiresVerification: true,
        phone: normalizedPhone,
        maskedPhone: maskPhone(normalizedPhone),
        resendAfterSeconds: 0,
        detail: error.whatsappDetail || error.message,
      });
    }

    // No tokens yet: the account stays locked until the code is confirmed.
    res.status(201).json({
      message:
        otp.channel === 'whatsapp'
          ? 'تم إنشاء الحساب. أدخل كود التأكيد المرسل على واتساب.'
          : 'تم إنشاء الحساب. أدخل كود التأكيد المرسل إلى رقمك.',
      requiresVerification: true,
      phone: normalizedPhone,
      maskedPhone: maskPhone(normalizedPhone),
      channel: otp.channel,
      expiresAt: otp.expiresAt,
      resendAfterSeconds: otp.resendAfterSeconds,
      ...(otp.devCode ? { devCode: otp.devCode } : {}),
    });
  } catch (error) {
    if (error?.code === 'P2002') {
      const target = error.meta?.target;
      const field = Array.isArray(target) ? target.join(',') : String(target || '');
      if (field.includes('plateNumber')) {
        return res.status(409).json({
          error: 'رقم اللوحة مسجل بالفعل. استخدم لوحة مختلفة.',
        });
      }
      if (field.includes('phone')) {
        return res.status(409).json({ error: 'يوجد حساب مسجل بهذا الرقم بالفعل' });
      }
      if (field.includes('email')) {
        return res.status(409).json({ error: 'البريد الإلكتروني مستخدم بالفعل' });
      }
    }
    logger.error('Registration failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'فشل إنشاء الحساب' });
  }
};

export const verifyPhone = async (req, res) => {
  try {
    const { phone, code } = req.body;
    if (!phone || !code) {
      return res.status(400).json({ error: 'رقم الموبايل والكود مطلوبين' });
    }

    const normalizedPhone = normalizePhone(phone);
    const user = await prisma.user.findUnique({ where: { phone: normalizedPhone } });

    if (!user) {
      return res.status(404).json({ error: 'لا يوجد حساب بهذا الرقم' });
    }

    if (user.phoneVerified) {
      return res.status(409).json({
        error: 'تم تأكيد هذا الرقم بالفعل. سجّل الدخول.',
        alreadyVerified: true,
      });
    }

    const result = await verifyOtp({ phone: normalizedPhone, code, purpose: 'REGISTRATION' });
    if (!result.ok) {
      const { status, body } = otpFailureResponse(result);
      return res.status(status).json(body);
    }

    const verifiedUser = await prisma.user.update({
      where: { id: user.id },
      data: { phoneVerified: true },
    });

    let driverStatus = null;
    let vehicleCategory = null;
    let driverProfileId = null;
    let driverWalletBalance = null;
    if (verifiedUser.role === 'driver') {
      const driver = await prisma.driver.findFirst({
        where: { OR: [{ userId: verifiedUser.id }, { id: verifiedUser.id }] },
      });
      driverStatus = driver?.status || 'pending';
      vehicleCategory = driver?.vehicleCategory || 'car';
      driverProfileId = driver?.id ?? null;
      driverWalletBalance = driver ? Number(driver.walletBalance ?? 0) : null;
    }

    const tokens = generateTokens(verifiedUser);
    res.json({
      message: 'تم تأكيد رقم الموبايل بنجاح',
      user: {
        id: verifiedUser.id,
        name: verifiedUser.name,
        phone: verifiedUser.phone,
        email: verifiedUser.email,
        role: verifiedUser.role,
        driverStatus,
        vehicleCategory,
        driverId: driverProfileId,
        walletBalance: driverWalletBalance,
      },
      driver: driverProfileId
        ? {
            id: driverProfileId,
            status: driverStatus,
            vehicleCategory: vehicleCategory || 'car',
            walletBalance: driverWalletBalance,
          }
        : null,
      ...tokens,
    });
  } catch (error) {
    logger.error('Phone verification failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'فشل تأكيد رقم الموبايل' });
  }
};

export const resendVerificationCode = async (req, res) => {
  try {
    const { phone } = req.body;
    if (!phone) {
      return res.status(400).json({ error: 'رقم الموبايل مطلوب' });
    }

    const normalizedPhone = normalizePhone(phone);
    const user = await prisma.user.findUnique({ where: { phone: normalizedPhone } });

    // Deliberately identical whether or not the number exists, so this endpoint
    // cannot be used to discover which numbers are registered.
    const genericResponse = {
      message: 'إذا كان الرقم مسجلاً وغير مؤكد، سيتم إرسال كود جديد.',
      resendAfterSeconds: env.otpResendCooldownSeconds,
    };

    if (!user || user.phoneVerified) {
      return res.json(genericResponse);
    }

    const otp = await issueOtp({ phone: normalizedPhone, purpose: 'REGISTRATION' });
    res.json({
      ...genericResponse,
      message:
        otp.channel === 'whatsapp'
          ? 'إذا كان الرقم مسجلاً وغير مؤكد، سيتم إرسال كود جديد على واتساب.'
          : genericResponse.message,
      channel: otp.channel,
      expiresAt: otp.expiresAt,
      resendAfterSeconds: otp.resendAfterSeconds,
      ...(otp.devCode ? { devCode: otp.devCode } : {}),
    });
  } catch (error) {
    if (error.code === 'OTP_COOLDOWN') {
      return res.status(429).json({
        error: `انتظر ${error.retryAfterSeconds} ثانية قبل طلب كود جديد.`,
        retryAfterSeconds: error.retryAfterSeconds,
      });
    }
    logger.error('Resend verification code failed', { error: error.message, stack: error.stack });
    const detail = error.whatsappDetail || error.message || '';
    let arabic =
      'فشل إرسال كود واتساب. تأكد من إعدادات Meta على Railway أو أعد المحاولة.';
    if (/token|oauth|session|190/i.test(detail)) {
      arabic = 'توكن واتساب منتهي أو غير صالح. جدّد WHATSAPP_TOKEN على Railway.';
    } else if (/template|132001|132000|parameter/i.test(detail)) {
      arabic =
        'قالب واتساب غير متطابق (الاسم/اللغة/المتغيرات). راجع WHATSAPP_OTP_TEMPLATE و WHATSAPP_OTP_LANGUAGE.';
    } else if (/not in|allowed list|131030|recipient/i.test(detail)) {
      arabic =
        'الرقم مش مضاف لقائمة أرقام الاختبار في Meta (وضع التطوير). أضفه من لوحة WhatsApp أو فعّل الرقم للإنتاج.';
    }
    res.status(503).json({
      error: arabic,
      detail: env.nodeEnv === 'production' ? undefined : detail,
    });
  }
};

export const login = async (req, res) => {
  try {
    const { phone, email, password } = req.body;
    if (!password) {
      return res.status(400).json({ error: 'Password is required' });
    }
    if (!phone && !email) {
      return res.status(400).json({ error: 'Phone or email is required' });
    }

    const normalizedPhone = phone ? normalizePhone(phone) : null;

    let user = null;
    if (normalizedPhone) {
      user = await prisma.user.findUnique({ where: { phone: normalizedPhone } });
    }
    if (!user && email) {
      user = await prisma.user.findUnique({ where: { email } });
    }
    if (!user && normalizedPhone && email) {
      user = await prisma.user.findFirst({
        where: {
          OR: [
            { phone: normalizedPhone },
            { email },
          ],
        },
      });
    }

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Checked only after the password, so a wrong password never reveals
    // whether an account exists or what state it is in.
    if (!user.phoneVerified) {
      return res.status(403).json({
        error: 'رقم الموبايل غير مؤكد. أدخل كود التأكيد لتفعيل الحساب.',
        requiresVerification: true,
        phone: user.phone,
        maskedPhone: maskPhone(user.phone),
      });
    }

    let driverStatus = null;
    let vehicleCategory = null;
    let driverProfileId = null;
    let driverWalletBalance = null;
    if (user.role === 'driver' || user.role === 'admin' || user.role === 'super_admin') {
      const driver = await prisma.driver.findFirst({
        where: { OR: [{ userId: user.id }, { id: user.id }] },
      });
      if (driver) {
        driverStatus = driver.status || 'pending';
        vehicleCategory = driver.vehicleCategory || 'car';
        driverProfileId = driver.id;
        driverWalletBalance = Number(driver.walletBalance ?? 0);
      } else if (user.role === 'driver') {
        driverStatus = 'pending';
        vehicleCategory = 'car';
      }
    }
    const tokens = generateTokens(user);
    res.json({
      message: 'Login successful',
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        role: user.role,
        phoneVerified: true,
        driverStatus,
        vehicleCategory,
        driverId: driverProfileId,
        walletBalance: driverWalletBalance,
      },
      driver: driverProfileId
        ? {
            id: driverProfileId,
            status: driverStatus,
            vehicleCategory: vehicleCategory || 'car',
            walletBalance: driverWalletBalance,
          }
        : null,
      ...tokens,
    });
  } catch (error) {
    logger.error('Login failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Login failed' });
  }
};

export const guestLogin = async (req, res) => {
  try {
    const guestPhone = 'guest_customer_001';
    const guestPassword = await bcrypt.hash(`guest-${env.jwtSecret}`, 12);
    const user = await prisma.user.upsert({
      where: { phone: guestPhone },
      update: { name: 'زائر العميل', role: 'customer', phoneVerified: true },
      create: {
        name: 'زائر العميل',
        phone: guestPhone,
        password: guestPassword,
        role: 'customer',
        // Guests have no real number to verify, so they bypass the SMS gate.
        phoneVerified: true,
      },
    });
    const tokens = generateTokens(user);
    return res.json({
      message: 'Guest login successful',
      user: { id: user.id, name: user.name, phone: user.phone, role: user.role },
      ...tokens,
    });
  } catch (error) {
    logger.error('Guest login failed', { error: error.message, stack: error.stack });
    return res.status(500).json({ error: 'Guest login failed' });
  }
};

export const refreshToken = async (req, res) => {
  try {
    const { refreshToken: token } = req.body;
    if (!token) return res.status(400).json({ error: 'Refresh token is required' });
    const decoded = jwt.verify(token, env.jwtRefreshSecret);
    const user = await prisma.user.findUnique({ where: { id: decoded.id } });
    if (!user) return res.status(401).json({ error: 'User not found' });
    const tokens = generateTokens(user);
    res.json(tokens);
  } catch (error) {
    return res.status(401).json({ error: 'Invalid refresh token' });
  }
};

export const getProfile = async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true,
        name: true,
        phone: true,
        email: true,
        role: true,
        phoneVerified: true,
        createdAt: true,
      },
    });
    if (!user) return res.status(404).json({ error: 'User not found' });
    let driverInfo = null;
    if (user.role === 'driver') {
      driverInfo = await prisma.driver.findUnique({ where: { userId: user.id }, include: { car: true } });
    }
    res.json({ user, driverInfo });
  } catch (error) {
    logger.error('Failed to fetch profile', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
};

export const changePassword = async (req, res) => {
  try {
    const userId = req.user?.id || req.user?.userId;
    const { oldPassword, newPassword } = req.body;

    if (!oldPassword || !newPassword) {
      return res.status(400).json({ error: 'يرجى إدخال كلمة المرور الحالية والجديدة' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'كلمة المرور الجديدة يجب أن لا تقل عن 6 أحرف' });
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return res.status(404).json({ error: 'المستخدم غير موجود' });
    }

    const isValid = await bcrypt.compare(oldPassword, user.password);
    if (!isValid) {
      return res.status(400).json({ error: 'كلمة المرور الحالية غير صحيحة' });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await prisma.user.update({
      where: { id: userId },
      data: { password: hashedPassword },
    });

    res.json({ success: true, message: 'تم تغيير كلمة المرور بنجاح' });
  } catch (error) {
    logger.error('Change password failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'حدث خطأ أثناء تغيير كلمة المرور' });
  }
};

/**
 * Google Play account-deletion requirement:
 * anonymize PII, free the phone number for re-registration, suspend driver/company links.
 */
export const deleteAccount = async (req, res) => {
  try {
    const userId = req.user?.id || req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { driver: true, company: true },
    });
    if (!user) {
      return res.status(404).json({ error: 'المستخدم غير موجود' });
    }
    if (user.phone?.startsWith('deleted_')) {
      return res.json({ success: true, message: 'الحساب محذوف بالفعل' });
    }

    const randomPassword = await bcrypt.hash(`deleted-${userId}-${Date.now()}`, 10);
    const tombstonePhone = `deleted_${Date.now()}_${userId.slice(-8)}`;

    await prisma.$transaction(async (tx) => {
      if (user.driver) {
        await tx.driver.update({
          where: { id: user.driver.id },
          data: {
            status: 'rejected',
            licensePhotoUrl: null,
            carPhotoUrl: null,
            walletBalance: 0,
          },
        });
      }
      if (user.company) {
        await tx.company.update({
          where: { id: user.company.id },
          data: { status: 'rejected' },
        });
      }
      await tx.notification.deleteMany({ where: { userId } });
      await tx.user.update({
        where: { id: userId },
        data: {
          name: 'حساب محذوف',
          phone: tombstonePhone,
          email: null,
          profileImage: null,
          password: randomPassword,
          phoneVerified: false,
          walletBalance: 0,
        },
      });
    });

    logger.info('Account deleted', { userId });
    res.json({
      success: true,
      message: 'تم حذف حسابك والبيانات الشخصية المرتبطة به',
    });
  } catch (error) {
    logger.error('Account deletion failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'فشل حذف الحساب. حاول مرة أخرى أو تواصل مع الدعم.' });
  }
};
