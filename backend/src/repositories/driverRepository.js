import { prisma } from '../db/prisma.js';

class DriverRepository {
  async listDrivers() {
    return prisma.driver.findMany({ orderBy: { createdAt: 'desc' } });
  }

  /** Accepts Driver.id or User.id (the app JWT is always the user id). */
  async getDriverById(id, extraIds = []) {
    const ids = [...new Set([id, ...extraIds].filter(Boolean))];
    if (ids.length === 0) return null;
    return prisma.driver.findFirst({
      where: {
        OR: ids.flatMap((value) => [{ id: value }, { userId: value }]),
      },
    });
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
    const driver = await this.getDriverById(driverId);
    if (!driver) throw new Error('Driver not found');
    const updated = await prisma.driver.update({
      where: { id: driver.id },
      data: {
        walletBalance: { increment: amount },
      },
    });
    if (updated.userId) {
      await prisma.user.update({
        where: { id: updated.userId },
        data: { walletBalance: updated.walletBalance },
      }).catch(() => {});
    }
    return updated;
  }
}

export const driverRepository = new DriverRepository();
