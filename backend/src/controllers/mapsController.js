import { getGoogleDirections } from '../services/mapsService.js';
import logger from '../utils/logger.js';

export const getDirections = async (req, res) => {
  try {
    const route = await getGoogleDirections({
      origin: req.query.origin,
      destination: req.query.destination,
    });
    return res.json({ route });
  } catch (error) {
    logger.error('Google Maps directions failed', { error: error.message, stack: error.stack });
    return res.status(400).json({ error: error.message });
  }
};