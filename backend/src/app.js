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
import { authMiddleware } from './middlewares/authMiddleware.js';

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
  },
});

app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use((req, res, next) => { console.log('[REQ] ' + req.method + ' ' + req.url, req.body); next(); });

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
  <p>آخر تحديث: 10 سبتمبر 2026</p>
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
    console.error('[Health] Database check failed:', err.message);
  }

  res.json({
    status: dbStatus === 'connected' ? 'ok' : 'degraded',
    phase: 'limousine-shipping-platform',
    database: dbStatus,
    timestamp: new Date().toISOString(),
  });
});

// Public routes (no authentication required)
app.use('/api/auth', authRoutes());
app.use('/api/settings', settingsRoutes());

// Company routes (public for registration, protected for operations)
app.use('/api/company', companyRoutes());

// Order routes (limousine & shipping)
app.use('/api/orders', orderRoutes());
app.use('/api/maps', mapsRoutes());

// Protected routes (authentication required)
app.use('/api/trips', authMiddleware, tripRoutes());
app.use('/api/drivers', authMiddleware, driverRoutes());
app.use('/api/locations', authMiddleware, locationRoutes());
app.use('/api/payments', authMiddleware, paymentRoutes());
app.use('/api/notifications', authMiddleware, notificationRoutes());
app.use('/api/admin', authMiddleware, adminRoutes());
app.use('/api/customers', authMiddleware, customerRoutes());

// Set Socket.IO instance in trip service for real-time events
setSocketIO(io);

initSocketServer(io);

httpServer.listen(env.port, '0.0.0.0', () => {
  console.log(`RideFlow backend running on port ${env.port} and listening on all interfaces`);
  console.log(`Health check: http://localhost:${env.port}/api/health`);
});
