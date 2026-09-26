import { PrismaClient } from '@prisma/client';
import { emitOrderStatusChanged, tripService } from '../services/tripService.js';
import { isWithinEgypt } from '../services/mapsService.js';
import logger from '../utils/logger.js';
const prisma = new PrismaClient();

export const createLimousineOrder = async (req, res) => {
  try {
    const {
      pickupAddress,
      pickupLat,
      pickupLng,
      dropoffAddress,
      dropoffLat,
      dropoffLng,
      passengerCount,
      date,
      time,
      notes,
      offerPrice,
    } = req.body;

    const customerId = req.user?.id;

    if (!customerId) {
      return res.status(401).json({ error: 'User authentication required' });
    }

    if (!pickupAddress || !dropoffAddress || !offerPrice) {
      return res.status(400).json({
        error: 'Pickup address, dropoff address, and offer price are required',
      });
    }

    if (!isWithinEgypt(pickupLat, pickupLng) ||
        !isWithinEgypt(dropoffLat, dropoffLng)) {
      return res.status(400).json({ error: 'الخدمة متاحة داخل مصر فقط' });
    }

    const order = await prisma.order.create({
      data: {
        customerId,
        serviceType: 'LIMOUSINE',
        status: 'NEW',
        customerOfferPrice: parseFloat(offerPrice),
        limousinePickupAddress: pickupAddress,
        limousinePickupLat: Number.isFinite(Number(pickupLat)) ? Number(pickupLat) : null,
        limousinePickupLng: Number.isFinite(Number(pickupLng)) ? Number(pickupLng) : null,
        limousineDropoffAddress: dropoffAddress,
        limousineDropoffLat: Number.isFinite(Number(dropoffLat)) ? Number(dropoffLat) : null,
        limousineDropoffLng: Number.isFinite(Number(dropoffLng)) ? Number(dropoffLng) : null,
        limousinePassengerCount: parseInt(passengerCount) || 1,
        limousineDateTime: date && time ? new Date(`${date}T${time}`) : null,
        limousineNotes: notes || null,
        customerContactVisible: false,
      },
      include: {
        customer: true,
      },
    });

    // Create notification for all limousine companies
    const limousineCompanies = await prisma.company.findMany({
      where: {
        companyType: 'LIMOUSINE',
        status: 'active',
      },
    });

    for (const company of limousineCompanies) {
      await prisma.notification.create({
        data: {
          companyId: company.id,
          title: 'New Limousine Order',
          body: `New order received. Offered price: ${offerPrice} EGP`,
          type: 'new_order',
          orderId: order.id,
        },
      });
    }

    // Customer notification
    await prisma.notification.create({
      data: {
        userId: customerId,
        title: 'Order Created',
        body: `Your limousine order has been created and sent to companies`,
        type: 'order_created',
        orderId: order.id,
      },
    });

    res.status(201).json({
      message: 'Limousine order created successfully',
      order: {
        id: order.id,
        serviceType: order.serviceType,
        status: order.status,
        customerOfferPrice: order.customerOfferPrice,
        createdAt: order.createdAt,
      },
    });
  } catch (error) {
    logger.error('Create limousine order failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to create order' });
  }
};

