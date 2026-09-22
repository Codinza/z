import { driverRepository } from '../repositories/driverRepository.js';
import { tripRepository } from '../repositories/tripRepository.js';
import { prisma } from '../db/prisma.js';

class DriverService {
  async listDrivers() {
    return await driverRepository.listDrivers();
  }

  async getDriverById(id) {
    return await driverRepository.getDriverById(id);
  }

  async getDriverWallet(id, authUserId) {
    let driver = await driverRepository.getDriverById(id, [authUserId]);

    // Driver row missing but the logged-in user is a driver — heal it.
    if (!driver && authUserId) {
      const user = await prisma.user.findUnique({
        where: { id: authUserId },
        select: { id: true, role: true, walletBalance: true },
      });
      if (user?.role === 'driver') {
        driver = await prisma.driver.upsert({
          where: { userId: authUserId },
          update: {},
          create: {
            userId: authUserId,
            status: 'approved',
            vehicleCategory: 'car',
            walletBalance: Number(user.walletBalance ?? 0),
          },
        });
      }
    }

    if (!driver) {
      return { walletBalance: 0, todayEarnings: 0, todayTrips: 0 };
    }

    let walletBalance = Number(driver.walletBalance ?? 0);
    try {
      const user = await prisma.user.findUnique({
        where: { id: driver.userId },
        select: { walletBalance: true },
      });
      const userBalance = Number(user?.walletBalance ?? 0);
      if (userBalance > walletBalance) {
        driver = await prisma.driver.update({
          where: { id: driver.id },
          data: { walletBalance: userBalance },
        });
        walletBalance = userBalance;
      } else if (userBalance !== walletBalance) {
        await prisma.user.update({
          where: { id: driver.userId },
          data: { walletBalance },
        });
      }
    } catch (_) {}

    const resolvedId = driver.id;
    let completedTrips = [];
    try {
      completedTrips = await tripRepository.listTripsByDriver(resolvedId);
    } catch (_) {}

    const memoryTrips = (await import('./tripService.js')).rides;
    for (const trip of memoryTrips.values()) {
      if (
        (trip.driverId === id ||
          trip.driverId === resolvedId ||
          trip.driverId === driver.userId) &&
        trip.status === 'completed'
      ) {
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
      walletBalance,
      driverId: driver.id,
      userId: driver.userId,
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

  async createTopUpRequest(id, amount, paymentMethod, receiptImage, authUserId) {
    const parsedAmount = Number(amount);
    if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
      throw new Error('أدخل مبلغ صحيح');
    }
    if (!['instapay', 'vodafone_cash'].includes(paymentMethod)) {
      throw new Error('طريقة التحويل غير صحيحة');
    }
    if (typeof receiptImage !== 'string' || !receiptImage.startsWith('data:image/')) {
      throw new Error('صورة الإيصال مطلوبة');
    }

    const ids = [...new Set([id, authUserId].filter(Boolean))];
    let driver = await prisma.driver.findFirst({
      where: {
        OR: ids.flatMap((value) => [{ id: value }, { userId: value }]),
      },
      select: { id: true },
    });

    // Driver account exists as User(role=driver) but missing Driver row — heal it.
    if (!driver && authUserId) {
      const user = await prisma.user.findUnique({
        where: { id: authUserId },
        select: { id: true, role: true },
      });
      if (user?.role === 'driver') {
        driver = await prisma.driver.upsert({
          where: { userId: authUserId },
          update: {},
          create: {
            userId: authUserId,
            status: 'approved',
            vehicleCategory: 'car',
          },
          select: { id: true },
        });
      }
    }

    if (!driver) {
      throw new Error('حساب السائق غير موجود. سجّل الخروج وادخل مرة أخرى.');
    }

    return prisma.driverTopUpRequest.create({
      data: {
        driverId: driver.id,
        amount: parsedAmount,
        paymentMethod,
        receiptImage,
      },
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
    let driver = null;
    try {
      driver = await prisma.driver.findFirst({
        where: {
          OR: [{ id }, { userId: id }],
        },
      });
    } catch (_) {}

    const driverDbId = driver?.id ?? id;
    const driverUserId = driver?.userId ?? id;

    const { rides } = await import('./tripService.js');
    const memoryHistory = Array.from(rides.values())
      .filter((ride) => (
        ride.driverId === id ||
        ride.driverId === driverDbId ||
        ride.driverId === driverUserId
      ) && (ride.status === 'completed' || ride.status === 'cancelled'));

    let databaseHistory = [];
    try {
      databaseHistory = await tripRepository.listTripsByDriver(driverDbId);
      if (driverUserId !== driverDbId) {
        const userTrips = await tripRepository.listTripsByDriver(driverUserId);
        for (const ut of userTrips) {
          if (!databaseHistory.some((dt) => dt.id === ut.id)) {
            databaseHistory.push(ut);
          }
        }
      }
    } catch (_) {}

    // Combine and deduplicate
    const combinedMap = new Map();

    for (const trip of databaseHistory) {
      const rating = trip.ratings?.[0]
        ? {
            score: trip.ratings[0].score,
            comment: trip.ratings[0].comment,
            createdAt: trip.ratings[0].createdAt,
          }
        : trip.rating || null;

      combinedMap.set(trip.id, {
        ...trip,
        rating,
        userName: trip.user?.name ?? 'عميل زوون',
        userPhone: trip.user?.phone ?? null,
      });
    }

    for (const ride of memoryHistory) {
      if (!combinedMap.has(ride.id)) {
        combinedMap.set(ride.id, {
          ...ride,
          userName: ride.userName || 'عميل زوون',
          userPhone: ride.userPhone || null,
        });
      }
    }

    return Array.from(combinedMap.values()).sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
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
