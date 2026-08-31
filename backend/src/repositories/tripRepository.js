import { prisma } from '../db/prisma.js';

class TripRepository {
  async createTrip(data) {
    return prisma.trip.create({ data });
  }

  async listTrips() {
    return prisma.trip.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async listTripsByDriver(driverId) {
    return prisma.trip.findMany({
      where: { driverId },
      include: { user: { select: { name: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getTripById(id) {
    return prisma.trip.findUnique({ where: { id } });
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
}

export const tripRepository = new TripRepository();
