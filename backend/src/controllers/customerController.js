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
            take: 10,
            orderBy: { createdAt: 'desc' },
            select: {
              id: true,
              amount: true,
              status: true,
              paymentMethod: true,
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

      // Transform transactions
      const transactions = user.payments.map((payment) => ({
        id: payment.id,
        amount: payment.amount,
        type: payment.order?.serviceType === 'LIMOUSINE' ? 'limousine' : 'shipping',
        location: payment.order?.shippingPickupAddress || payment.order?.limousinePickupAddress || 'معاملة',
        status: payment.status,
        date: payment.createdAt,
      }));

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
      const userId = req.user.id;
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
};
