import { prisma } from '../db/prisma.js';

class LocationRepository {
  async findDriverLocation(driverId) {
    return prisma.driverLocation.findFirst({
      where: { driverId },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async updateDriverLocation(driverId, data) {
    const latestLocation = await prisma.driverLocation.findFirst({
      where: { driverId },
      orderBy: { updatedAt: 'desc' },
    });

    if (latestLocation) {
      return prisma.driverLocation.update({
        where: { id: latestLocation.id },
        data,
      });
    }

    return prisma.driverLocation.create({
      data: {
        driverId,
        ...data,
      },
    });
  }

  async listLocations() {
    return prisma.driverLocation.findMany({ orderBy: { updatedAt: 'desc' } });
  }
}

export const locationRepository = new LocationRepository();
