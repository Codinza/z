import { PrismaClient } from '@prisma/client';
import { env } from '../config/env.js';
import logger from '../utils/logger.js';
const prisma = new PrismaClient();

export const createPaymobCheckout = async (req, res) => {
  try {
    const { tripId, amount, paymentMethod, userId } = req.body;
    const integrationId = env.paymobIntegrationId;

    if (!env.paymobApiKey || !integrationId) {
      return res.status(503).json({
        error: 'Paymob is not configured. Add PAYMOB_API_KEY and PAYMOB_INTEGRATION_ID to backend/.env',
      });
    }

    if (!tripId || !Number.isFinite(Number(amount)) || Number(amount) <= 0) {
      return res.status(400).json({ error: 'tripId and a valid amount are required' });
    }

    const trip = await prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip) return res.status(404).json({ error: 'Trip not found' });

    const authResponse = await fetch('https://accept.paymob.com/api/auth/tokens', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ api_key: env.paymobApiKey }),
    });
    if (!authResponse.ok) throw new Error('Paymob authentication failed');
    const { token } = await authResponse.json();

    const amountCents = Math.round(Number(amount) * 100);
    const orderResponse = await fetch('https://accept.paymob.com/api/ecommerce/orders', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        auth_token: token,
        delivery_needed: false,
        amount_cents: amountCents,
        currency: 'EGP',
        merchant_order_id: tripId,
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
        integration_id: Number(integrationId),
        lock_order_when_paid: true,
        billing_data: {
          first_name: 'RideFlow',
          last_name: 'Customer',
          email: 'customer@rideflow.local',
          phone_number: '+201000000000',
          apartment: 'NA',
          floor: 'NA',
          street: 'NA',
          building: 'NA',
          shipping_method: 'NA',
          postal_code: 'NA',
          city: 'Cairo',
          country: 'EGY',
          state: 'Cairo',
        },
      }),
    });
    if (!keyResponse.ok) throw new Error('Paymob payment key creation failed');
    const { token: paymentToken } = await keyResponse.json();

    const payment = await prisma.payment.upsert({
      where: { tripId },
      update: { amount: Number(amount), paymentMethod, status: 'pending' },
      create: {
        tripId,
        userId: userId || trip.userId,
        amount: Number(amount),
        paymentMethod,
        status: 'pending',
      },
    });

    res.status(201).json({
      payment,
      checkoutUrl: `https://accept.paymob.com/unifiedcheckout/?payment_token=${encodeURIComponent(paymentToken)}`,
    });
  } catch (error) {
    logger.error('Paymob checkout failed', { error: error.message, stack: error.stack });
    res.status(502).json({ error: 'Unable to create Paymob checkout session' });
  }
};

export const createPayment = async (req, res) => {
  try {
    const { tripId, amount, paymentMethod } = req.body;
    const userId = req.user?.id || req.body.userId;
    
    // Check if trip exists
    const trip = await prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Upsert to handle retries seamlessly
    const payment = await prisma.payment.upsert({
      where: { tripId },
      update: {
        amount,
        paymentMethod,
        status: 'completed',
      },
      create: {
        tripId,
        userId,
        amount,
        paymentMethod,
        status: 'completed',
      },
    });

    res.status(201).json(payment);
  } catch (error) {
    logger.error('Create payment failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to process payment' });
  }
};

export const getPaymentByTrip = async (req, res) => {
  try {
    const { tripId } = req.params;
    const payment = await prisma.payment.findUnique({
      where: { tripId },
    });
    
    if (!payment) {
      return res.status(404).json({ error: 'Payment not found' });
    }
    
    res.json(payment);
  } catch (error) {
    logger.error('Get payment failed', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Failed to fetch payment details' });
  }
};
