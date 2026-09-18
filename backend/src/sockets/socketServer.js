// Track online drivers
import { getPendingRides } from '../services/tripService.js';
import { locationService } from '../services/locationService.js';
import logger from '../utils/logger.js';

const onlineDrivers = new Map(); // socketId -> driverId

export function getOnlineDriversCount() {
  return onlineDrivers.size;
}

export function getOnlineDriversList() {
  return Array.from(onlineDrivers.values());
}

export function initSocketServer(io) {
  io.on('connection', (socket) => {
    logger.info('Socket connected', { socketId: socket.id });

    socket.on('driver:ready', async (driverId) => {
      socket.join(`driver:${driverId}`);
      socket.join('drivers');
      // Track this driver as online
      onlineDrivers.set(socket.id, driverId);
      logger.info('Driver is now online', { driverId, onlineCount: onlineDrivers.size });
      io.emit('driver:status', { driverId, ready: true, onlineCount: onlineDrivers.size });
      // Sync pending rides as a batch without triggering individual trip_request alert storms
      const pendingRides = await getPendingRides();
      socket.emit('pending_rides_sync', pendingRides);
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
