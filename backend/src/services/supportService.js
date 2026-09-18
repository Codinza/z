import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import logger from '../utils/logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const STORAGE_FILE = path.join(__dirname, '../../data/support_tickets.json');

class SupportService {
  constructor() {
    this.tickets = [];
    this._load();
  }

  _load() {
    try {
      const dir = path.dirname(STORAGE_FILE);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      if (fs.existsSync(STORAGE_FILE)) {
        const raw = fs.readFileSync(STORAGE_FILE, 'utf8');
        this.tickets = JSON.parse(raw);
      } else {
        // Seed with sample tickets if empty
        this.tickets = [
          {
            id: 'ticket_sample_001',
            name: 'محمود عبد الرحيم',
            email: 'mahmoud@gmail.com',
            phone: '01012345678',
            message: 'واجهت مشكلة أثناء دفع الأجرة كاش وتم احتساب الخصم مرتين.',
            status: 'OPEN',
            adminReply: null,
            createdAt: new Date(Date.now() - 3600000 * 3).toISOString(),
            updatedAt: new Date(Date.now() - 3600000 * 3).toISOString(),
          },
          {
            id: 'ticket_sample_002',
            name: 'كابتن هاني سيد',
            email: 'captain.hany@gmail.com',
            phone: '01198765432',
            message: 'أرغب في تحديث رقم لوحة سيارتي في التطبيق لو سمحت.',
            status: 'RESOLVED',
            adminReply: 'تم تحديث بيانات سيارتك بنجاح كابتن هاني. نتمنى لك رحلات موفقة!',
            createdAt: new Date(Date.now() - 86400000).toISOString(),
            updatedAt: new Date(Date.now() - 80000000).toISOString(),
          },
        ];
        this._save();
      }
    } catch (e) {
      logger.warn('Failed to load support tickets from disk, starting empty', { error: e.message });
      this.tickets = [];
    }
  }

  _save() {
    try {
      const dir = path.dirname(STORAGE_FILE);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      fs.writeFileSync(STORAGE_FILE, JSON.stringify(this.tickets, null, 2), 'utf8');
    } catch (e) {
      logger.error('Failed to save support tickets to disk', { error: e.message });
    }
  }

  createTicket({ name, email, phone = '', message, userId = null, role = 'customer' }) {
    const ticket = {
      id: `ticket_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      name: name || 'مستخدم',
      email: email || '',
      phone: phone || '',
      message: message || '',
      userId,
      role,
      status: 'OPEN', // OPEN, RESOLVED, CLOSED
      adminReply: null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    this.tickets.unshift(ticket);
    this._save();
    logger.info('Support ticket created', { ticketId: ticket.id, name: ticket.name });
    return ticket;
  }

  getTickets({ status = null, search = '' } = {}) {
    let list = [...this.tickets];

    if (status && status !== 'ALL') {
      list = list.filter((t) => t.status === status);
    }

    if (search && search.trim().length > 0) {
      const q = search.trim().toLowerCase();
      list = list.filter(
        (t) =>
          (t.name && t.name.toLowerCase().includes(q)) ||
          (t.phone && t.phone.toLowerCase().includes(q)) ||
          (t.email && t.email.toLowerCase().includes(q)) ||
          (t.message && t.message.toLowerCase().includes(q))
      );
    }

    return list;
  }

  updateTicket(id, { status, adminReply }) {
    const index = this.tickets.findIndex((t) => t.id === id);
    if (index === -1) return null;

    if (status) this.tickets[index].status = status;
    if (adminReply !== undefined) this.tickets[index].adminReply = adminReply;
    this.tickets[index].updatedAt = new Date().toISOString();

    this._save();
    return this.tickets[index];
  }

  getStats() {
    const total = this.tickets.length;
    const open = this.tickets.filter((t) => t.status === 'OPEN').length;
    const resolved = this.tickets.filter((t) => t.status === 'RESOLVED').length;
    return { total, open, resolved };
  }
}

export const supportService = new SupportService();
