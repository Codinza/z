import { prisma } from '../db/prisma.js';

class TripRepository {
  async createTrip(data) {
    return prisma.trip.create({ data });
  }

  async listTrips() {
    return prisma.trip.findMany({
      include: { user: { select: { name: true, profileImage: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async listTripsByDriver(driverId) {
    return prisma.trip.findMany({
      where: {
        OR: [
          { driverId },
          { driver: { userId: driverId } },
        ],
      },
      include: {
        user: { select: { name: true, phone: true } },
        ratings: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getTripById(id) {
    return prisma.trip.findUnique({
      where: { id },
      include: { user: { select: { name: true, profileImage: true, phone: true } } },
    });
  }

  async createAssignment(data) {
    return prisma.trip.update({
      where: { id: data.rideRequestId },
      data: {
        driverId: data.driverId,
        status: data.status,
      },
    });
  }

  async getAssignmentByTripId(rideRequestId) {
    return prisma.trip.findUnique({ where: { id: rideRequestId } });
  }

  async updateAssignment(rideRequestId, data) {
    return prisma.trip.update({
      where: { id: rideRequestId },
      data,
    });
  }

  async updateTripStatus(id, status, driverId = null, finalFare = null) {
    const data = { status };
    if (driverId) data.driverId = driverId;
    if (finalFare !== null && finalFare !== undefined) data.finalFare = Number(finalFare);

    return prisma.trip.update({
      where: { id },
      data,
    });
  }
}

export const tripRepository = new TripRepository();
