import { prisma } from '../db/prisma.js';

export const customerController = {
  // Get customer profile
  getProfile: async (req, res) => {
    try {
      const userId = req.user?.id || req.user?.userId;

      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          name: true,
          phone: true,
          email: true,
          profileImage: true,
          walletBalance: true,
          createdAt: true,
        },
      });

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      res.json(user);
    } catch (error) {
      console.error('Error fetching profile:', error);
      res.status(500).json({ error: 'Failed to fetch profile' });
    }
  },

  // Get customer balance and transactions
  getBalance: async (req, res) => {
    try {
      const userId = req.user?.id || req.user?.userId;

      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          walletBalance: true,
          payments: {
            take: 20,
            orderBy: { createdAt: 'desc' },
            select: {
              id: true,
              amount: true,
              status: true,
              paymentMethod: true,
              orderId: true,
              tripId: true,
              createdAt: true,
              order: {
                select: {
                  id: true,
                  serviceType: true,
                  shippingPickupAddress: true,
                  limousinePickupAddress: true,
                },
              },
            },
          },
        },
      });

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      // Transform transactions — distinguish wallet top-ups from service payments
      const transactions = user.payments.map((payment) => {
        const isTopUp = !payment.orderId && !payment.tripId;
        let type, title, location;

        if (isTopUp) {
          type = 'wallet_topup';
          title = 'شحن رصيد';
          location = payment.paymentMethod === 'card' ? 'بطاقة بنكية' : 'كاش';
        } else if (payment.order?.serviceType === 'LIMOUSINE') {
          type = 'limousine';
          title = 'خدمة ليموزين';
          location = payment.order?.limousinePickupAddress || 'رحلة ليموزين';
        } else {
          type = 'shipping';
          title = 'خدمة شحن';
          location = payment.order?.shippingPickupAddress || 'شحنة';
        }

        return {
          id: payment.id,
          amount: payment.amount,
          type,
          title,
          location,
          isTopUp,
          status: payment.status,
          paymentMethod: payment.paymentMethod,
          date: payment.createdAt,
        };
      });

      res.json({
        balance: user.walletBalance || 0.0,
        transactions,
      });
    } catch (error) {
      console.error('Error fetching balance:', error);
      res.status(500).json({ error: 'Failed to fetch balance' });
    }
  },

  // Get customer orders (past trips)
  getOrders: async (req, res) => {
    try {
      const userId = req.user?.id || req.user?.userId;
      const limit = parseInt(req.query.limit) || 10;
      const skip = parseInt(req.query.skip) || 0;

      const [orders, trips] = await Promise.all([
        prisma.order.findMany({
          where: { customerId: userId },
          take: limit,
          skip: skip,
          orderBy: { createdAt: 'desc' },
          select: {
            id: true,
            serviceType: true,
            status: true,
            finalPrice: true,
            shippingPickupAddress: true,
            shippingDropoffAddress: true,
            limousinePickupAddress: true,
            limousineDropoffAddress: true,
            createdAt: true,
          },
        }).catch(() => []),
        prisma.trip.findMany({
          where: { userId },
          take: limit,
          skip: skip,
          orderBy: { createdAt: 'desc' },
          select: {
            id: true,
            pickupAddress: true,
            dropoffAddress: true,
            status: true,
            finalFare: true,
            proposedFare: true,
            fareEstimate: true,
            createdAt: true,
          },
        }).catch(() => []),
      ]);

      const formattedOrders = orders.map((order) => ({
        id: order.id,
        tripId: `#${order.id.slice(0, 6).toUpperCase()}`,
        from: order.shippingPickupAddress || order.limousinePickupAddress || 'غير محدد',
        to: order.shippingDropoffAddress || order.limousineDropoffAddress || 'غير محدد',
        date: order.createdAt,
        cost: order.finalPrice || 'N/A',
        status: order.status === 'COMPLETED' ? 'مكتملة' : order.status === 'CANCELLED' ? 'ملغاة' : order.status,
        statusColor: order.status === 'COMPLETED' ? 'success' : order.status === 'CANCELLED' ? 'error' : 'warning',
      }));

      const formattedTrips = trips.map((trip) => ({
        id: trip.id,
        tripId: `#${trip.id.slice(0, 6).toUpperCase()}`,
        from: trip.pickupAddress || 'غير محدد',
        to: trip.dropoffAddress || 'غير محدد',
        date: trip.createdAt,
        cost: trip.finalFare || trip.proposedFare || trip.fareEstimate || '0',
        status: trip.status === 'completed' ? 'مكتملة' : trip.status === 'cancelled' ? 'ملغاة' : trip.status,
        statusColor: trip.status === 'completed' ? 'success' : trip.status === 'cancelled' ? 'error' : 'warning',
      }));

      const allTrips = [...formattedOrders, ...formattedTrips].sort(
        (a, b) => new Date(b.date) - new Date(a.date)
      );

      res.json(allTrips.slice(0, limit));
    } catch (error) {
      console.error('Error fetching orders:', error);
      res.status(500).json({ error: 'Failed to fetch orders' });
    }
  },

  // Get customer trips history
  getTripsHistory: async (req, res) => {
    try {
      const userId = req.user.id;

      const trips = await prisma.trip.findMany({
        where: { userId },
        take: 10,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          pickupAddress: true,
          dropoffAddress: true,
          status: true,
          finalFare: true,
          createdAt: true,
        },
      });

      const formattedTrips = trips.map((trip) => ({
        id: trip.id,
        tripId: `#${trip.id.slice(0, 6).toUpperCase()}`,
        from: trip.pickupAddress,
        to: trip.dropoffAddress,
        date: trip.createdAt,
        cost: trip.finalFare,
        status: trip.status === 'completed' ? 'مكتملة' : trip.status,
      }));

      res.json(formattedTrips);
    } catch (error) {
      console.error('Error fetching trips history:', error);
      res.status(500).json({ error: 'Failed to fetch trips history' });
    }
  },

  // Add funds to wallet
  addFunds: async (req, res) => {
    try {
      const userId = req.user?.id || req.user?.userId;
      const { amount } = req.body;

      if (!amount || amount <= 0) {
        return res.status(400).json({ error: 'Invalid amount' });
      }

      const user = await prisma.user.update({
        where: { id: userId },
        data: {
          walletBalance: {
            increment: amount,
          },
        },
        select: {
          walletBalance: true,
        },
      });

      // Create payment record
      await prisma.payment.create({
        data: {
          userId,
          amount,
          status: 'completed',
          paymentMethod: 'card',
        },
      });

      res.json({
        success: true,
        newBalance: user.walletBalance,
      });
    } catch (error) {
      console.error('Error adding funds:', error);
      res.status(500).json({ error: 'Failed to add funds' });
    }
  },

  // Get customer recurring trips (aggregated from real trips & orders)
  getRecurringTrips: async (req, res) => {
    try {
      const userId = req.user?.id || req.user?.userId;

      const [trips, orders] = await Promise.all([
        prisma.trip.findMany({
          where: { userId },
          orderBy: { createdAt: 'desc' },
          take: 50,
          select: {
            id: true,
            pickupAddress: true,
            dropoffAddress: true,
            pickupLat: true,
            pickupLng: true,
            dropoffLat: true,
            dropoffLng: true,
            fareEstimate: true,
            finalFare: true,
            proposedFare: true,
            createdAt: true,
          },
        }).catch(() => []),
        prisma.order.findMany({
          where: { customerId: userId },
          orderBy: { createdAt: 'desc' },
          take: 50,
          select: {
            id: true,
            shippingPickupAddress: true,
            shippingDropoffAddress: true,
            shippingPickupLat: true,
            shippingPickupLng: true,
            shippingDropoffLat: true,
            shippingDropoffLng: true,
            limousinePickupAddress: true,
            limousineDropoffAddress: true,
            limousinePickupLat: true,
            limousinePickupLng: true,
            limousineDropoffLat: true,
            limousineDropoffLng: true,
            finalPrice: true,
            customerOfferPrice: true,
            createdAt: true,
          },
        }).catch(() => []),
      ]);

      // Normalize all trips
      const allNormalized = [];

      for (const t of trips) {
        if (t.pickupAddress && t.dropoffAddress) {
          allNormalized.push({
            from: t.pickupAddress.trim(),
            to: t.dropoffAddress.trim(),
            pickupLat: t.pickupLat,
            pickupLng: t.pickupLng,
            dropoffLat: t.dropoffLat,
            dropoffLng: t.dropoffLng,
            cost: t.finalFare || t.proposedFare || t.fareEstimate || 0,
            date: t.createdAt,
          });
        }
      }

      for (const o of orders) {
        const from = (o.shippingPickupAddress || o.limousinePickupAddress || '').trim();
        const to = (o.shippingDropoffAddress || o.limousineDropoffAddress || '').trim();
        if (from && to) {
          allNormalized.push({
            from,
            to,
            pickupLat: o.shippingPickupLat || o.limousinePickupLat,
            pickupLng: o.shippingPickupLng || o.limousinePickupLng,
            dropoffLat: o.shippingDropoffLat || o.limousineDropoffLat,
            dropoffLng: o.shippingDropoffLng || o.limousineDropoffLng,
            cost: o.finalPrice || o.customerOfferPrice || 0,
            date: o.createdAt,
          });
        }
      }

      // Group by from + to
      const routeMap = new Map();
      for (const item of allNormalized) {
        const key = `${item.from.toLowerCase()}___${item.to.toLowerCase()}`;
        if (!routeMap.has(key)) {
          routeMap.set(key, {
            from: item.from,
            to: item.to,
            pickupLat: item.pickupLat,
            pickupLng: item.pickupLng,
            dropoffLat: item.dropoffLat,
            dropoffLng: item.dropoffLng,
            count: 1,
            lastTripDate: item.date,
            totalCost: Number(item.cost) || 0,
          });
        } else {
          const existing = routeMap.get(key);
          existing.count += 1;
          existing.totalCost += (Number(item.cost) || 0);
          if (new Date(item.date) > new Date(existing.lastTripDate)) {
            existing.lastTripDate = item.date;
          }
        }
      }

      // Sort routes: first by count descending, then by lastTripDate descending
      const recurring = Array.from(routeMap.values())
        .sort((a, b) => b.count - a.count || new Date(b.lastTripDate) - new Date(a.lastTripDate))
        .map((r, index) => {
          const avgCost = Math.round(r.totalCost / r.count);
          const daysAgo = Math.floor((Date.now() - new Date(r.lastTripDate).getTime()) / (1000 * 60 * 60 * 24));
          const lastTripText = daysAgo === 0 ? 'اليوم' : daysAgo === 1 ? 'أمس' : `منذ ${daysAgo} أيام`;

          return {
            id: `rec_${index}`,
            name: r.count > 1 ? `مشوار متكرر (${r.count} مرات)` : `مشوار سابق`,
            from: r.from,
            to: r.to,
            pickupLat: r.pickupLat,
            pickupLng: r.pickupLng,
            dropoffLat: r.dropoffLat,
            dropoffLng: r.dropoffLng,
            frequency: r.count > 1 ? `تكررت ${r.count} مرات` : 'وجهة سابقة',
            time: new Date(r.lastTripDate).toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' }),
            lastTrip: `آخر استخدام: ${lastTripText}`,
            cost: avgCost,
          };
        });

      res.json(recurring);
    } catch (error) {
      console.error('Error fetching recurring trips:', error);
      res.status(500).json({ error: 'Failed to fetch recurring trips' });
    }
  },

  // Update customer profile
  updateProfile: async (req, res) => {
    try {
      const userId = req.user?.id || req.user?.userId;
      const { name, email, phone, profileImage } = req.body;

      const updateData = {};
      if (name && typeof name === 'string' && name.trim().length > 0) {
        updateData.name = name.trim();
      }
      if (email && typeof email === 'string' && email.trim().length > 0) {
        updateData.email = email.trim();
      }
      if (phone && typeof phone === 'string' && phone.trim().length > 0) {
        updateData.phone = phone.trim();
      }
      if (typeof profileImage === 'string' && profileImage.startsWith('data:image/')) {
        updateData.profileImage = profileImage;
      }

      const updatedUser = await prisma.user.update({
        where: { id: userId },
        data: updateData,
        select: {
          id: true,
          name: true,
          phone: true,
          email: true,
          profileImage: true,
          role: true,
          walletBalance: true,
          createdAt: true,
        },
      });

      res.json({ success: true, user: updatedUser });
    } catch (error) {
      console.error('Error updating profile:', error);
      res.status(500).json({ error: 'Failed to update profile' });
    }
  },
};
