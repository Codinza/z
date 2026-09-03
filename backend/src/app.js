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
