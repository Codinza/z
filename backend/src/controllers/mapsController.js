import { getGoogleDirections } from '../services/mapsService.js';

export const getDirections = async (req, res) => {
  try {
    const route = await getGoogleDirections({
      origin: req.query.origin,
      destination: req.query.destination,
    });
    return res.json({ route });
  } catch (error) {
    console.error('Google Maps directions error:', error);
    return res.status(400).json({ error: error.message });
  }
};