export const createShippingOrder = async (req, res) => {
  try {
    const {
      pickupAddress,
      pickupLat,
      pickupLng,
      dropoffAddress,
      dropoffLat,
      dropoffLng,
      shipmentDetails,
      shipmentType,
      shippingSize,
      shippingImageBase64,
      date,
      time,
      notes,
      offerPrice,
    } = req.body;

    const customerId = req.user?.id;

    if (!customerId) {
      return res.status(401).json({ error: 'User authentication required' });
    }

    if (!pickupAddress || !dropoffAddress || !offerPrice) {
      return res.status(400).json({
        error: 'Pickup address, dropoff address, and offer price are required',
      });
    }

    if (!isWithinEgypt(pickupLat, pickupLng) ||
        !isWithinEgypt(dropoffLat, dropoffLng)) {
      return res.status(400).json({ error: 'الخدمة متاحة داخل مصر فقط' });
    }

    const order = await prisma.order.create({
      data: {
        customerId,
        serviceType: 'SHIPPING',
        status: 'NEW',
        customerOfferPrice: parseFloat(offerPrice),
        shippingPickupAddress: pickupAddress,
        shippingPickupLat: Number.isFinite(Number(pickupLat)) ? Number(pickupLat) : null,
        shippingPickupLng: Number.isFinite(Number(pickupLng)) ? Number(pickupLng) : null,
        shippingDropoffAddress: dropoffAddress,
        shippingDropoffLat: Number.isFinite(Number(dropoffLat)) ? Number(dropoffLat) : null,
        shippingDropoffLng: Number.isFinite(Number(dropoffLng)) ? Number(dropoffLng) : null,
        shippingDetails: shipmentDetails || null,
        shippingType: shipmentType || null,
        shippingSize: shippingSize || null,
        shippingImageBase64: shippingImageBase64 || null,
        shippingDateTime: date && time ? new Date(`${date}T${time}`) : null,
        shippingNotes: notes || null,
        customerContactVisible: false,
      },
      include: {
        customer: true,
      },
    });

    // Create notification for all shipping companies
    const shippingCompanies = await prisma.company.findMany({
      where: {
        companyType: 'SHIPPING',
        status: 'active',
      },
    });

    for (const company of shippingCompanies) {
      await prisma.notification.create({
        data: {
          companyId: company.id,
          title: 'New Shipping Order',
          body: `New order received. Offered price: ${offerPrice} EGP`,
          type: 'new_order',
          orderId: order.id,
        },
      });
    }

    // Customer notification
    await prisma.notification.create({
      data: {
        userId: customerId,
        title: 'Order Created',
        body: `Your shipping order has been created and sent to companies`,
        type: 'order_created',
        orderId: order.id,
      },
    });

    emitOrderStatusChanged({
      orderId: order.id,
      status: 'NEW_SHIPPING_ORDER',
      customerId,
      price: order.customerOfferPrice,
    });

    res.status(201).json({
      message: 'Shipping order created successfully',
      order: {
        id: order.id,
        serviceType: order.serviceType,
        status: order.status,
        customerOfferPrice: order.customerOfferPrice,
        createdAt: order.createdAt,
      },
    });
  } catch (error) {
    logger.error('Create shipping order failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to create order' });
  }
};

