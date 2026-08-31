import { Router } from 'express';
import { getNotifications, markAsRead, createNotification } from '../controllers/notificationController.js';

const router = Router();

export const notificationRoutes = () => {
  router.get('/', getNotifications);
  router.post('/', createNotification);
  router.put('/:id/read', markAsRead);
  return router;
};
