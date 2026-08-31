import { config } from '../config.js';
import { calculateDistanceKm, estimateFare } from './mapsService.js';

const rides = new Map();
const assignments = new Map();
const driverAvailability = new Map([
  ['driver_dummy_001', { id: 'driver_dummy_001', isAvailable: true, lat: 24.7136, lng: 46.6753 }],
  ['driver_dummy_002', { id: 'driver_dummy_002', isAvailable: true, lat: 24.7517, lng: 46.7161 }],
]);

function makeRideId() {
  return `ride_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
}

export function listRides() {
  return Array.from(rides.values()).map((ride) => ({
    ...ride,
    assignment: assignments.get(ride.id) || null,
  }));
}

export function getRideById(id) {
  const ride = rides.get(id);
  if (!ride) return null;
  return { ...ride, assignment: assignments.get(id) || null };
}

export function createRideRequest(payload, io) {
  const { pickupAddress, dropoffAddress, pickupLat, pickupLng, dropoffLat, dropoffLng } = payload;

  if (!pickupAddress || !dropoffAddress) {
    throw new Error('pickupAddress and dropoffAddress are required');
  }

  const distanceKm = calculateDistanceKm({ pickupLat, pickupLng, dropoffLat, dropoffLng });
  const fareEstimate = estimateFare(distanceKm);
  const rideId = makeRideId();

  const ride = {
    id: rideId,
    userId: config.dummyUserId,
    pickupAddress,
    dropoffAddress,
    pickupLat,
    pickupLng,
    dropoffLat,
    dropoffLng,
    status: 'requested',
    fareEstimate,
    distanceKm,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  rides.set(rideId, ride);
  io.emit('ride.requested', { ride });

  return ride;
}

export function assignDriverToRide(rideId, io) {
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
  io.emit('ride.assigned', { ride, assignment });
  return assignment;
}

export function acceptRide(rideId, io) {
  const ride = rides.get(rideId);
  const assignment = assignments.get(rideId);
  if (!ride || !assignment) throw new Error('Ride or assignment not found');

  assignment.status = 'accepted';
  assignment.acceptedAt = new Date().toISOString();
  assignment.updatedAt = new Date().toISOString();
  ride.status = 'driver_accepted';
  ride.updatedAt = new Date().toISOString();

  io.emit('ride.accepted', { ride, assignment });
  return { ride, assignment };
}

export function startRide(rideId, io) {
  const ride = rides.get(rideId);
  const assignment = assignments.get(rideId);
  if (!ride || !assignment) throw new Error('Ride or assignment not found');

  ride.status = 'in_progress';
  ride.updatedAt = new Date().toISOString();
  assignment.status = 'in_progress';
  assignment.startedAt = new Date().toISOString();
  assignment.updatedAt = new Date().toISOString();

  io.emit('ride.started', { ride, assignment });
  return { ride, assignment };
}

export function completeRide(rideId, io) {
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

  io.emit('ride.completed', { ride, assignment });
  return { ride, assignment };
}