export const getCustomerOrders = async (req, res) => {
  try {
    const customerId = req.user?.id;

    if (!customerId) {
      return res.status(401).json({ error: 'User authentication required' });
    }

    const orders = await prisma.order.findMany({
      where: { customerId },
      include: {
        company: {
          select: {
            id: true,
            companyName: true,
            companyType: true,
          },
        },
        priceOffers: {
          orderBy: { createdAt: 'desc' },
          include: {
            company: { select: { id: true, companyName: true, companyType: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    res.json({ orders });
  } catch (error) {
    logger.error('Get customer orders failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
};

export const getOrderDetails = async (req, res) => {
  try {
    const { id: orderId } = req.params;
    const userId = req.user?.id;

    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: {
        customer: {
          select: {
            id: true,
            name: true,
            phone: true,
            email: true,
          },
        },
        company: {
          select: {
            id: true,
            companyName: true,
            companyType: true,
          },
        },
        priceOffers: {
          orderBy: { createdAt: 'desc' },
          include: {
            company: { select: { id: true, companyName: true, companyType: true } },
          },
        },
        payment: true,
      },
    });

    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }

    // Check access - customer or associated company or super admin
    if (order.customerId !== userId && req.user?.role !== 'super_admin') {
      if (req.user?.companyId !== order.companyId) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }

    // Mask sensitive data unless the deal is confirmed or contact was unlocked.
    let processedOrder = { ...order };
    const canSeePhone =
      order.customerId === userId ||
      order.customerContactVisible === true ||
      order.status === 'CONFIRMED' ||
      order.status === 'COMPLETED' ||
      req.user?.role === 'super_admin' ||
      req.user?.role === 'admin';

    if (!canSeePhone && processedOrder.customer) {
      processedOrder = {
        ...processedOrder,
        customer: {
          ...processedOrder.customer,
          phone: order.customer.phone
            ? order.customer.phone.slice(0, 3) + '****' + order.customer.phone.slice(-2)
            : null,
        },
      };
    }

    res.json({ order: processedOrder });
  } catch (error) {
    logger.error('Get order details failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch order' });
  }
};

export const approveCustomerPrice = async (req, res) => {
  try {
    const orderId = req.params.orderId || req.params.id;
    const customerId = req.user?.id;

    if (!customerId) {
      return res.status(401).json({ error: 'User authentication required' });
    }

    const order = await prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }

    if (order.customerId !== customerId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    if (order.status !== 'PRICE_SENT') {
      return res
        .status(400)
        .json({ error: 'Order must be in PRICE_SENT status' });
    }

    const offerAgeMs = Date.now() - new Date(order.updatedAt).getTime();
    if (offerAgeMs > 10 * 60 * 1000) {
      await prisma.order.update({
        where: { id: orderId },
        data: {
          status: 'CUSTOMER_REJECTED',
          rejectionReason: 'انتهت مهلة العرض',
        },
      });
      return res.status(400).json({ error: 'انتهت مهلة العرض' });
    }

    // Customer accepted the company counter-offer — deal is closed.
    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'CONFIRMED',
        customerContactVisible: true,
        finalPrice: order.companyOfferPrice,
      },
    });

    // Create notification for company
    if (order.companyId) {
      await prisma.notification.create({
        data: {
          companyId: order.companyId,
          title: 'Price Approved',
          body: `Customer approved the offered price of ${order.companyOfferPrice} EGP`,
          type: 'price_approved',
          orderId: orderId,
        },
      });
    }

    emitOrderStatusChanged({
      orderId,
      status: 'CONFIRMED',
      price: updatedOrder.finalPrice,
    });

    if (String(order.serviceType || '').toUpperCase() === 'SHIPPING') {
      try {
        await tripService.createTripRequest({
          pickupAddress: order.shippingPickupAddress,
          dropoffAddress: order.shippingDropoffAddress,
          pickupLat: order.shippingPickupLat,
          pickupLng: order.shippingPickupLng,
          dropoffLat: order.shippingDropoffLat,
          dropoffLng: order.shippingDropoffLng,
          userId: order.customerId,
          proposedFare: order.companyOfferPrice,
          vehicleType: 'car',
          tripType: 'shipping',
          notes: `شحن ${order.shippingSize || ''} ${order.shippingType || ''}`.trim(),
        });
      } catch (err) {
        logger.warn('Shipping trip was not broadcast to captains', { error: err.message });
      }
    }

    res.json({
      message: 'Price approved and order confirmed',
      order: updatedOrder,
    });
  } catch (error) {
    logger.error('Approve customer price failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to approve price' });
  }
};

export const rejectCustomerPrice = async (req, res) => {
  try {
    const orderId = req.params.orderId || req.params.id;
    const { reason } = req.body;
    const customerId = req.user?.id;

    if (!customerId) {
      return res.status(401).json({ error: 'User authentication required' });
    }

    const order = await prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }

    if (order.customerId !== customerId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    if (order.status !== 'PRICE_SENT') {
      return res
        .status(400)
        .json({ error: 'Order must be in PRICE_SENT status' });
    }

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'CUSTOMER_REJECTED',
        rejectionReason: reason || 'Customer rejected price',
      },
    });

    // Create notification for company
    if (order.companyId) {
      await prisma.notification.create({
        data: {
          companyId: order.companyId,
          title: 'Price Rejected',
          body: `Customer rejected the offered price${reason ? ': ' + reason : ''}`,
          type: 'price_rejected',
          orderId: orderId,
        },
      });
    }

    emitOrderStatusChanged({
      orderId,
      status: 'CUSTOMER_REJECTED',
      reason: reason || 'Customer rejected price',
    });

    res.json({
      message: 'Price rejected',
      order: updatedOrder,
    });
  } catch (error) {
    logger.error('Reject customer price failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to reject price' });
  }
};

