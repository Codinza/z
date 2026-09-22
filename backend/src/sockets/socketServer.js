// Track online drivers
import { getPendingRides } from '../services/tripService.js';
import { locationService } from '../services/locationService.js';
import logger from '../utils/logger.js';

const onlineDrivers = new Map(); // socketId -> driverId
let socketIo = null;

export function getOnlineDriversCount() {
  return onlineDrivers.size;
}

export function getOnlineDriversList() {
  return Array.from(onlineDrivers.values());
}

/** Push wallet balance changes to a driver's connected apps. */
export function emitDriverWalletUpdated({ driverId, userId, walletBalance }) {
  if (!socketIo) return;
  const payload = {
    driverId,
    userId,
    walletBalance,
    timestamp: new Date().toISOString(),
  };
  if (driverId) socketIo.to(`driver:${driverId}`).emit('wallet_updated', payload);
  if (userId && userId !== driverId) {
    socketIo.to(`driver:${userId}`).emit('wallet_updated', payload);
  }
}

export function initSocketServer(io) {
  socketIo = io;
  io.on('connection', (socket) => {
    logger.info('Socket connected', { socketId: socket.id });

    socket.on('driver:ready', async (payload) => {
      const driverId =
        typeof payload === 'string' ? payload : payload?.driverId;
      const vehicleCategory =
        typeof payload === 'object' && payload?.vehicleCategory === 'motorcycle'
          ? 'motorcycle'
          : 'car';

      if (!driverId) return;

      socket.join(`driver:${driverId}`);
      socket.join('drivers');
      socket.data.vehicleCategory = vehicleCategory;
      // Track this driver as online
      onlineDrivers.set(socket.id, driverId);

      try {
        const { prisma } = await import('../db/prisma.js');
        const driver = await prisma.driver.findFirst({
          where: { OR: [{ id: driverId }, { userId: driverId }] },
          select: { id: true, userId: true },
        });
        if (driver?.id) socket.join(`driver:${driver.id}`);
        if (driver?.userId && driver.userId !== driverId) {
          socket.join(`driver:${driver.userId}`);
        }
      } catch (_) {}
      logger.info('Driver is now online', {
        driverId,
        vehicleCategory,
        onlineCount: onlineDrivers.size,
      });
      io.emit('driver:status', { driverId, ready: true, onlineCount: onlineDrivers.size });
      // Sync only pending rides that match this driver's vehicle category
      const pendingRides = await getPendingRides();
      const matching = pendingRides.filter((ride) => {
        const rideType =
          String(ride.vehicleType || '').toLowerCase() === 'motorcycle'
            ? 'motorcycle'
            : 'car';
        return rideType === vehicleCategory;
      });
      socket.emit('pending_rides_sync', matching);
    });

    socket.on('admin:ready', async () => {
      socket.join('admins');
      logger.info('Admin socket joined admins room', { socketId: socket.id });
      try {
        const pendingRides = await getPendingRides();
        socket.emit('pending_rides_sync', pendingRides);
      } catch (error) {
        logger.warn('Failed to sync pending rides to admin', {
          error: error.message,
        });
      }
    });

    socket.on('driver_location_update', async (data) => {
      const { driverId, lat, lng, rideId, orderId } = data || {};
      if (driverId != null && lat != null && lng != null) {
        try {
          await locationService.updateDriverLocation(driverId, { lat, lng });
        } catch (error) {
          logger.warn('Failed to persist driver socket location', { error: error.message });
        }
      }
      if (driverId != null) socket.join(`driver:${driverId}`);
      if (rideId || orderId) {
        io.to(`ride:${rideId || orderId}`).emit('location_update', {
          driverId,
          lat,
          lng,
          rideId: rideId || orderId,
          orderId: orderId || rideId,
          timestamp: new Date().toISOString(),
        });
      }
      
    });

    socket.on('customer:track_trip', (rideId) => {
      socket.join(`ride:${rideId}`);
      socket.emit('customer:tracking_ready', { rideId });
    });

    socket.on('trip:status_update', (data) => {
      const { rideId, status, driverId } = data;
      
      // Notify all parties tracking this ride
      io.to(`ride:${rideId}`).emit('trip_status_changed', {
        rideId,
        status,
        driverId,
        timestamp: new Date().toISOString(),
      });

      // Also notify specific driver if provided
      if (driverId) {
        io.to(`driver:${driverId}`).emit('trip_status_changed', {
          rideId,
          status,
          timestamp: new Date().toISOString(),
        });
      }
    });

    socket.on('new_trip_request', (data) => {
      const { rideId, pickupLat, pickupLng, dropoffLat, dropoffLng, fareEstimate } = data;
      
      // Broadcast only to connected drivers
      io.to('drivers').emit('trip_request', {
        rideId,
        status: 'pending',
        pickupLat,
        pickupLng,
        dropoffLat,
        dropoffLng,
        fareEstimate,
        timestamp: new Date().toISOString(),
      });
    });

    socket.on('driver:accept_trip', (data) => {
      const { rideId, driverId } = data;
      
      // Notify customer that driver accepted
      io.to(`ride:${rideId}`).emit('driver_accepted', {
        rideId,
        driverId,
        timestamp: new Date().toISOString(),
      });
    });

    socket.on('disconnect', () => {
      const driverId = onlineDrivers.get(socket.id);
      if (driverId) {
        onlineDrivers.delete(socket.id);
        logger.info('Driver went offline', { driverId, onlineCount: onlineDrivers.size });
        io.emit('driver:status', { driverId, ready: false, onlineCount: onlineDrivers.size });
      }
      logger.info('Socket disconnected', { socketId: socket.id });
    });
  });
}
