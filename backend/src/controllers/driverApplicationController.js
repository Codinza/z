import jwt from 'jsonwebtoken';
import { prisma } from '../db/prisma.js';
import { env } from '../config/env.js';
import logger from '../utils/logger.js';

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

/**
 * POST /api/driver-application
 * A signed-in customer applies to become a captain from inside the app.
 * They stay a customer until an admin approves the application.
 */
export const submitDriverApplication = async (req, res) => {
  try {
    const userId = req.user?.id;
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return res.status(401).json({ error: 'الحساب غير موجود' });
    }
    if (user.role !== 'customer') {
      return res.status(403).json({ error: 'الحساب ده مش حساب عميل' });
    }

    const {
      name,
      vehicleCategory,
      carModel,
      carColor,
      carYear,
      plateNumber,
      licensePhotoUrl,
      carPhotoUrl,
      carSidePhotoUrl,
      idFrontPhotoUrl,
      idBackPhotoUrl,
      workType,
      birthDate,
      address,
      email,
    } = req.body || {};

    const cleanEmail = String(email || '').trim().toLowerCase();
    if (cleanEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(cleanEmail)) {
      return res.status(400).json({ error: 'الإيميل مش مكتوب صح' });
    }
    if (cleanEmail) {
      const emailOwner = await prisma.user.findUnique({
        where: { email: cleanEmail },
        select: { id: true },
      });
      if (emailOwner && emailOwner.id !== userId) {
        return res
          .status(409)
          .json({ error: 'الإيميل ده مستخدم في حساب تاني' });
      }
    }

    const cleanWorkType = ['city', 'courier', 'travel'].includes(String(workType))
      ? String(workType)
      : 'city';
    const cleanBirthDate = String(birthDate || '').trim().slice(0, 20) || null;
    const cleanAddress = String(address || '').trim().slice(0, 300) || null;

    const category =
      String(vehicleCategory || '').toLowerCase() === 'motorcycle'
        ? 'motorcycle'
        : 'car';
    const model = String(carModel || '').trim();
    const color = String(carColor || '').trim();
    const plate = String(plateNumber || '').trim();
    const year = parseInt(carYear, 10);
    const cleanName = String(name || '').trim();

    if (!model || !color || !plate || !year) {
      return res.status(400).json({
        error:
          category === 'motorcycle'
            ? 'اكتب بيانات الدراجة كاملة (الموديل، اللون، السنة، اللوحة)'
            : 'اكتب بيانات السيارة كاملة (الموديل، اللون، السنة، اللوحة)',
      });
    }
    if (year < 1980 || year > new Date().getFullYear() + 1) {
      return res.status(400).json({ error: 'سنة الصنع غير صحيحة' });
    }
    if (cleanName && (cleanName.length < 2 || cleanName.length > 60)) {
      return res.status(400).json({ error: 'الاسم لازم يكون من 2 لـ 60 حرف' });
    }

    const existing = await prisma.driver.findUnique({ where: { userId } });
    if (existing && existing.status === 'approved') {
      return res.status(409).json({ error: 'طلبك اتقبل بالفعل' });
    }

    const plateOwner = await prisma.car.findUnique({
      where: { plateNumber: plate },
      select: { driverId: true },
    });
    if (plateOwner && plateOwner.driverId !== existing?.id) {
      return res.status(409).json({
        error: 'رقم اللوحة مسجل بالفعل لكابتن تاني. استخدم لوحة مختلفة.',
      });
    }

    const driver = await prisma.$transaction(async (tx) => {
      if (cleanName || cleanEmail) {
        await tx.user.update({
          where: { id: userId },
          data: {
            ...(cleanName ? { name: cleanName } : {}),
            ...(cleanEmail ? { email: cleanEmail } : {}),
          },
        });
      }
      const saved = await tx.driver.upsert({
        where: { userId },
        update: {
          status: 'pending',
          vehicleCategory: category,
          workType: cleanWorkType,
          birthDate: cleanBirthDate,
          address: cleanAddress,
          ...(licensePhotoUrl ? { licensePhotoUrl } : {}),
          ...(carPhotoUrl ? { carPhotoUrl } : {}),
          ...(carSidePhotoUrl ? { carSidePhotoUrl } : {}),
          ...(idFrontPhotoUrl ? { idFrontPhotoUrl } : {}),
          ...(idBackPhotoUrl ? { idBackPhotoUrl } : {}),
        },
        create: {
          userId,
          status: 'pending',
          vehicleCategory: category,
          workType: cleanWorkType,
          birthDate: cleanBirthDate,
          address: cleanAddress,
          licensePhotoUrl: licensePhotoUrl || null,
          carPhotoUrl: carPhotoUrl || null,
          carSidePhotoUrl: carSidePhotoUrl || null,
          idFrontPhotoUrl: idFrontPhotoUrl || null,
          idBackPhotoUrl: idBackPhotoUrl || null,
        },
      });
      await tx.car.upsert({
        where: { driverId: saved.id },
        update: { plateNumber: plate, model, color, year },
        create: { driverId: saved.id, plateNumber: plate, model, color, year },
      });
      return saved;
    });

    res.status(201).json({
      message: 'تم إرسال طلب الانضمام. هنراجعه ونبلغك.',
      status: driver.status,
      vehicleCategory: driver.vehicleCategory,
    });
  } catch (error) {
    if (error?.code === 'P2002') {
      return res.status(409).json({
        error: 'رقم اللوحة مسجل بالفعل. استخدم لوحة مختلفة.',
      });
    }
    logger.error('Driver application failed', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: 'تعذّر إرسال الطلب. حاول مرة أخرى.' });
  }
};

/**
 * GET /api/driver-application/me
 * Status of the caller's application. Once approved, the account becomes a
 * captain account and fresh tokens are returned so the app can switch over.
 */
export const getMyDriverApplication = async (req, res) => {
  try {
    const userId = req.user?.id;
    let user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return res.status(401).json({ error: 'الحساب غير موجود' });
    }

    const driver = await prisma.driver.findUnique({
      where: { userId },
      include: { car: true },
    });
    if (!driver) {
      return res.json({ status: 'none' });
    }

    if (driver.status !== 'approved') {
      return res.json({
        status: driver.status,
        vehicleCategory: driver.vehicleCategory,
        car: driver.car
          ? {
              model: driver.car.model,
              color: driver.car.color,
              year: driver.car.year,
              plateNumber: driver.car.plateNumber,
            }
          : null,
      });
    }

    if (user.role === 'customer') {
      user = await prisma.user.update({
        where: { id: user.id },
        data: { role: 'driver' },
      });
    }

    const tokens = generateTokens(user);
    res.json({
      status: 'approved',
      vehicleCategory: driver.vehicleCategory,
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        role: user.role,
        phoneVerified: true,
        driverStatus: 'approved',
        vehicleCategory: driver.vehicleCategory,
        driverId: driver.id,
        walletBalance: Number(driver.walletBalance ?? 0),
      },
      driver: {
        id: driver.id,
        status: 'approved',
        vehicleCategory: driver.vehicleCategory,
        walletBalance: Number(driver.walletBalance ?? 0),
      },
      ...tokens,
    });
  } catch (error) {
    logger.error('Driver application status failed', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: 'تعذّر تحميل حالة الطلب' });
  }
};
