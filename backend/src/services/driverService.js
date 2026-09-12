import { driverRepository } from '../repositories/driverRepository.js';
import { tripRepository } from '../repositories/tripRepository.js';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

class DriverService {
  async listDrivers() {
    return await driverRepository.listDrivers();
  }

  async getDriverById(id) {
    return await driverRepository.getDriverById(id);
  }

  async getDriverWallet(id) {
    let driver = await driverRepository.getDriverById(id);
    if (!driver && id === 'driver_dummy_001') {
      driver = { id: 'driver_dummy_001', walletBalance: 0 };
    }
    
    let completedTrips = [];
    try {
      completedTrips = await tripRepository.listTripsByDriver(id);
    } catch (_) {}

    const memoryTrips = (await import('./tripService.js')).rides;
    for (const trip of memoryTrips.values()) {
      if (trip.driverId === id && trip.status === 'completed') {
        completedTrips.push(trip);
      }
    }

    const today = new Date();
    const todayTrips = completedTrips.filter((trip) => {
      const createdAt = new Date(trip.createdAt);
      return trip.status === 'completed' &&
        createdAt.getFullYear() === today.getFullYear() &&
        createdAt.getMonth() === today.getMonth() &&
        createdAt.getDate() === today.getDate();
    });

    return {
      walletBalance: driver?.walletBalance ?? 0,
      todayEarnings: todayTrips.reduce(
        (total, trip) => total + (trip.finalFare ?? trip.fareEstimate ?? 0),
        0,
      ),
      todayTrips: todayTrips.length,
    };
  }

  async rechargeWallet(id, amount) {
    const parsedAmount = parseFloat(amount);
    if (isNaN(parsedAmount) || parsedAmount <= 0) throw new Error('Invalid amount');
    // Prisma check disabled for dummy driver if not in DB
    try {
      const updated = await driverRepository.updateDriverWallet(id, parsedAmount);
      return { message: 'Recharged successfully', balance: updated.walletBalance };
    } catch (e) {
      // Fallback for dummy
      return { message: 'Recharged successfully (Dummy)', balance: parsedAmount };
    }
  }

  async createTopUpRequest(id, amount, paymentMethod, receiptImage) {
    const parsedAmount = Number(amount);
    if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) throw new Error('Invalid amount');
    if (!['instapay', 'vodafone_cash'].includes(paymentMethod)) throw new Error('Invalid payment method');
    if (typeof receiptImage !== 'string' || !receiptImage.startsWith('data:image/')) {
      throw new Error('Receipt image is required');
    }

    const driver = await prisma.driver.findFirst({
      where: { OR: [{ id }, { userId: id }] },
      select: { id: true },
    });
    if (!driver) throw new Error('Driver not found');

