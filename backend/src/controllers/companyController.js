import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { emitOrderStatusChanged } from '../services/tripService.js';

const prisma = new PrismaClient();

function generateTokens(user, companyId = null, companyType = null) {
  const payload = {
    id: user.id,
    role: user.role,
    email: user.email,
    ...(companyId && { companyId }),
    ...(companyType && { companyType }),
  };

  const accessToken = jwt.sign(payload, env.jwtSecret, { expiresIn: '7d' });
  const refreshToken = jwt.sign(
    { id: user.id },
    env.jwtRefreshSecret,
    { expiresIn: '30d' }
  );
  return { accessToken, refreshToken };
}

export const registerCompany = async (req, res) => {
  try {
    const {
      companyName,
      companyType, // LIMOUSINE or SHIPPING
      contactPerson,
      phone,
      email,
      password,
      address,
    } = req.body;

    if (!companyName || !companyType || !phone || !password) {
      return res
        .status(400)
        .json({ error: 'Company name, type, phone, and password are required' });
    }

    if (!['LIMOUSINE', 'SHIPPING'].includes(companyType)) {
      return res
        .status(400)
        .json({ error: 'Company type must be LIMOUSINE or SHIPPING' });
    }

    const existingUser = await prisma.user.findFirst({
      where: {
        OR: [{ phone }, ...(email ? [{ email }] : [])],
      },
    });

    if (existingUser) {
      return res
        .status(409)
        .json({ error: 'User with this phone or email already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 12);

    const user = await prisma.user.create({
      data: {
        name: contactPerson || companyName,
        phone,
        email: email || null,
        password: hashedPassword,
        role: 'company',
      },
    });

    const company = await prisma.company.create({
      data: {
        userId: user.id,
        companyType,
        companyName,
        companyPhone: phone,
        address: address || '',
        status: 'pending', // Admin must approve
      },
    });

    const tokens = generateTokens(user, company.id, company.companyType);

    res.status(201).json({
      message: 'Company registration successful. Awaiting admin approval.',
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        role: user.role,
      },
      company: {
        id: company.id,
        companyName: company.companyName,
        companyType: company.companyType,
        status: company.status,
      },
      ...tokens,
    });
  } catch (error) {
    console.error('Company Registration Error:', error);
    res.status(500).json({ error: 'Registration failed' });
  }
};

export const companyLogin = async (req, res) => {
  try {
    const { phone, password } = req.body;

    if (!phone || !password) {
      return res
        .status(400)
        .json({ error: 'Phone and password are required' });
    }

    const user = await prisma.user.findUnique({
      where: { phone },
      include: {
        company: true,
      },
    });

    if (!user || user.role !== 'company') {
      return res
        .status(401)
        .json({ error: 'Invalid credentials or not a company account' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    if (user.company.status === 'rejected') {
      return res
        .status(403)
        .json({ error: 'Your company registration has been rejected' });
    }

    const tokens = generateTokens(user, user.company.id, user.company.companyType);

    res.json({
      message: 'Login successful',
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        role: user.role,
      },
      company: {
        id: user.company.id,
        companyName: user.company.companyName,
        companyType: user.company.companyType,
        status: user.company.status,
      },
      ...tokens,
    });
  } catch (error) {
    console.error('Company Login Error:', error);
    res.status(500).json({ error: 'Login failed' });
  }
};

export const getCompanyDashboard = async (req, res) => {
  try {
    const companyId = req.user.companyId;

    const company = await prisma.company.findUnique({
      where: { id: companyId },
      include: {
        orders: {
          select: {
            id: true,
            serviceType: true,
            status: true,
            customerOfferPrice: true,
            companyOfferPrice: true,
            finalPrice: true,
            limousinePickupAddress: true,
            limousineDropoffAddress: true,
            shippingPickupAddress: true,
            shippingDropoffAddress: true,
            createdAt: true,
            updatedAt: true,
            customer: {
              select: {
                id: true,
                name: true,
                phone: true, // Only show if order status is CONFIRMED or later
              },
            },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!company) {
      return res.status(404).json({ error: 'Company not found' });
    }

    const newOrders = await prisma.order.findMany({
      where: {
        companyId: null,
        serviceType: company.companyType,
        status: 'NEW',
      },
      select: {
        id: true,
        serviceType: true,
        status: true,
        customerOfferPrice: true,
        companyOfferPrice: true,
        finalPrice: true,
        limousinePickupAddress: true,
        limousineDropoffAddress: true,
        shippingPickupAddress: true,
        shippingDropoffAddress: true,
        createdAt: true,
        updatedAt: true,
        customer: {
          select: {
            id: true,
            name: true,
            phone: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    // Show only this company's service, including new unassigned orders.
    const orders = [
      ...company.orders.filter((order) => order.serviceType === company.companyType),
      ...newOrders,
    ];

    // Mask customer phone if order is not confirmed
    const processedOrders = orders.map((order) => {
      if (order.status !== 'CONFIRMED' && order.status !== 'COMPLETED' && order.status !== 'CANCELLED') {
        return {
          ...order,
          customer: {
            ...order.customer,
            phone: order.customer.phone
              ? order.customer.phone.slice(0, 3) + '****' + order.customer.phone.slice(-2)
              : null,
          },
        };
      }
      return order;
    });

    // Dashboard stats
    const stats = {
      totalOrders: processedOrders.length,
      newOrders: processedOrders.filter((o) => o.status === 'NEW').length,
      reviewingOrders: processedOrders.filter(
        (o) => o.status === 'COMPANY_REVIEWING'
      ).length,
      acceptedOrders: processedOrders.filter(
        (o) => o.status === 'COMPANY_ACCEPTED'
      ).length,
      confirmedOrders: processedOrders.filter((o) => o.status === 'CONFIRMED')
        .length,
      completedOrders: processedOrders.filter((o) => o.status === 'COMPLETED')
        .length,
    };

    res.json({
      company: {
        id: company.id,
        companyName: company.companyName,
        companyType: company.companyType,
        status: company.status,
      },
      orders: processedOrders,
      stats,
    });
  } catch (error) {
    console.error('Get Company Dashboard Error:', error);
    res.status(500).json({ error: 'Failed to fetch dashboard' });
  }
};

export const getCompanyOrders = async (req, res) => {
  try {
    const companyId = req.user.companyId;
    const { status } = req.query;

    const company = await prisma.company.findUnique({
      where: { id: companyId },
    });

    if (!company) {
      return res.status(404).json({ error: 'Company not found' });
    }

    const filters = {
      OR: [
        {
          companyId: companyId,
          serviceType: company.companyType,
        }, // Orders assigned to this company
        {
          AND: [
            { companyId: null }, // Orders not yet assigned to a company
            { serviceType: company.companyType },
            { status: 'NEW' }, // New orders for this company type
          ],
        },
      ],
    };

    if (status) {
      filters.status = status;
    }

    const orders = await prisma.order.findMany({
      where: filters,
      include: {
        customer: {
          select: {
            id: true,
            name: true,
            phone: true,
          },
        },
        priceOffers: {
          orderBy: { createdAt: 'desc' },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    // Mask sensitive customer data
    const processedOrders = orders.map((order) => {
      if (order.status !== 'CONFIRMED' && order.status !== 'COMPLETED' && order.status !== 'CANCELLED') {
        return {
          ...order,
          customer: {
            ...order.customer,
            phone: order.customer.phone
              ? order.customer.phone.slice(0, 3) + '****' + order.customer.phone.slice(-2)
              : null,
          },
        };
      }
      return order;
    });

    res.json({ orders: processedOrders });
  } catch (error) {
    console.error('Get Company Orders Error:', error);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
};

export const reviewOrder = async (req, res) => {
  try {
    const { orderId } = req.params;
    const companyId = req.user.companyId;

    const order = await prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }

    if (order.serviceType === 'LIMOUSINE') {
      // Check if this is a limousine company
      const company = await prisma.company.findUnique({
        where: { id: companyId },
      });
      if (company.companyType !== 'LIMOUSINE') {
        return res
          .status(403)
          .json({ error: 'You can only access limousine orders' });
      }
    } else if (order.serviceType === 'SHIPPING') {
      // Check if this is a shipping company
      const company = await prisma.company.findUnique({
        where: { id: companyId },
      });
      if (company.companyType !== 'SHIPPING') {
        return res
          .status(403)
          .json({ error: 'You can only access shipping orders' });
      }
    }

    // Update order status to COMPANY_REVIEWING
    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'COMPANY_REVIEWING',
        companyId: companyId,
      },
      include: {
        customer: {
          select: {
            id: true,
            name: true,
            phone: true,
          },
        },
      },
    });

    // Mask phone
    const processedOrder = {
      ...updatedOrder,
      customer: {
        ...updatedOrder.customer,
        phone: updatedOrder.customer.phone
          ? updatedOrder.customer.phone.slice(0, 3) + '****' + updatedOrder.customer.phone.slice(-2)
          : null,
      },
    };

    res.json({
      message: 'Order marked as reviewing',
      order: processedOrder,
    });
  } catch (error) {
    console.error('Review Order Error:', error);
    res.status(500).json({ error: 'Failed to review order' });
  }
};

export const acceptOrder = async (req, res) => {
  try {
    const { orderId } = req.params;
    const companyId = req.user.companyId;

    const order = await prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }

    if (order.companyId !== companyId) {
      return res
        .status(403)
        .json({ error: 'You do not have access to this order' });
    }

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'COMPANY_ACCEPTED',
        finalPrice: order.customerOfferPrice,
      },
      include: {
        customer: true,
      },
    });

    // Create notification for customer
    await prisma.notification.create({
      data: {
        userId: updatedOrder.customerId,
        title: 'Order Accepted',
        body: `Your ${updatedOrder.serviceType.toLowerCase()} order has been accepted at ${updatedOrder.customerOfferPrice} EGP`,
        type: 'order_accepted',
        orderId: orderId,
      },
    });

    emitOrderStatusChanged({
      orderId,
      status: 'COMPANY_ACCEPTED',
      price: updatedOrder.finalPrice,
    });

    res.json({
      message: 'Order accepted',
      order: updatedOrder,
    });
  } catch (error) {
    console.error('Accept Order Error:', error);
    res.status(500).json({ error: 'Failed to accept order' });
  }
};

export const rejectOrder = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { reason } = req.body;
    const companyId = req.user.companyId;

    const order = await prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }

    if (order.companyId !== companyId) {
      return res
        .status(403)
        .json({ error: 'You do not have access to this order' });
    }

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'COMPANY_REJECTED',
        rejectionReason: reason || null,
      },
    });

    // Create notification for customer
    await prisma.notification.create({
      data: {
        userId: updatedOrder.customerId,
        title: 'Order Rejected',
        body: `Your ${updatedOrder.serviceType.toLowerCase()} order has been rejected${reason ? ': ' + reason : ''}`,
        type: 'order_rejected',
        orderId: orderId,
      },
    });

    res.json({
      message: 'Order rejected',
      order: updatedOrder,
    });
  } catch (error) {
    console.error('Reject Order Error:', error);
    res.status(500).json({ error: 'Failed to reject order' });
  }
};

export const sendCounterOffer = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { offeredPrice } = req.body;
    const companyId = req.user.companyId;

    if (!offeredPrice || offeredPrice <= 0) {
      return res.status(400).json({ error: 'Valid offered price is required' });
    }

    const order = await prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }

    if (order.companyId !== companyId) {
      return res
        .status(403)
        .json({ error: 'You do not have access to this order' });
    }

    // Create price offer
    const priceOffer = await prisma.priceOffer.create({
      data: {
        orderId,
        customerId: order.customerId,
        companyId,
        offeredPrice,
        sentBy: 'COMPANY',
      },
    });

    // Update order status to PRICE_SENT
    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'PRICE_SENT',
        companyOfferPrice: offeredPrice,
      },
    });

    // Create notification for customer
    await prisma.notification.create({
      data: {
        userId: order.customerId,
        title: 'Price Offer',
        body: `Offered price for your ${order.serviceType.toLowerCase()} order: ${offeredPrice} EGP`,
        type: 'price_offer',
        orderId: orderId,
      },
    });

    emitOrderStatusChanged({ orderId, status: 'PRICE_SENT', price: offeredPrice });

    res.json({
      message: 'Counter offer sent',
      priceOffer,
      order: updatedOrder,
    });
  } catch (error) {
    console.error('Send Counter Offer Error:', error);
    res.status(500).json({ error: 'Failed to send counter offer' });
  }
};
