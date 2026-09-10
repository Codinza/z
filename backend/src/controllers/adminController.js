import { PrismaClient } from '@prisma/client';
import { tripService, emitOrderStatusChanged } from '../services/tripService.js';
import { getOnlineDriversCount, getOnlineDriversList } from '../sockets/socketServer.js';

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
    console.error('getTopUpRequests error:', error);
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
    console.error('reviewTopUpRequest error:', error);
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
    console.error('getPendingDrivers error:', error);
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
    console.error('approveDriver error:', error);
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
    console.error('rejectDriver error:', error);
    res.status(500).json({ error: 'Failed to reject driver' });
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
    console.error('getPendingCompanies error:', error);
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
    console.error('approveCompany error:', error);
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
    console.error('rejectCompany error:', error);
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
    console.error('getAllOrders error:', error);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
};

export const getAllCustomers = async (req, res) => {
  try {
    const customers = await prisma.user.findMany({
      where: { role: 'customer' },
      select: {
        id: true,
        name: true,
        phone: true,
        email: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    res.json({ customers });
  } catch (error) {
    console.error('getAllCustomers error:', error);
    res.status(500).json({ error: 'Failed to fetch customers' });
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
    console.error('getAllCompanies error:', error);
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
      console.warn('DB stats unavailable:', e.message);
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
    console.error('getAdminStats error:', error);
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
    console.error('adminAcceptOrder error:', error);
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

    res.json({ message: 'Order rejected', order: updatedOrder });
  } catch (error) {
    console.error('adminRejectOrder error:', error);
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
    console.error('adminSendCounterOffer error:', error);
    res.status(500).json({ error: 'Failed to send counter offer' });
  }
};
