import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import logger from '../utils/logger.js';

const prisma = new PrismaClient();

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
    const { name, phone, email, password, role, carModel, carColor, carYear, plateNumber, licensePhotoUrl, carPhotoUrl } = req.body;
    if (!name || !phone || !password) {
      return res.status(400).json({ error: 'Name, phone, and password are required' });
    }
    const existingUser = await prisma.user.findFirst({
      where: { OR: [{ phone }, ...(email ? [{ email }] : [])] },
    });
    if (existingUser) {
      return res.status(409).json({ error: 'User with this phone or email already exists' });
    }
    const hashedPassword = await bcrypt.hash(password, 12);
    const userRole = role === 'driver' ? 'driver' : 'customer';
    const user = await prisma.user.create({
      data: { name, phone, email: email || null, password: hashedPassword, role: userRole },
    });
    if (userRole === 'driver') {
      const driver = await prisma.driver.create({
        data: { userId: user.id, status: 'pending', licensePhotoUrl: licensePhotoUrl || null, carPhotoUrl: carPhotoUrl || null },
      });
      if (plateNumber && carModel) {
        await prisma.car.create({
          data: { driverId: driver.id, plateNumber, model: carModel || 'Unknown', color: carColor || 'Unknown', year: parseInt(carYear) || 2024 },
        });
      }
    }
    const tokens = generateTokens(user);
    res.status(201).json({
      message: 'Registration successful',
      user: { id: user.id, name: user.name, phone: user.phone, email: user.email, role: user.role },
      ...tokens,
    });
  } catch (error) {
    logger.error('Registration failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Registration failed' });
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

    let user = null;
    if (phone) {
      user = await prisma.user.findUnique({ where: { phone } });
    }
    if (!user && email) {
      user = await prisma.user.findUnique({ where: { email } });
    }
    if (!user && phone && email) {
      user = await prisma.user.findFirst({
        where: {
          OR: [
            { phone },
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
    let driverStatus = null;
    if (user.role === 'driver') {
      const driver = await prisma.driver.findUnique({ where: { userId: user.id } });
      driverStatus = driver?.status || 'pending';
    }
    const tokens = generateTokens(user);
    res.json({
      message: 'Login successful',
      user: { id: user.id, name: user.name, phone: user.phone, email: user.email, role: user.role, driverStatus },
      driver: driverStatus ? { status: driverStatus } : null,
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
      update: { name: 'زائر العميل', role: 'customer' },
      create: {
        name: 'زائر العميل',
        phone: guestPhone,
        password: guestPassword,
        role: 'customer',
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
      select: { id: true, name: true, phone: true, email: true, role: true, createdAt: true },
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
