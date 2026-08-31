import { env } from '../config/env.js';
import { calculateDistanceKm, estimateFare, getSurgeMultiplier, calculateDriverOffer } from './mapsService.js';
import { tripRepository } from '../repositories/tripRepository.js';
import { driverRepository } from '../repositories/driverRepository.js';

// Global socket.io instance (will be set from app.js)
let io = null;

export function setSocketIO(socketIOInstance) {
  io = socketIOInstance;
}

export const rides = new Map();
const assignments = new Map();
const driverAvailability = new Map([
  ['driver_dummy_001', { id: 'driver_dummy_001', isAvailable: true, lat: 24.7136, lng: 46.6753 }],
  ['driver_dummy_002', { id: 'driver_dummy_002', isAvailable: true, lat: 24.7517, lng: 46.7161 }],
]);

function makeRideId() {
  return `ride_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
}

class TripService {
  async listTrips() {
    return Array.from(rides.values());
  }

  async getTripHistory() {
    return Array.from(rides.values()).filter((ride) => ride.status === 'completed' || ride.status === 'cancelled');
  }

  async getTripById(id) {
    return rides.get(id) ?? (await tripRepository.getTripById(id));
  }

  async createTripRequest(payload) {
    const { pickupAddress, dropoffAddress, pickupLat, pickupLng, dropoffLat, dropoffLng, userId, proposedFare, areaType, vehicleType, tripType, notes } = payload;
    if (!pickupAddress || !dropoffAddress) {
      throw new Error('pickupAddress and dropoffAddress are required');
    }

    const distanceKm = calculateDistanceKm({ pickupLat, pickupLng, dropoffLat, dropoffLng });
    
    // Calculate surge pricing based on current time
    const now = new Date();
    const hour = now.getHours();
    const dayOfWeek = now.getDay();
    const surgeMultiplier = getSurgeMultiplier(hour, dayOfWeek);
    
    const calculatedFare = estimateFare(distanceKm, surgeMultiplier);
    const fareEstimate = proposedFare ? parseFloat(proposedFare) : calculatedFare;
    const tripId = makeRideId();

    const ride = {
      id: tripId,
      userId: userId || env.dummyUserId,
      userName: 'User Dummy',
      userPhone: '+966500000001',
      pickupAddress,
      dropoffAddress,
      pickupLat,
      pickupLng,
      dropoffLat,
      dropoffLng,
      areaType,
      vehicleType,
      tripType,
      notes,
      status: 'pending',
      fareEstimate,
      finalFare: fareEstimate,
      distanceKm,
      durationMinutes: 10,
      remainingDistanceKm: distanceKm,
      remainingMinutes: 10,
      driverName: 'Driver Dummy',
      driverPhone: '+966500000000',
      driverId: 'driver_dummy_001',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    rides.set(tripId, ride);

    // Emit new trip request to all drivers via socket
    if (io) {
      io.emit('trip_request', {
        id: tripId,
        rideId: tripId,
        userName: ride.userName,
        pickupAddress,
        dropoffAddress,
        pickupLat,
        pickupLng,
        dropoffLat,
        dropoffLng,
        distanceKm,
        fareEstimate,
        areaType: ride.areaType,
        vehicleType: ride.vehicleType,
        tripType: ride.tripType,
        notes: ride.notes,
      });
    }

    try {
      await tripRepository.createTrip({
        id: ride.id,
        userId: ride.userId,
        pickupAddress: ride.pickupAddress,
        dropoffAddress: ride.dropoffAddress,
        pickupLat: ride.pickupLat,
        pickupLng: ride.pickupLng,
        dropoffLat: ride.dropoffLat,
        dropoffLng: ride.dropoffLng,
        status: ride.status,
        fareEstimate: ride.fareEstimate,
        distanceKm: ride.distanceKm,
        finalFare: ride.finalFare,
      });
    } catch (error) {
      console.warn('Trip persisted in memory only because Prisma storage is unavailable:', error.message);
    }

    return ride;
  }

  async assignDriver(rideId) {
    const ride = rides.get(rideId);
    if (!ride) throw new Error('Ride not found');

    const availableDriver = Array.from(driverAvailability.values()).find((driver) => driver.isAvailable);
    if (!availableDriver) throw new Error('No driver available');

    const assignment = {
      id: `assignment_${Date.now()}`,
      rideRequestId: rideId,
      driverId: availableDriver.id,
      status: 'pending',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    assignments.set(rideId, assignment);
    availableDriver.isAvailable = false;
    ride.driverId = availableDriver.id;
    ride.driverName = 'Driver Dummy';
    ride.driverPhone = '+966500000000';
    ride.status = 'accepted';
    ride.updatedAt = new Date().toISOString();

    try {
      await tripRepository.createAssignment({
        id: assignment.id,
        rideRequestId: assignment.rideRequestId,
        driverId: assignment.driverId,
        status: assignment.status,
      });
    } catch (error) {
      console.warn('Assignment persisted in memory only because Prisma storage is unavailable:', error.message);
    }

    return assignment;
  }

  async acceptTrip(rideId, driverId, offerAmount) {
    const ride = rides.get(rideId);
    if (!ride) throw new Error('Ride not found');

    const acceptedDriverId = driverId || 'driver_dummy_001';

    // Create assignment if it doesn't exist
    let assignment = assignments.get(rideId);
    if (!assignment) {
      assignment = {
        id: `assignment_${Date.now()}`,
        rideRequestId: rideId,
        driverId: acceptedDriverId,
        status: 'accepted',
        acceptedAt: new Date().toISOString(),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      assignments.set(rideId, assignment);
    } else {
      assignment.status = 'accepted';
      assignment.driverId = acceptedDriverId;
      assignment.acceptedAt = new Date().toISOString();
      assignment.updatedAt = new Date().toISOString();
    }

    ride.status = 'accepted';
    ride.driverId = assignment.driverId;
    if (offerAmount) {
      ride.fareEstimate = offerAmount;
      ride.finalFare = offerAmount;
    }
    ride.updatedAt = new Date().toISOString();

    // Emit trip status update via socket so driver and customer know it's accepted
    if (io) {
      io.emit('trip_status_changed', {
        rideId,
        status: 'accepted',
        driverId: ride.driverId,
      });
    }

    try {
      await tripRepository.updateAssignment(rideId, {
        status: assignment.status,
      });
    } catch (error) {
      console.warn('Trip assignment update skipped because Prisma storage is unavailable:', error.message);
    }

    return { ride, assignment };
  }

  async rejectTrip(rideId, driverId) {
    const ride = rides.get(rideId);
    if (!ride) throw new Error('Ride not found');
    if (ride.status !== 'pending') throw new Error('Only pending rides can be rejected');

    ride.status = 'cancelled';
    ride.rejectedBy = driverId || 'driver_dummy_001';
    ride.updatedAt = new Date().toISOString();

    if (io) {
      io.emit('trip_status_changed', {
        rideId,
        status: 'cancelled',
        driverId: ride.rejectedBy,
      });
    }

    return ride;
  }

  async updateTripStatus(rideId, status) {
    const ride = rides.get(rideId);
    if (!ride) throw new Error('Ride not found');

    const statusMap = {
      pending: 'pending',
      accepted: 'accepted',
      driver_arriving: 'driver_arriving',
      driver_arrived: 'driver_arrived',
      start: 'started',
      started: 'started',
      complete: 'completed',
      completed: 'completed',
      cancelled: 'cancelled',
    };

    const normalizedStatus = statusMap[status] ?? status;

    if (normalizedStatus === 'started') {
      try { return await this.startTrip(rideId); } catch(e) {}
    }
    if (normalizedStatus === 'completed') {
      try { return await this.completeTrip(rideId); } catch(e) {}
    }

    ride.status = normalizedStatus;
    ride.updatedAt = new Date().toISOString();

    // Emit trip status update via socket to ALL connected clients
    if (io) {
      io.emit('trip_status_changed', {
        rideId,
        status: normalizedStatus,
        driverId: ride.driverId,
      });
    }

    if (normalizedStatus === 'started') {
      ride.remainingDistanceKm = Math.max(ride.remainingDistanceKm - 1.5, 0);
      ride.remainingMinutes = Math.max(ride.remainingMinutes - 2, 0);
    }

    if (normalizedStatus === 'completed') {
      ride.finalFare = Number((ride.fareEstimate + 5).toFixed(2));
    }

    return ride;
  }

  async startTrip(rideId) {
    const ride = rides.get(rideId);
    const assignment = assignments.get(rideId);
    if (!ride || !assignment) throw new Error('Ride or assignment not found');

    ride.status = 'started';
    ride.updatedAt = new Date().toISOString();
    assignment.status = 'in_progress';
    assignment.startedAt = new Date().toISOString();
    assignment.updatedAt = new Date().toISOString();

    try {
      await tripRepository.updateAssignment(rideId, {
        status: assignment.status,
        startedAt: new Date(assignment.startedAt),
      });
    } catch (error) {
      console.warn('Trip start update skipped because Prisma storage is unavailable:', error.message);
    }

    if (io) {
      io.emit('trip_status_changed', {
        rideId,
        status: ride.status,
        driverId: ride.driverId,
      });
    }

    return { ride, assignment };
  }

  async cancelTrip(rideId) {
    const ride = rides.get(rideId);
    if (!ride) throw new Error('Ride not found');

    if (ride.status === 'started' || ride.status === 'completed') {
      throw new Error('This trip cannot be cancelled after it has started.');
    }

    ride.status = 'cancelled';
    ride.updatedAt = new Date().toISOString();
    return ride;
  }

  async completeTrip(rideId) {
    const ride = rides.get(rideId);
    const assignment = assignments.get(rideId);
    if (!ride || !assignment) throw new Error('Ride or assignment not found');

    ride.status = 'completed';
    ride.finalFare = Number((ride.fareEstimate + 5).toFixed(2));
    ride.updatedAt = new Date().toISOString();
    assignment.status = 'completed';
    assignment.completedAt = new Date().toISOString();
    assignment.updatedAt = new Date().toISOString();

    const driver = driverAvailability.get(assignment.driverId);
    if (driver) {
      driver.isAvailable = true;
    }

    try {
      await tripRepository.updateAssignment(rideId, {
        status: assignment.status,
        completedAt: new Date(assignment.completedAt),
      });

      await driverRepository.updateDriverAvailability(assignment.driverId, { isAvailable: true });
      
      // Deduct 10% commission from driver wallet
      const commission = ride.finalFare * 0.10;
      await driverRepository.updateDriverWallet(assignment.driverId, -commission);
    } catch (error) {
      console.warn('Trip completion update skipped because Prisma storage is unavailable:', error.message);
    }

    if (io) {
      io.emit('trip_status_changed', {
        rideId,
        status: ride.status,
        driverId: ride.driverId,
      });
    }

    return { ride, assignment };
  }

  async submitRating(rideId, score, comment) {
    const ride = rides.get(rideId);
    if (!ride) throw new Error('Ride not found');

    ride.rating = {
      score,
      comment,
      createdAt: new Date().toISOString(),
    };

    ride.updatedAt = new Date().toISOString();
    return ride;
  }

  async submitDriverOffer(rideId, driverId, offerAmount) {
    const ride = rides.get(rideId);
    if (!ride) throw new Error('Ride not found');
    
    // Check wallet
    try {
      const { driverService } = await import('./driverService.js');
      const walletInfo = await driverService.getDriverWallet(driverId);
      if (walletInfo.walletBalance <= -50) {
        throw new Error('Wallet balance too low. Please recharge.');
      }
    } catch (e) {
      if (e.message.includes('Wallet balance too low')) throw e;
    }

    // Store driver offer
    if (!ride.offers) {
      ride.offers = [];
    }

    const offer = {
      driverId,
      offerAmount,
      timestamp: new Date().toISOString(),
    };

    ride.offers.push(offer);
    ride.updatedAt = new Date().toISOString();

    // Emit offer to customer via socket
    if (io) {
      io.emit('driver_offer', {
        rideId,
        driverId,
        offerAmount,
        timestamp: offer.timestamp,
      });
    }

    return { ride, offer };
  }

  // ── Admin Stats ──────────────────────────────────────────────
  getTripStats() {
    const allRides = Array.from(rides.values());

    // Driver earnings: sum finalFare of completed trips per driver
    const driverEarnings = {};
    allRides
      .filter((r) => r.status === 'completed')
      .forEach((r) => {
        const dId = r.driverId || 'unknown';
        if (!driverEarnings[dId]) {
          driverEarnings[dId] = { driverId: dId, driverName: r.driverName || dId, totalEarnings: 0, completedTrips: 0 };
        }
        driverEarnings[dId].totalEarnings += r.finalFare || r.fareEstimate || 0;
        driverEarnings[dId].completedTrips += 1;
      });

    // Customer order counts
    const customerOrders = {};
    allRides.forEach((r) => {
      const uId = r.userId || 'unknown';
      if (!customerOrders[uId]) {
        customerOrders[uId] = { userId: uId, userName: r.userName || uId, totalOrders: 0, totalSpent: 0 };
      }
      customerOrders[uId].totalOrders += 1;
      if (r.status === 'completed') {
        customerOrders[uId].totalSpent += r.finalFare || r.fareEstimate || 0;
      }
    });

    // Unique customers who ordered
    const customersWhoOrdered = Object.keys(customerOrders).length;

    return {
      totalTrips: allRides.length,
      pendingTrips: allRides.filter((r) => r.status === 'pending').length,
      activeTrips: allRides.filter((r) => !['pending', 'completed', 'cancelled'].includes(r.status)).length,
      completedTrips: allRides.filter((r) => r.status === 'completed').length,
      cancelledTrips: allRides.filter((r) => r.status === 'cancelled').length,
      customersWhoOrdered,
      driverEarnings: Object.values(driverEarnings),
      customerOrders: Object.values(customerOrders),
    };
  }
}

export const tripService = new TripService();
