import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

export const getNotifications = async (req, res) => {
  try {
    // Use authenticated user ID from JWT, fallback to query for backward compatibility
    const userId = req.user?.id || req.query.userId;
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    const notifications = await prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });

    res.json(notifications);
  } catch (error) {
    console.error('Get Notifications Error:', error);
    res.status(500).json({ error: 'Failed to fetch notifications' });
  }
};

export const markAsRead = async (req, res) => {
  try {
    const { id } = req.params;
    const notification = await prisma.notification.update({
      where: { id },
      data: { isRead: true },
    });
    res.json(notification);
  } catch (error) {
    console.error('Mark Notification Read Error:', error);
    res.status(500).json({ error: 'Failed to update notification' });
  }
};

export const createNotification = async (req, res) => {
  try {
    const { userId, title, body, type } = req.body;
    const notification = await prisma.notification.create({
      data: {
        userId,
        title,
        body,
        type: type || 'system',
      },
    });
    
    // In future: push to FCM/APNs here
    
    res.status(201).json(notification);
  } catch (error) {
    console.error('Create Notification Error:', error);
    res.status(500).json({ error: 'Failed to create notification' });
  }
};
