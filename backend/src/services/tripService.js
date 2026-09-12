import { env } from '../config/env.js';
import { calculateDistanceKm, estimateFare, getSurgeMultiplier, calculateDriverOffer } from './mapsService.js';
import { tripRepository } from '../repositories/tripRepository.js';
import { driverRepository } from '../repositories/driverRepository.js';
import { prisma } from '../db/prisma.js';
import logger from '../utils/logger.js';

// Global socket.io instance (will be set from app.js)
let io = null;

export function setSocketIO(socketIOInstance) {
  io = socketIOInstance;
}

export function emitOrderStatusChanged(data) {
  io?.emit('order_status_changed', data);
}

export const rides = new Map();

export async function getPendingRides() {
  const memoryTrips = Array.from(rides.values());
  try {
    const storedTrips = await tripRepository.listTrips();
    const byId = new Map(storedTrips.map((trip) => [trip.id, trip]));
    for (const trip of memoryTrips) byId.set(trip.id, trip);
    return Array.from(byId.values()).filter((ride) => ride.status === 'pending');
  } catch (_) {
    return memoryTrips.filter((ride) => ride.status === 'pending');
  }
}
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
    const memoryTrips = Array.from(rides.values());
    try {
      const storedTrips = await tripRepository.listTrips();
      const normalizedTrips = storedTrips.map(({ user, ...trip }) => {
        const isAccepted = ['accepted', 'driver_arriving', 'driver_arrived', 'started', 'completed'].includes(trip.status);
        const rawName = (user?.name && user.name !== 'User Dummy' && user.name !== 'a') ? user.name : (trip.userName && trip.userName !== 'User Dummy' && trip.userName !== 'a' ? trip.userName : 'أيمن');
        const rawPhone = (user?.phone && !user.phone.includes('96650000000')) ? user.phone : (trip.userPhone && !trip.userPhone.includes('96650000000') ? trip.userPhone : '01273381289');
        return {
          ...trip,
          userName: rawName,
          // Hide phone for pending trips (only visible once accepted)
          userPhone: isAccepted ? rawPhone : null,
          customerPhone: isAccepted ? rawPhone : null,
          customerImageUrl: user?.profileImage ?? null,
        };
      });
      const byId = new Map(normalizedTrips.map((trip) => [trip.id, trip]));
      for (const trip of memoryTrips) {
        const isAccepted = ['accepted', 'driver_arriving', 'driver_arrived', 'started', 'completed'].includes(trip.status);
        const existing = byId.get(trip.id);
        const rawName = (trip.userName && trip.userName !== 'User Dummy' && trip.userName !== 'a') ? trip.userName : (existing?.userName || 'أيمن');
        const rawPhone = (trip.userPhone && !trip.userPhone.includes('96650000000')) ? trip.userPhone : (existing?.userPhone || '01273381289');
        byId.set(trip.id, {
          ...(existing || {}),
          ...trip,
          userName: rawName,
          userPhone: isAccepted ? rawPhone : null,
          customerPhone: isAccepted ? rawPhone : null,
        });
      }
      return Array.from(byId.values()).sort((a, b) =>
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
      );
    } catch (error) {
      logger.warn('Using in-memory trips because Prisma storage is unavailable', { error: error.message });
      return memoryTrips;
    }
  }

  async getTripHistory() {
    return Array.from(rides.values()).filter((ride) => ride.status === 'completed' || ride.status === 'cancelled');
  }

  async getTripById(id) {
    let trip = rides.get(id);
    if (trip) {
      if ((!trip.userPhone || trip.userName === 'User Dummy') && trip.userId) {
        try {
          const user = await prisma.user.findUnique({
            where: { id: trip.userId },
            select: { name: true, phone: true, profileImage: true },
          });
          if (user) {
            if (user.phone) trip.userPhone = user.phone;
            if (user.name) trip.userName = user.name;
            if (user.profileImage) trip.customerImageUrl = user.profileImage;
          }
        } catch (_) {}
      }
    } else {
      const stored = await tripRepository.getTripById(id);
      if (!stored) return null;
      trip = {
        ...stored,
        userName: stored.user?.name ?? stored.userName ?? 'عميل زوون VIP',
        userPhone: stored.user?.phone ?? stored.userPhone ?? null,
        customerImageUrl: stored.user?.profileImage ?? null,
      };
    }

    // Enrich with driver details (photo, rating, car) if driver is assigned
    if (trip && trip.driverId) {
      try {
        const driverRecord = await prisma.driver.findFirst({
          where: {
            OR: [{ id: trip.driverId }, { userId: trip.driverId }],
          },
          include: {
            user: { select: { name: true, phone: true, profileImage: true } },
            car: true,
          },
        });
        const { driverService } = await import('./driverService.js');
        const ratingsData = await driverService.getDriverRatings(trip.driverId);
        const dImage = driverRecord?.user?.profileImage ?? trip.driverImage ?? null;
        const dRating = ratingsData?.averageRating ?? trip.driverRating ?? 5.0;
        const dTotal = ratingsData?.totalRatings ?? trip.driverTotalRatings ?? 0;

        trip.driver = {
          id: driverRecord?.id ?? trip.driverId,
          name: driverRecord?.user?.name ?? trip.driverName ?? 'كابتن زوون',
          phone: trip.status === 'pending' ? null : (driverRecord?.user?.phone ?? trip.driverPhone ?? ''),
          profileImage: dImage,
          driverImage: dImage,
          rating: dRating,
          totalRatings: dTotal,
          car: driverRecord?.car ?? null,
        };
        trip.driverName = trip.driver.name;
        trip.driverPhone = trip.driver.phone;
        trip.driverImage = dImage;
        trip.driverRating = dRating;
        trip.driverTotalRatings = dTotal;
      } catch (_) {}
    }

    return trip;
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

    let userName = payload.userName || payload.customerName || 'عميل زوون VIP';
    let userPhone = payload.userPhone || payload.customerPhone || payload.phone || null;
    let customerImageUrl = payload.customerImageUrl || payload.userImageUrl || null;

    if (userId) {
      try {
        const user = await prisma.user.findUnique({
          where: { id: userId },
          select: { name: true, phone: true, profileImage: true },
        });
        if (user) {
          if (user.name) userName = user.name;
          if (user.phone) userPhone = user.phone;
          if (user.profileImage) customerImageUrl = user.profileImage;
        }
      } catch (err) {
        logger.warn('Failed to fetch user details for trip request', { error: err.message });
      }
    }

    const ride = {
      id: tripId,
      userId: userId || env.dummyUserId,
      userName,
      userPhone,
      customerImageUrl,
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

    // Emit new trip request to connected drivers and globally (for admin/monitoring)
    if (io) {
      const tripRequestPayload = {
        id: tripId,
        rideId: tripId,
        status: 'pending',
        userName: ride.userName,
        userPhone: null, // Hidden for customer privacy until accepted
        customerImageUrl: ride.customerImageUrl,
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
      };
      io.to('drivers').emit('trip_request', tripRequestPayload);
      io.emit('trip_request', tripRequestPayload);
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
      logger.warn('Trip persisted in memory only because Prisma storage is unavailable', { error: error.message });
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
      logger.warn('Assignment persisted in memory only because Prisma storage is unavailable', { error: error.message });
    }

    return assignment;
  }

  async acceptTrip(rideId, driverId, offerAmount) {
    let ride = rides.get(rideId);
    if (!ride) {
      const storedRide = await tripRepository.getTripById(rideId);
      if (storedRide) {
        ride = {
          ...storedRide,
          userName: storedRide.user?.name ?? storedRide.userName ?? 'عميل زوون VIP',
          userPhone: storedRide.user?.phone ?? storedRide.userPhone ?? null,
          customerImageUrl: storedRide.user?.profileImage ?? null,
        };
        rides.set(rideId, ride);
      }
    }
    if (!ride) throw new Error('Ride not found');

    // If ride doesn't have customer phone yet, fetch user by userId
    if ((!ride.userPhone || ride.userName === 'User Dummy') && ride.userId) {
      try {
        const user = await prisma.user.findUnique({
          where: { id: ride.userId },
          select: { name: true, phone: true, profileImage: true },
        });
        if (user) {
          if (user.phone) ride.userPhone = user.phone;
          if (user.name) ride.userName = user.name;
          if (user.profileImage) ride.customerImageUrl = user.profileImage;
        }
      } catch (_) {}
    }

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
        userName: ride.userName,
        userPhone: ride.userPhone,
        customerName: ride.userName,
        customerPhone: ride.userPhone,
      });
    }

    try {
      await tripRepository.updateAssignment(rideId, {
        status: assignment.status,
      });
    } catch (error) {
      logger.warn('Trip assignment update skipped because Prisma storage is unavailable', { error: error.message });
    }

    return {
      ride: {
        ...ride,
        customerName: ride.userName,
        customerPhone: ride.userPhone,
      },
      assignment,
    };
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
      logger.warn('Trip start update skipped because Prisma storage is unavailable', { error: error.message });
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
    let ride = rides.get(rideId);
    if (!ride) {
      const stored = await tripRepository.getTripById(rideId);
      if (stored) {
        ride = { ...stored };
        rides.set(rideId, ride);
      }
    }
    if (!ride) throw new Error('Ride not found');

    let assignment = assignments.get(rideId);
    if (!assignment) {
      assignment = {
        id: `assignment_${Date.now()}`,
        rideRequestId: rideId,
        driverId: ride.driverId || 'driver_dummy_001',
        status: 'completed',
        completedAt: new Date().toISOString(),
      };
      assignments.set(rideId, assignment);
    }

    ride.status = 'completed';
    ride.finalFare = Number((ride.finalFare || ride.fareEstimate || 50).toFixed(2));
    ride.updatedAt = new Date().toISOString();
    assignment.status = 'completed';
    assignment.completedAt = new Date().toISOString();
    assignment.updatedAt = new Date().toISOString();

    const driver = driverAvailability.get(assignment.driverId);
    if (driver) {
      driver.isAvailable = true;
    }

    try {
      await tripRepository.updateTripStatus(rideId, 'completed', ride.driverId, ride.finalFare);
      await driverRepository.updateDriverAvailability(assignment.driverId, { isAvailable: true });
      
      // Deduct 10% commission from driver wallet
      try {
        const commission = ride.finalFare * 0.10;
        await driverRepository.updateDriverWallet(assignment.driverId, -commission);
      } catch (_) {}
    } catch (error) {
      logger.warn('Trip completion DB update skipped: ' + error.message);
    }

    if (io) {
      const completionPayload = {
        rideId,
        tripId: rideId,
        status: ride.status,
        driverId: ride.driverId,
        finalFare: ride.finalFare,
      };
      io.emit('trip_status_changed', completionPayload);
      if (ride.userId) {
        io.to(`user_${ride.userId}`).emit('trip_status_changed', completionPayload);
      }
      if (ride.driverId) {
        io.to(`driver_${ride.driverId}`).emit('trip_status_changed', completionPayload);
      }
    }

    return { ride, assignment };
  }

  async submitRating(rideId, score, comment) {
    let ride = rides.get(rideId);
    if (!ride) {
      const stored = await tripRepository.getTripById(rideId);
      if (stored) {
        ride = { ...stored };
        rides.set(rideId, ride);
      }
    }
    if (!ride) throw new Error('Ride not found');

    const parsedScore = Math.max(1, Math.min(5, parseInt(score, 10) || 5));
    const trimmedComment = comment ? String(comment).trim() : null;

    ride.rating = {
      score: parsedScore,
      comment: trimmedComment,
      createdAt: new Date().toISOString(),
    };

    ride.updatedAt = new Date().toISOString();

    // Persist rating to PostgreSQL
    try {
      let driverDbId = null;
      if (ride.driverId) {
        let driverRecord = await prisma.driver.findFirst({
          where: {
            OR: [
              { id: ride.driverId },
              { userId: ride.driverId },
            ],
          },
        });
        if (!driverRecord) {
          const userExists = await prisma.user.findUnique({ where: { id: ride.driverId } });
          if (userExists) {
            try {
              driverRecord = await prisma.driver.create({
                data: { userId: userExists.id, status: 'approved' },
              });
            } catch (_) {}
          }
        }
        if (driverRecord) {
          driverDbId = driverRecord.id;
        }
      }

      // Check if rating for this trip already exists
      const existingRating = await prisma.rating.findFirst({
        where: { tripId: ride.id },
      });

      if (existingRating) {
        await prisma.rating.update({
          where: { id: existingRating.id },
          data: {
            score: parsedScore,
            comment: trimmedComment,
            driverId: driverDbId ?? existingRating.driverId,
          },
        });
      } else if (ride.userId) {
        await prisma.rating.create({
          data: {
            tripId: ride.id,
            userId: ride.userId,
            driverId: driverDbId,
            score: parsedScore,
            comment: trimmedComment,
          },
        });
      }
      logger.info(`Persisted rating ${parsedScore} for trip ${ride.id}`);
    } catch (err) {
      logger.error(`Failed to persist rating to DB: ${err.message}`);
    }

    // Realtime notification via Socket.IO
    try {
      if (io && ride.driverId) {
        io.to(`driver_${ride.driverId}`).emit('new_rating_received', {
          tripId: ride.id,
          rating: ride.rating,
        });
        io.emit('driver_rating_updated', {
          driverId: ride.driverId,
          rating: ride.rating,
        });
      }
    } catch (_) {}

    return ride;
  }

  async submitDriverOffer(rideId, driverId, offerAmount, driverName, driverPhone, driverImageUrl, driverRating) {
    let ride = rides.get(rideId);
    if (!ride) {
      const stored = await tripRepository.getTripById(rideId);
      if (stored) {
        ride = {
          ...stored,
          offers: [],
        };
        rides.set(rideId, ride);
      }
    }
    if (!ride) throw new Error('الرحلة غير موجودة أو انتهت');
    if (ride.status !== 'pending') throw new Error('هذه الرحلة لم تعد تقبل عروض أسعار');

    // Check wallet balance
    try {
      const { driverService } = await import('./driverService.js');
      const walletInfo = await driverService.getDriverWallet(driverId);
      if (walletInfo.walletBalance <= -50) {
        throw new Error('رصيد المحفظة منخفض جداً. يرجى الشحن أولاً.');
      }
    } catch (e) {
      if (e.message && e.message.includes('رصيد المحفظة')) throw e;
    }

    if (!ride.offers) {
      ride.offers = [];
    }

    // Resolve driver profile image and rating
    let resolvedDriverName = driverName;
    let resolvedDriverPhone = driverPhone;
    let resolvedDriverImage = driverImageUrl || null;
    let resolvedRating = driverRating ? Number(driverRating) : 5.0;
    let resolvedTotalRatings = 0;

    try {
      const driverRecord = await prisma.driver.findFirst({
        where: {
          OR: [{ id: driverId }, { userId: driverId }],
        },
        include: {
          user: { select: { name: true, phone: true, profileImage: true } },
          car: true,
        },
      });

      if (driverRecord) {
        if (!resolvedDriverName || resolvedDriverName === 'كابتن زوون') {
          resolvedDriverName = driverRecord.user?.name || 'كابتن زوون';
        }
        if (!resolvedDriverPhone) {
          resolvedDriverPhone = driverRecord.user?.phone || '';
        }
        if (!resolvedDriverImage && driverRecord.user?.profileImage) {
          resolvedDriverImage = driverRecord.user.profileImage;
        }
        const { driverService } = await import('./driverService.js');
        const ratingsData = await driverService.getDriverRatings(driverRecord.id);
        resolvedRating = ratingsData.averageRating ?? 5.0;
        resolvedTotalRatings = ratingsData.totalRatings ?? 0;
      } else {
        const userRecord = await prisma.user.findUnique({
          where: { id: driverId },
          select: { name: true, phone: true, profileImage: true },
        });
        if (userRecord) {
          if (!resolvedDriverName || resolvedDriverName === 'كابتن زوون') {
            resolvedDriverName = userRecord.name || 'كابتن زوون';
          }
          if (!resolvedDriverPhone) {
            resolvedDriverPhone = userRecord.phone || '';
          }
          if (!resolvedDriverImage && userRecord.profileImage) {
            resolvedDriverImage = userRecord.profileImage;
          }
          const { driverService } = await import('./driverService.js');
          const ratingsData = await driverService.getDriverRatings(driverId);
          resolvedRating = ratingsData.averageRating ?? 5.0;
          resolvedTotalRatings = ratingsData.totalRatings ?? 0;
        }
      }
    } catch (_) {}

    // Check if driver already sent an offer - if so, update it instead of failing
    const existingIndex = ride.offers.findIndex(o => o.driverId === driverId);
    let offer;
    if (existingIndex !== -1) {
      ride.offers[existingIndex].offerAmount = offerAmount;
      ride.offers[existingIndex].timestamp = new Date().toISOString();
      if (resolvedDriverName) ride.offers[existingIndex].driverName = resolvedDriverName;
      if (resolvedDriverPhone) ride.offers[existingIndex].driverPhone = resolvedDriverPhone;
      if (resolvedDriverImage) ride.offers[existingIndex].driverImage = resolvedDriverImage;
      ride.offers[existingIndex].rating = resolvedRating;
      ride.offers[existingIndex].totalRatings = resolvedTotalRatings;
      offer = ride.offers[existingIndex];
    } else {
      offer = {
        driverId,
        driverName: resolvedDriverName || 'كابتن زوون',
        driverPhone: resolvedDriverPhone || '',
        driverImage: resolvedDriverImage,
        rating: resolvedRating,
        totalRatings: resolvedTotalRatings,
        offerAmount,
        status: 'pending',
        timestamp: new Date().toISOString(),
      };
      ride.offers.push(offer);
    }

    ride.updatedAt = new Date().toISOString();

    // Emit offer to customer via socket across all channels
    if (io) {
      const offerPayload = {
        rideId,
        tripId: rideId,
        orderId: rideId,
        driverId,
        driverName: offer.driverName,
        driverPhone: offer.driverPhone,
        driverImage: offer.driverImage,
        rating: offer.rating,
        totalRatings: offer.totalRatings,
        offerAmount: offer.offerAmount,
        price: offer.offerAmount,
        offersCount: ride.offers.length,
        timestamp: offer.timestamp,
        status: 'pending',
      };

      io.emit('driver_offer', offerPayload);
      if (ride.userId) {
        io.to(`user_${ride.userId}`).emit('driver_offer', offerPayload);
      }
      io.to(`trip_${rideId}`).emit('driver_offer', offerPayload);
      io.to(rideId).emit('driver_offer', offerPayload);
    }

    return { ride, offer };
  }

  // Get all offers for a specific trip (for customer to see)
  async getTripOffers(rideId) {
    let ride = rides.get(rideId);
    if (!ride) {
      const stored = await tripRepository.getTripById(rideId);
      if (stored) {
        ride = { ...stored, offers: [] };
        rides.set(rideId, ride);
      }
    }
    return ride ? (ride.offers || []) : [];
  }

  // Customer accepts a specific driver's offer
  async acceptDriverOffer(rideId, driverId) {
    let ride = rides.get(rideId);
    if (!ride) {
      const stored = await tripRepository.getTripById(rideId);
      if (stored) {
        ride = { ...stored, offers: [] };
        rides.set(rideId, ride);
      }
    }
    if (!ride) throw new Error('Ride not found');
    if (ride.status !== 'pending') throw new Error('This ride is no longer pending');

    const offer = (ride.offers || []).find(o => o.driverId === driverId);
    if (!offer) throw new Error('Offer not found from this driver');

    // Accept this offer, reject all others
    ride.offers.forEach(o => {
      o.status = o.driverId === driverId ? 'accepted' : 'rejected';
    });

    ride.status = 'accepted';
    ride.driverId = driverId;
    ride.driverName = offer.driverName;
    ride.driverPhone = offer.driverPhone;
    ride.driverImage = offer.driverImage;
    ride.driverRating = offer.rating;
    ride.driverTotalRatings = offer.totalRatings;
    ride.driver = {
      id: driverId,
      name: offer.driverName,
      phone: offer.driverPhone,
      profileImage: offer.driverImage,
      driverImage: offer.driverImage,
      rating: offer.rating,
      totalRatings: offer.totalRatings,
    };
    ride.finalFare = offer.offerAmount;
    ride.fareEstimate = offer.offerAmount;
    ride.updatedAt = new Date().toISOString();

    // Also persist status update in PostgreSQL
    try {
      await tripRepository.updateTripStatus(rideId, 'accepted', driverId);
    } catch (_) {}

    // Resolve real customer phone and name for driver
    if ((!ride.userPhone || ride.userName === 'User Dummy') && ride.userId) {
      try {
        const user = await prisma.user.findUnique({
          where: { id: ride.userId },
          select: { name: true, phone: true, profileImage: true },
        });
        if (user) {
          if (user.phone) ride.userPhone = user.phone;
          if (user.name) ride.userName = user.name;
          if (user.profileImage) ride.customerImageUrl = user.profileImage;
        }
      } catch (_) {}
    }

    // Create assignment
    const assignment = {
      id: `assignment_${Date.now()}`,
      rideRequestId: rideId,
      driverId: driverId,
      status: 'accepted',
      acceptedAt: new Date().toISOString(),
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    assignments.set(rideId, assignment);

    // Notify the accepted driver
    if (io) {
      const offerAcceptedPayload = {
        rideId,
        tripId: rideId,
        status: 'accepted',
        driverId,
        customerName: ride.userName,
        customerPhone: ride.userPhone,
        pickupAddress: ride.pickupAddress,
        pickupLat: ride.pickupLat,
        pickupLng: ride.pickupLng,
        dropoffAddress: ride.dropoffAddress,
        dropoffLat: ride.dropoffLat,
        dropoffLng: ride.dropoffLng,
        fareAmount: offer.offerAmount,
      };
      io.to(`driver:${driverId}`).emit('offer_accepted', offerAcceptedPayload);
      io.emit('offer_accepted', offerAcceptedPayload);

      // Notify ALL clients that this trip is taken
      io.emit('trip_status_changed', {
        rideId,
        tripId: rideId,
        status: 'accepted',
        driverId,
        customerName: ride.userName,
        customerPhone: ride.userPhone,
        userName: ride.userName,
        userPhone: ride.userPhone,
        driverName: offer.driverName,
        driverPhone: offer.driverPhone,
        driverImage: offer.driverImage,
        driverRating: offer.rating,
        driverTotalRatings: offer.totalRatings,
      });
    }

    return { ride, assignment, acceptedOffer: offer };
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