export const confirmOrder = async (req, res) => {
  try {
    const orderId = req.params.orderId || req.params.id;
    const userId = req.user?.id;
    const role = req.user?.role;
    const companyId = req.user?.companyId;

    const order = await prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }

    const isAdmin = role === 'super_admin' || role === 'admin';
    const isCustomer = order.customerId === userId;
    const isAssignedCompany = companyId && order.companyId === companyId;

    if (!isAdmin && !isCustomer && !isAssignedCompany) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Recover stuck legacy states and close the deal.
    const confirmable = ['CUSTOMER_APPROVED', 'COMPANY_ACCEPTED'];
    if (!confirmable.includes(order.status)) {
      return res.status(400).json({
        error: 'Order must be in CUSTOMER_APPROVED or COMPANY_ACCEPTED status',
      });
    }

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'CONFIRMED',
        customerContactVisible: true,
        finalPrice:
          order.finalPrice ??
          order.companyOfferPrice ??
          order.customerOfferPrice,
      },
    });

    await prisma.notification.create({
      data: {
        userId: order.customerId,
        title: 'Order Confirmed',
        body: `Your ${order.serviceType.toLowerCase()} order has been confirmed. Final price: ${updatedOrder.finalPrice} EGP`,
        type: 'order_confirmed',
        orderId: orderId,
      },
    });

    emitOrderStatusChanged({
      orderId,
      status: 'CONFIRMED',
      price: updatedOrder.finalPrice,
    });

    res.json({
      message: 'Order confirmed',
      order: updatedOrder,
    });
  } catch (error) {
    logger.error('Confirm order failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to confirm order' });
  }
};

export const completeOrder = async (req, res) => {
  try {
    const orderId = req.params.orderId || req.params.id;
    const companyId = req.user?.companyId;

    if (!companyId) {
      return res.status(401).json({ error: 'Company authentication required' });
    }

    const order = await prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }

    if (order.companyId !== companyId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    if (order.status !== 'CONFIRMED') {
      return res
        .status(400)
        .json({ error: 'Order must be in CONFIRMED status' });
    }

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'COMPLETED',
      },
    });

    // Create notification for customer
    await prisma.notification.create({
      data: {
        userId: order.customerId,
        title: 'Order Completed',
        body: `Your ${order.serviceType.toLowerCase()} order has been completed`,
        type: 'order_completed',
        orderId: orderId,
      },
    });

    emitOrderStatusChanged({
      orderId,
      status: 'COMPLETED',
    });

    res.json({
      message: 'Order completed',
      order: updatedOrder,
    });
  } catch (error) {
    logger.error('Complete order failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to complete order' });
  }
};

export const cancelOrder = async (req, res) => {
  try {
    const orderId = req.params.orderId || req.params.id;
    const { reason } = req.body;
    const userId = req.user?.id;

    const order = await prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }

    // Only customer can cancel
    if (order.customerId !== userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'CANCELLED',
        rejectionReason: reason || null,
      },
    });

    // Create notification for company if assigned
    if (order.companyId) {
      await prisma.notification.create({
        data: {
          companyId: order.companyId,
          title: 'Order Cancelled',
          body: `Order cancelled by customer${reason ? ': ' + reason : ''}`,
          type: 'order_cancelled',
          orderId: orderId,
        },
      });
    }

    emitOrderStatusChanged({
      orderId,
      status: 'CANCELLED',
      reason: reason || null,
    });

    res.json({
      message: 'Order cancelled',
      order: updatedOrder,
    });
  } catch (error) {
    logger.error('Cancel order failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to cancel order' });
  }
};
