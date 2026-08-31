import { Router } from 'express';
import { getPageContent, submitContactMessage } from '../controllers/settingsController.js';

const router = Router();

export const settingsRoutes = () => {
  router.get('/pages/:pageId', getPageContent);
  router.post('/contact', submitContactMessage);
  return router;
};