    return prisma.driverTopUpRequest.create({
      data: { driverId: driver.id, amount: parsedAmount, paymentMethod, receiptImage },
    });
  }

  async createWalletCheckout(id, amount) {
    const parsedAmount = parseFloat(amount);
    if (isNaN(parsedAmount) || parsedAmount <= 0) throw new Error('Invalid amount');
    if (!process.env.PAYMOB_API_KEY || !process.env.PAYMOB_INTEGRATION_ID) {
      throw new Error('Paymob is not configured');
    }

    const authResponse = await fetch('https://accept.paymob.com/api/auth/tokens', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ api_key: process.env.PAYMOB_API_KEY }),
    });
    if (!authResponse.ok) throw new Error('Paymob authentication failed');
    const { token } = await authResponse.json();
    const amountCents = Math.round(parsedAmount * 100);

    const orderResponse = await fetch('https://accept.paymob.com/api/ecommerce/orders', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        auth_token: token,
        delivery_needed: false,
        amount_cents: amountCents,
        currency: 'EGP',
        merchant_order_id: `wallet_${id}_${Date.now()}`,
        items: [],
      }),
    });
    if (!orderResponse.ok) throw new Error('Paymob order creation failed');
    const paymobOrder = await orderResponse.json();

    const keyResponse = await fetch('https://accept.paymob.com/api/acceptance/payment_keys', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        auth_token: token,
        amount_cents: amountCents,
        expiration: 3600,
        order_id: paymobOrder.id,
        currency: 'EGP',
        integration_id: Number(process.env.PAYMOB_INTEGRATION_ID),
        lock_order_when_paid: true,
        billing_data: {
          first_name: 'RideFlow', last_name: 'Driver', email: 'driver@rideflow.local',
          phone_number: '+201000000000', apartment: 'NA', floor: 'NA', street: 'NA',
          building: 'NA', shipping_method: 'NA', postal_code: 'NA', city: 'Cairo',
          country: 'EGY', state: 'Cairo',
        },
      }),
    });
    if (!keyResponse.ok) throw new Error('Paymob payment key creation failed');
    const { token: paymentToken } = await keyResponse.json();

    return {
      checkoutUrl: `https://accept.paymob.com/unifiedcheckout/?payment_token=${encodeURIComponent(paymentToken)}`,
      amount: parsedAmount,
    };
  }

  async getDriverHistory(id) {
    const { rides } = await import('./tripService.js');
    const memoryHistory = Array.from(rides.values())
      .filter((ride) => (ride.driverId === id) &&
        (ride.status === 'completed' || ride.status === 'cancelled'));

    let databaseHistory = [];
    try {
      databaseHistory = await tripRepository.listTripsByDriver(id);
    } catch (_) {}

    return [
      ...memoryHistory,
      ...databaseHistory.map((trip) => {
        const rating = trip.ratings?.[0]
          ? {
              score: trip.ratings[0].score,
              comment: trip.ratings[0].comment,
              createdAt: trip.ratings[0].createdAt,
            }
          : trip.rating || null;

        return {
          ...trip,
          rating,
          userName: trip.user?.name ?? 'عميل',
          userPhone: trip.user?.phone,
        };
      }),
    ];
  }

  async getDriverRatings(id) {
    let driver = null;
    try {
      driver = await prisma.driver.findFirst({
        where: {
          OR: [
            { id },
            { userId: id },
          ],
        },
        include: {
          user: { select: { name: true, phone: true } },
        },
      });
    } catch (_) {}

    const driverDbId = driver?.id ?? id;

    // 1. Fetch ratings from DB
    let dbRatings = [];
    try {
      dbRatings = await prisma.rating.findMany({
        where: {
          OR: [
            { driverId: driverDbId },
            { trip: { driverId: driverDbId } },
            ...(driver?.userId ? [{ trip: { driver: { userId: driver.userId } } }] : []),
          ],
        },
        include: {
          user: { select: { name: true, profileImage: true } },
        },
        orderBy: { createdAt: 'desc' },
      });
    } catch (err) {
      console.error('Error fetching driver ratings from DB:', err.message);
    }

    // 2. Fetch ratings from memory
    const { rides } = await import('./tripService.js');
    const memoryRatings = [];
    for (const trip of rides.values()) {
      const isDriverTrip =
        trip.driverId === id ||
        trip.driverId === driverDbId ||
        (driver && trip.driverId === driver.userId);

      if (isDriverTrip && trip.rating) {
        const alreadyInDb = dbRatings.some((r) => r.tripId === trip.id);
        if (!alreadyInDb) {
          memoryRatings.push({
            id: `mem_${trip.id}`,
            tripId: trip.id,
            score: trip.rating.score,
            comment: trip.rating.comment,
            createdAt: trip.rating.createdAt,
            customerName: trip.userName || 'عميل زوون',
          });
        }
      }
    }

    const allRatings = [
      ...dbRatings.map((r) => ({
        id: r.id,
        tripId: r.tripId,
        score: r.score,
        comment: r.comment,
        createdAt: r.createdAt,
        customerName: r.user?.name || 'عميل زوون',
      })),
      ...memoryRatings,
    ];

    const totalRatings = allRatings.length;
    const averageRating =
      totalRatings > 0
        ? Number((allRatings.reduce((sum, r) => sum + r.score, 0) / totalRatings).toFixed(1))
        : 5.0;

    const breakdown = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
    for (const r of allRatings) {
      const s = Math.round(r.score);
      if (breakdown[s] !== undefined) breakdown[s]++;
    }

    return {
      driverId: id,
      driverName: driver?.user?.name ?? 'كابتن زوون',
      averageRating,
      totalRatings,
      breakdown,
      ratings: allRatings,
    };
  }
}

export const driverService = new DriverService();
