import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { Server } from 'socket.io';
import { env } from './config/env.js';
import { prisma } from './db/prisma.js';
import { tripRoutes } from './routes/tripRoutes.js';
import { driverRoutes } from './routes/driverRoutes.js';
import { locationRoutes } from './routes/locationRoutes.js';
import { initSocketServer } from './sockets/socketServer.js';
import { paymentRoutes } from './routes/paymentRoutes.js';
import { notificationRoutes } from './routes/notificationRoutes.js';
import { settingsRoutes } from './routes/settingsRoutes.js';
import { authRoutes } from './routes/authRoutes.js';
import { adminRoutes } from './routes/adminRoutes.js';
import { companyRoutes } from './routes/companyRoutes.js';
import { orderRoutes } from './routes/orderRoutes.js';
import { mapsRoutes } from './routes/mapsRoutes.js';
import { customerRoutes } from './routes/customerRoutes.js';
import { setSocketIO } from './services/tripService.js';
import { authMiddleware, requireRole } from './middlewares/authMiddleware.js';
import { generalLimiter, authLimiter, sensitiveLimiter } from './middlewares/rateLimiter.js';
import logger from './utils/logger.js';

const app = express();
app.set('trust proxy', 1);
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
  },
});

app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Apply general rate limiting to all routes
app.use(generalLimiter);

app.use((req, res, next) => {
  const sensitiveKeys = new Set([
    'password',
    'oldPassword',
    'newPassword',
    'token',
    'accessToken',
    'refreshToken',
    'receiptImage',
    'shippingImageBase64',
    'profileImage',
    'licensePhotoUrl',
    'carPhotoUrl',
  ]);

  let safeBody;
  if (req.body && typeof req.body === 'object' && !Array.isArray(req.body)) {
    safeBody = {};
    for (const [key, value] of Object.entries(req.body)) {
      if (sensitiveKeys.has(key)) {
        safeBody[key] = '[REDACTED]';
      } else {
        safeBody[key] = value;
      }
    }
  } else {
    safeBody = undefined;
  }

  logger.info('Incoming request', {
    method: req.method,
    url: req.url,
    ...(safeBody ? { body: safeBody } : {}),
  });
  next();
});

app.get('/privacy-policy', (_, res) => {
  res.type('html').send(`<!doctype html>
<html lang="ar" dir="rtl">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>سياسة خصوصية Zoon</title></head>
<body style="font-family:Arial,sans-serif;max-width:760px;margin:40px auto;padding:0 20px;line-height:1.8">
  <h1>سياسة خصوصية تطبيق Zoon</h1>
  <p>نحترم خصوصيتك ونجمع الحد الأدنى من البيانات اللازمة لتشغيل خدمات حجز الرحلات والشحن.</p>
  <h2>البيانات التي نجمعها</h2>
  <p>قد نجمع الاسم ورقم الهاتف وبيانات الحساب ومعلومات الطلبات والموقع الجغرافي عند استخدام ميزات الحجز والتتبع.</p>
  <h2>طريقة استخدام البيانات</h2>
  <p>نستخدم البيانات لتسجيل الدخول، تنفيذ الطلبات، تحسين الخدمة، والتواصل معك بشأن رحلاتك وطلباتك.</p>
  <h2>المشاركة والحماية</h2>
  <p>لا نبيع بياناتك. قد تتم مشاركة البيانات اللازمة مع السائق أو الشركة لتنفيذ الطلب. تُرسل البيانات عبر اتصال HTTPS وتُحفظ وفق ضوابط الوصول.</p>
  <h2>الموقع الجغرافي</h2>
  <p>يُستخدم الموقع لتحديد الرحلة والتتبع وتقديم الخدمة. يمكنك إيقاف إذن الموقع من إعدادات جهازك، وقد تتوقف بعض الميزات عن العمل.</p>
  <h2>حقوقك</h2>
  <p>يمكنك طلب تحديث بياناتك أو حذف حسابك عبر التواصل مع دعم Zoon.</p>
  <p>آخر تحديث: 21 سبتمبر 2026</p>
</body></html>`);
});

