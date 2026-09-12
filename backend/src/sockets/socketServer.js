// Track online drivers
import { getPendingRides } from '../services/tripService.js';
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
      const pendingRides = await getPendingRides();
      for (const ride of pendingRides) {
        socket.emit('trip_request', {
          ...ride,
          rideId: ride.id,
          status: ride.status || 'pending',
        });
      }
    });

    socket.on('driver_location_update', (data) => {
      // Broadcast location to all clients (for demo simplicity, real app would use rooms)
      io.emit('driver_location_update', data);
    });

    socket.on('driver:location_update', (data) => {
      const { driverId, lat, lng, rideId } = data;
      socket.join(`driver:${driverId}`);
      
      // Broadcast location to customers tracking this ride
      if (rideId) {
        io.to(`ride:${rideId}`).emit('location_update', {
          driverId,
          lat,
          lng,
          rideId,
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
