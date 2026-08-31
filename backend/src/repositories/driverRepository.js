import { prisma } from '../db/prisma.js';

class DriverRepository {
  async listDrivers() {
    return prisma.driver.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async getDriverById(id) {
    return prisma.driver.findUnique({ where: { id } });
  }

  async updateDriverAvailability(driverId, data) {
    return prisma.driver.update({
      where: { id: driverId },
      data: {
        isActive: data.isAvailable ?? data.isActive ?? true,
      },
    });
  }

  async updateDriverWallet(driverId, amount) {
    return prisma.driver.update({
      where: { id: driverId },
      data: {
        walletBalance: { increment: amount },
      },
    });
  }
}

export const driverRepository = new DriverRepository();