app.get('/account-deletion', (_, res) => {
  res.type('html').send(`<!doctype html>
<html lang="ar" dir="rtl">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>طلب حذف حساب Zoon</title></head>
<body style="font-family:Arial,sans-serif;max-width:760px;margin:40px auto;padding:0 20px;line-height:1.8">
  <h1>طلب حذف حساب Zoon</h1>
  <p>يمكنك حذف حسابك مباشرة من داخل التطبيق:</p>
  <ol>
    <li>افتح تطبيق Zoon</li>
    <li>الإعدادات ← حذف الحساب</li>
    <li>أكّد الحذف</li>
  </ol>
  <p>أو أرسل طلب حذف بالبريد من الرقم/البريد المرتبط بحسابك إلى:</p>
  <p><a href="mailto:ayman01aay@gmail.com?subject=Zoon%20account%20deletion%20request">ayman01aay@gmail.com</a></p>
  <h2>ما الذي يُحذف؟</h2>
  <p>الاسم، رقم الهاتف، البريد، صورة الملف، رصيد المحفظة الشخصي، وبيانات السائق/الشركة المرتبطة بالحساب. قد نحتفظ بسجلات الرحلات/الطلبات بشكل مجهّل للالتزام القانوني ومنع الاحتيال لمدة تصل إلى 30 يومًا ثم تُحذف أو تبقى مجهّلة.</p>
  <p>آخر تحديث: 21 سبتمبر 2026</p>
</body></html>`);
});

app.get('/terms', (_, res) => {
  res.type('html').send(`<!doctype html>
<html lang="ar" dir="rtl">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>شروط استخدام Zoon</title></head>
<body style="font-family:Arial,sans-serif;max-width:760px;margin:40px auto;padding:0 20px;line-height:1.8">
  <h1>شروط وأحكام استخدام تطبيق Zoon</h1>
  <p>باستخدامك لتطبيق Zoon فإنك توافق على استخدام الخدمة لحجز الرحلات وطلبات الشحن بشكل قانوني وآمن.</p>
  <h2>الخدمة</h2>
  <p>يوفر التطبيق منصة للربط بين العملاء والسائقين/شركات النقل. الأسعار والعروض قد تختلف حسب الطلب والمسافة والوقت.</p>
  <h2>حسابك</h2>
  <p>أنت مسؤول عن سرية بيانات الدخول وصحة رقم الهاتف. يُحظر إساءة الاستخدام أو الاحتيال أو إزعاج الآخرين.</p>
  <h2>المدفوعات</h2>
  <p>قد تتم المدفوعات نقدًا أو عبر المحفظة/بوابات الدفع المتاحة. رسوم الإلغاء أو العمولات تُطبق وفق سياسة التطبيق المعروضة وقت الطلب.</p>
  <h2>الموقع</h2>
  <p>نستخدم الموقع لتقديم الخدمة والتتبع. يمكنك إيقاف الإذن من إعدادات الجهاز مع تأثر بعض الميزات.</p>
  <h2>إخلاء المسؤولية</h2>
  <p>نبذل جهدًا لتوفير خدمة مستقرة، لكن قد تحدث انقطاعات أو تأخيرات خارجة عن السيطرة. في حال النزاع تواصل مع الدعم.</p>
  <p>للدعم: <a href="mailto:ayman01aay@gmail.com">ayman01aay@gmail.com</a></p>
  <p>آخر تحديث: 21 سبتمبر 2026</p>
</body></html>`);
});

// Enhanced health check - verifies database connectivity
app.get('/api/health', async (_, res) => {
  let dbStatus = 'unknown';
  try {
    await prisma.$queryRaw`SELECT 1`;
    dbStatus = 'connected';
  } catch (err) {
    dbStatus = 'disconnected';
    logger.error('Database health check failed', { error: err.message });
  }

  res.json({
    status: dbStatus === 'connected' ? 'ok' : 'degraded',
    phase: 'limousine-shipping-platform',
    database: dbStatus,
    timestamp: new Date().toISOString(),
  });
});

// Public routes (no authentication required)
app.use('/api/auth', authLimiter, authRoutes());
app.use('/api/settings', settingsRoutes());

// Company routes (public for registration, protected for operations)
app.use('/api/company', companyRoutes());

// Order routes (limousine & shipping)
app.use('/api/orders', sensitiveLimiter, orderRoutes());
app.use('/api/maps', mapsRoutes());

// Protected routes (authentication required)
app.use('/api/trips', authMiddleware, tripRoutes());
app.use('/api/drivers', authMiddleware, driverRoutes());
app.use('/api/locations', authMiddleware, locationRoutes());
app.use('/api/payments', authMiddleware, sensitiveLimiter, paymentRoutes());
app.use('/api/notifications', authMiddleware, notificationRoutes());
app.use('/api/admin', authMiddleware, requireRole('admin', 'super_admin'), adminRoutes());
app.use('/api/customers', authMiddleware, customerRoutes());

// Set Socket.IO instance in trip service for real-time events
setSocketIO(io);

initSocketServer(io);

httpServer.listen(env.port, '0.0.0.0', () => {
  logger.info('RideFlow backend started', { 
    port: env.port, 
    host: '0.0.0.0',
    healthCheck: `http://localhost:${env.port}/api/health`
  });
});
