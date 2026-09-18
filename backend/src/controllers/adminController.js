import { PrismaClient } from '@prisma/client';
import { tripService, emitOrderStatusChanged } from '../services/tripService.js';
import { getOnlineDriversCount, getOnlineDriversList } from '../sockets/socketServer.js';
import { supportService } from '../services/supportService.js';
import logger from '../utils/logger.js';

const prisma = new PrismaClient();

export const getTopUpRequests = async (req, res) => {
  try {
    const requests = await prisma.driverTopUpRequest.findMany({
      where: { status: 'pending' },
      include: { driver: { include: { user: { select: { name: true, phone: true } } } } },
      orderBy: { createdAt: 'asc' },
    });
    res.json({ requests });
  } catch (error) {
    logger.error('Failed to fetch top-up requests', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch top-up requests' });
  }
};

export const reviewTopUpRequest = async (req, res) => {
  try {
    const request = await prisma.driverTopUpRequest.findUnique({ where: { id: req.params.id } });
    if (!request || request.status !== 'pending') {
      return res.status(404).json({ error: 'Pending request not found' });
    }

    const approve = req.body.approve === true;
    const result = await prisma.$transaction(async (tx) => {
      const updated = await tx.driverTopUpRequest.update({
        where: { id: request.id },
        data: { status: approve ? 'approved' : 'rejected', adminNote: req.body.adminNote || null },
      });
      if (approve) {
        await tx.driver.update({
          where: { id: request.driverId },
          data: { walletBalance: { increment: request.amount } },
        });
      }
      return updated;
    });
    res.json({ request: result });
  } catch (error) {
    logger.error('Failed to review top-up request', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to review top-up request' });
  }
};

export const getPendingDrivers = async (req, res) => {
  try {
    const drivers = await prisma.driver.findMany({
      where: { status: 'pending' },
      include: {
        user: { select: { name: true, phone: true, email: true } },
        car: true,
      },
    });
    res.json({ drivers });
  } catch (error) {
    logger.error('Failed to fetch pending drivers', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch pending drivers' });
  }
};

export const approveDriver = async (req, res) => {
  try {
    const { id } = req.params;
    const driver = await prisma.driver.update({
      where: { id },
      data: { status: 'approved' },
      include: { user: true },
    });
    res.json({ message: 'Driver approved successfully', driver });
  } catch (error) {
    logger.error('Failed to approve driver', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to approve driver' });
  }
};

export const rejectDriver = async (req, res) => {
  try {
    const { id } = req.params;
    const driver = await prisma.driver.update({
      where: { id },
      data: { status: 'rejected' },
      include: { user: true },
    });
    res.json({ message: 'Driver rejected successfully', driver });
  } catch (error) {
    logger.error('Failed to reject driver', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to reject driver' });
  }
};

export const getAllDrivers = async (req, res) => {
  try {
    const { status, search } = req.query;
    const where = {};
    if (status && status !== 'ALL') {
      where.status = status;
    }

    let drivers = await prisma.driver.findMany({
      where,
      include: {
        user: { select: { id: true, name: true, phone: true, email: true, profileImage: true } },
        car: true,
        trips: {
          select: { id: true, status: true, finalFare: true, fareEstimate: true },
        },
        ratings: { select: { score: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    let formatted = drivers.map((d) => {
      const completedTrips = (d.trips || []).filter((t) => t.status === 'completed');
      const avgRating = (d.ratings && d.ratings.length > 0)
        ? Number((d.ratings.reduce((acc, r) => acc + r.score, 0) / d.ratings.length).toFixed(1))
        : 5.0;

      return {
        id: d.id,
        userId: d.userId,
        name: d.user?.name || 'سائق',
        phone: d.user?.phone || '',
        email: d.user?.email || '',
        profileImage: d.user?.profileImage,
        status: d.status || 'approved', // 'pending', 'approved', 'rejected', 'suspended'
        walletBalance: d.walletBalance || 0.0,
        car: d.car
          ? {
              model: d.car.model,
              color: d.car.color,
              year: d.car.year,
              plateNumber: d.car.plateNumber,
            }
          : null,
        completedTripsCount: completedTrips.length,
        rating: avgRating,
        createdAt: d.createdAt,
      };
    });

    if (search && search.trim().length > 0) {
      const q = search.trim().toLowerCase();
      formatted = formatted.filter((d) =>
        (d.name && d.name.toLowerCase().includes(q)) ||
        (d.phone && d.phone.includes(q)) ||
        (d.car?.plateNumber && d.car.plateNumber.toLowerCase().includes(q)) ||
        (d.car?.model && d.car.model.toLowerCase().includes(q))
      );
    }

    res.json({ drivers: formatted });
  } catch (error) {
    logger.error('Failed to fetch drivers', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch drivers' });
  }
};

export const updateDriverStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    if (!status) return res.status(400).json({ error: 'Status is required' });

    const driver = await prisma.driver.update({
      where: { id },
      data: { status },
      include: { user: true },
    });

    res.json({ message: 'Driver status updated successfully', driver });
  } catch (error) {
    logger.error('Failed to update driver status', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to update driver status' });
  }
};

export const adjustDriverWallet = async (req, res) => {
  try {
    const { id } = req.params;
    const { amount, reason } = req.body;
    const numericAmount = parseFloat(amount);
    if (isNaN(numericAmount) || numericAmount === 0) {
      return res.status(400).json({ error: 'Valid amount is required' });
    }

    const driver = await prisma.driver.update({
      where: { id },
      data: { walletBalance: { increment: numericAmount } },
      include: { user: true },
    });

    // Notify driver if user exists
    if (driver.userId) {
      await prisma.notification.create({
        data: {
          userId: driver.userId,
          title: numericAmount > 0 ? 'إيداع رصيد في المحفظة 💰' : 'خصم من رصيد المحفظة ⚠️',
          body: `${numericAmount > 0 ? 'تمت إضافة' : 'تم خصم'} ${Math.abs(numericAmount)} ج.م ${reason ? `(${reason})` : ''}`,
          type: 'wallet_update',
        },
      }).catch(() => {});
    }

    res.json({
      message: 'Driver wallet updated successfully',
      driverId: driver.id,
      newBalance: driver.walletBalance,
    });
  } catch (error) {
    logger.error('Failed to adjust driver wallet', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to adjust driver wallet' });
  }
};

// Company management
export const getPendingCompanies = async (req, res) => {
  try {
    const companies = await prisma.company.findMany({
      where: { status: 'pending' },
      include: {
        user: { select: { name: true, phone: true, email: true } },
      },
    });
    res.json({ companies });
  } catch (error) {
    logger.error('Failed to fetch pending companies', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch pending companies' });
  }
};

export const approveCompany = async (req, res) => {
  try {
    const { id } = req.params;
    const company = await prisma.company.update({
      where: { id },
      data: { status: 'active' },
      include: { user: true },
    });
    res.json({ message: 'Company approved successfully', company });
  } catch (error) {
    logger.error('Failed to approve company', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to approve company' });
  }
};

export const rejectCompany = async (req, res) => {
  try {
    const { id } = req.params;
    const company = await prisma.company.update({
      where: { id },
      data: { status: 'rejected' },
      include: { user: true },
    });
    res.json({ message: 'Company rejected successfully', company });
  } catch (error) {
    logger.error('Failed to reject company', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to reject company' });
  }
};

// Order management for super admin
export const getAllOrders = async (req, res) => {
  try {
    const { serviceType, status } = req.query;
    const filters = {};

    if (serviceType) filters.serviceType = serviceType;
    if (status) filters.status = status;

    const orders = await prisma.order.findMany({
      where: filters,
      include: {
        customer: { select: { id: true, name: true, phone: true, email: true } },
        company: { select: { id: true, companyName: true, companyType: true } },
        priceOffers: { orderBy: { createdAt: 'desc' } },
      },
      orderBy: { createdAt: 'desc' },
    });

    res.json({ orders });
  } catch (error) {
    logger.error('Failed to fetch orders', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
};

export const getAllCustomers = async (req, res) => {
  try {
    const { search } = req.query;
    const customers = await prisma.user.findMany({
      where: { role: 'customer' },
      include: {
        trips: {
          select: { id: true, status: true, finalFare: true, fareEstimate: true },
        },
        orders: {
          select: { id: true, status: true, finalPrice: true, customerOfferPrice: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    let formatted = customers.map((c) => {
      const completedTrips = (c.trips || []).filter((t) => t.status === 'completed');
      const tripsSpent = completedTrips.reduce((sum, t) => sum + (t.finalFare || t.fareEstimate || 0), 0);
      const completedOrders = (c.orders || []).filter((o) => o.status === 'COMPLETED');
      const ordersSpent = completedOrders.reduce((sum, o) => sum + (o.finalPrice || o.customerOfferPrice || 0), 0);

      return {
        id: c.id,
        name: c.name,
        phone: c.phone,
        email: c.email,
        walletBalance: c.walletBalance || 0,
        createdAt: c.createdAt,
        totalTrips: c.trips?.length || 0,
        completedTripsCount: completedTrips.length,
        totalOrders: c.orders?.length || 0,
        totalSpent: Number((tripsSpent + ordersSpent).toFixed(2)),
      };
    });

    if (search && search.trim().length > 0) {
      const q = search.trim().toLowerCase();
      formatted = formatted.filter((c) =>
        (c.name && c.name.toLowerCase().includes(q)) ||
        (c.phone && c.phone.includes(q)) ||
        (c.email && c.email.toLowerCase().includes(q))
      );
    }

    res.json({ customers: formatted });
  } catch (error) {
    logger.error('Failed to fetch customers', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch customers' });
  }
};

export const getFinancesSummary = async (req, res) => {
  try {
    // Total drivers wallet balance & count
    const driversAgg = await prisma.driver.aggregate({
      _sum: { walletBalance: true },
      _count: { id: true },
    }).catch(() => ({ _sum: { walletBalance: 0 }, _count: { id: 0 } }));

    // Top-up requests count & total
    const pendingTopUps = await prisma.driverTopUpRequest.count({
      where: { status: 'pending' },
    }).catch(() => 0);

    const approvedTopUpsAgg = await prisma.driverTopUpRequest.aggregate({
      where: { status: 'approved' },
      _sum: { amount: true },
      _count: { id: true },
    }).catch(() => ({ _sum: { amount: 0 }, _count: { id: 0 } }));

    // Trips volume
    const tripsAgg = await prisma.trip.aggregate({
      where: { status: 'completed' },
      _sum: { finalFare: true },
      _count: { id: true },
    }).catch(() => ({ _sum: { finalFare: 0 }, _count: { id: 0 } }));

    res.json({
      totalDriversBalance: driversAgg._sum.walletBalance || 0,
      totalDriversCount: driversAgg._count.id || 0,
      pendingTopUpsCount: pendingTopUps,
      approvedTopUpsCount: approvedTopUpsAgg._count.id || 0,
      approvedTopUpsTotal: approvedTopUpsAgg._sum.amount || 0,
      completedTripsCount: tripsAgg._count.id || 0,
      totalTripsVolume: tripsAgg._sum.finalFare || 0,
    });
  } catch (error) {
    logger.error('Failed to fetch finances summary', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch finances summary' });
  }
};

export const getSupportTickets = (req, res) => {
  try {
    const { status, search } = req.query;
    const tickets = supportService.getTickets({ status, search });
    const stats = supportService.getStats();
    res.json({ tickets, stats });
  } catch (error) {
    logger.error('Failed to get support tickets', { error: error.message });
    res.status(500).json({ error: 'Failed to get support tickets' });
  }
};

export const updateSupportTicket = (req, res) => {
  try {
    const { id } = req.params;
    const { status, adminReply } = req.body;
    const updated = supportService.updateTicket(id, { status, adminReply });
    if (!updated) {
      return res.status(404).json({ error: 'Ticket not found' });
    }
    res.json({ message: 'Ticket updated successfully', ticket: updated });
  } catch (error) {
    logger.error('Failed to update support ticket', { error: error.message });
    res.status(500).json({ error: 'Failed to update support ticket' });
  }
};

export const getAllCompanies = async (req, res) => {
  try {
    const companies = await prisma.company.findMany({
      include: {
        user: { select: { name: true, phone: true, email: true } },
        orders: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    res.json({ companies });
  } catch (error) {
    logger.error('Failed to fetch companies', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch companies' });
  }
};

export const getAdminStats = async (req, res) => {
  try {
    // Database stats (may fail if DB not ready)
    let dbStats = {
      registeredUsers: 0,
      registeredDrivers: 0,
      registeredCustomers: 0,
      registeredCompanies: 0,
    };
    try {
      const usersCount = await prisma.user.count();
      const driversCount = await prisma.driver.count();
      const customersCount = await prisma.user.count({ where: { role: 'customer' } });
      const companiesCount = await prisma.company.count();
      dbStats = {
        registeredUsers: usersCount,
        registeredDrivers: driversCount,
        registeredCustomers: customersCount,
        registeredCompanies: companiesCount,
      };
    } catch (e) {
      logger.warn('DB stats unavailable', { error: e.message });
    }

    // Order stats
    const totalOrders = await prisma.order.count();
    const limousineOrders = await prisma.order.count({ where: { serviceType: 'LIMOUSINE' } });
    const shippingOrders = await prisma.order.count({ where: { serviceType: 'SHIPPING' } });
    const confirmedOrders = await prisma.order.count({ where: { status: 'CONFIRMED' } });
    const completedOrders = await prisma.order.count({ where: { status: 'COMPLETED' } });

    // Company stats
    const pendingCompanies = await prisma.company.count({ where: { status: 'pending' } });
    const activeCompanies = await prisma.company.count({ where: { status: 'active' } });
    const limousineCompanies = await prisma.company.count({ where: { companyType: 'LIMOUSINE' } });
    const shippingCompanies = await prisma.company.count({ where: { companyType: 'SHIPPING' } });

    // Live stats from in-memory trip service
    const tripStats = tripService.getTripStats();

    // Online drivers from socket server
    const onlineDriversCount = getOnlineDriversCount();
    const onlineDriversList = getOnlineDriversList();

    res.json({
      // Live connection stats
      onlineDriversCount,
      onlineDriversList,

      // User stats
      ...dbStats,

      // Order stats
      orders: {
        totalOrders,
        limousineOrders,
        shippingOrders,
        confirmedOrders,
        completedOrders,
      },

      // Company stats
      companies: {
        pendingCompanies,
        activeCompanies,
        limousineCompanies,
        shippingCompanies,
      },

      // Trip stats (from in-memory store)
      ...tripStats,
    });
  } catch (error) {
    logger.error('Failed to fetch admin stats', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
};

// Keep backward compatibility
export const getStats = getAdminStats;
export const adminAcceptOrder = async (req, res) => {
  try {
    const { orderId } = req.params;
    const order = await prisma.order.findUnique({ where: { id: orderId } });
    if (!order) return res.status(404).json({ error: 'Order not found' });

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'COMPANY_ACCEPTED',
        finalPrice: order.customerOfferPrice,
      },
      include: { customer: true },
    });

    await prisma.notification.create({
      data: {
        userId: updatedOrder.customerId,
        title: 'Order Accepted (Admin)',
        body: `Your order has been accepted at ${updatedOrder.price || 0} EGP`,
        type: 'order_accepted',
        orderId: orderId,
      },
    });

    emitOrderStatusChanged({
      orderId,
      status: 'COMPANY_ACCEPTED',
      price: updatedOrder.finalPrice,
    });

    res.json({ message: 'Order accepted', order: updatedOrder });
  } catch (error) {
    logger.error('Failed to accept order', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to accept order' });
  }
};

export const adminRejectOrder = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { reason } = req.body;
    const order = await prisma.order.findUnique({ where: { id: orderId } });
    if (!order) return res.status(404).json({ error: 'Order not found' });

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'COMPANY_REJECTED',
        rejectionReason: reason || null,
      },
    });

    await prisma.notification.create({
      data: {
        userId: updatedOrder.customerId,
        title: 'Order Rejected (Admin)',
        body: `Your order has been rejected`,
        type: 'order_rejected',
        orderId: orderId,
      },
    });

    emitOrderStatusChanged({
      orderId,
      status: 'COMPANY_REJECTED',
      reason: reason || null,
    });

    res.json({ message: 'Order rejected', order: updatedOrder });
  } catch (error) {
    logger.error('Failed to reject order', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to reject order' });
  }
};

export const adminSendCounterOffer = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { offeredPrice } = req.body;

    if (!offeredPrice || offeredPrice <= 0) {
      return res.status(400).json({ error: 'Valid offered price is required' });
    }

    const order = await prisma.order.findUnique({ where: { id: orderId } });
    if (!order) return res.status(404).json({ error: 'Order not found' });

    let companyId = req.user?.companyId || order.companyId;
    if (companyId) {
      const company = await prisma.company.findUnique({ where: { id: companyId } });
      if (!company) companyId = null;
    }
    if (!companyId) {
      let shippingCompany = await prisma.company.findFirst({
        where: { companyType: 'SHIPPING', status: { in: ['active', 'approved'] } },
        orderBy: { createdAt: 'asc' },
      });
      if (!shippingCompany) {
        shippingCompany = await prisma.company.findFirst({
          where: { companyType: 'SHIPPING' },
        });
      }
      if (!shippingCompany) {
        shippingCompany = await prisma.company.findFirst();
      }
      if (!shippingCompany) {
        shippingCompany = await prisma.company.create({
          data: {
            companyName: 'شركة النقل المعتمدة',
            companyType: 'SHIPPING',
            phone: '01000000000',
            password: 'password_placeholder',
            status: 'active',
          },
        });
      }
      companyId = shippingCompany.id;
    }

    const priceOffer = await prisma.priceOffer.create({
      data: {
        orderId,
        customerId: order.customerId,
        companyId,
        offeredPrice,
        sentBy: 'COMPANY',
      },
    });

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'PRICE_SENT',
        companyOfferPrice: offeredPrice,
        companyId,
      },
    });

    await prisma.notification.create({
      data: {
        userId: order.customerId,
        title: 'Price Offer (Admin)',
        body: `Offered price for your order: ${offeredPrice} EGP`,
        type: 'price_offer',
        orderId: orderId,
      },
    });

    emitOrderStatusChanged({ orderId, status: 'PRICE_SENT', price: offeredPrice });

    res.json({ message: 'Counter offer sent', priceOffer, order: updatedOrder });
  } catch (error) {
    logger.error('Failed to send counter offer', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to send counter offer' });
  }
};
