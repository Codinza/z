import { prisma } from '../db/prisma.js';
import logger from '../utils/logger.js';

function serializeTicket(ticket) {
  if (!ticket) return null;
  return {
    id: ticket.id,
    name: ticket.name,
    email: ticket.email || '',
    phone: ticket.phone || '',
    message: ticket.message,
    userId: ticket.userId,
    role: ticket.role || 'customer',
    status: ticket.status,
    adminReply: ticket.adminReply,
    createdAt: ticket.createdAt?.toISOString?.() || ticket.createdAt,
    updatedAt: ticket.updatedAt?.toISOString?.() || ticket.updatedAt,
  };
}

class SupportService {
  async createTicket({ name, email, phone = '', message, userId = null, role = 'customer' }) {
    const ticket = await prisma.supportTicket.create({
      data: {
        name: name || 'مستخدم',
        email: email || '',
        phone: phone || '',
        message: message || '',
        userId: userId || null,
        role: role || 'customer',
        status: 'OPEN',
      },
    });
    logger.info('Support ticket created', { ticketId: ticket.id, name: ticket.name });
    return serializeTicket(ticket);
  }

  async getTickets({ status = null, search = '' } = {}) {
    const where = {};

    if (status && status !== 'ALL') {
      where.status = String(status).toUpperCase();
    }

    if (search && search.trim().length > 0) {
      const q = search.trim();
      where.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q, mode: 'insensitive' } },
        { email: { contains: q, mode: 'insensitive' } },
        { message: { contains: q, mode: 'insensitive' } },
      ];
    }

    const tickets = await prisma.supportTicket.findMany({
      where,
      orderBy: { createdAt: 'desc' },
    });

    return tickets.map(serializeTicket);
  }

  async updateTicket(id, { status, adminReply }) {
    const data = {};
    if (status) data.status = String(status).toUpperCase();
    if (adminReply !== undefined) data.adminReply = adminReply;

    try {
      const updated = await prisma.supportTicket.update({
        where: { id },
        data,
      });
      return serializeTicket(updated);
    } catch (error) {
      if (error?.code === 'P2025') return null;
      throw error;
    }
  }

  async getStats() {
    const [total, open, resolved] = await Promise.all([
      prisma.supportTicket.count(),
      prisma.supportTicket.count({ where: { status: 'OPEN' } }),
      prisma.supportTicket.count({ where: { status: 'RESOLVED' } }),
    ]);
    return { total, open, resolved };
  }
}

export const supportService = new SupportService();
