const toRadians = (deg) => (deg * Math.PI) / 180;

// Approximate mainland Egypt bounds used to keep service operations in Egypt.
export function isWithinEgypt(lat, lng) {
  const latitude = Number(lat);
  const longitude = Number(lng);
  return Number.isFinite(latitude) && Number.isFinite(longitude) &&
    latitude >= 22 && latitude <= 31.7 &&
    longitude >= 24 && longitude <= 37;
}

export async function getGoogleDirections({ origin, destination }) {
  if (!origin || !destination) {
    throw new Error('Origin and destination are required');
  }

  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (!apiKey) {
    throw new Error('Google Maps API key is not configured');
  }

  const params = new URLSearchParams({
    origin,
    destination,
    key: apiKey,
    language: 'ar',
  });
  const response = await fetch(`https://maps.googleapis.com/maps/api/directions/json?${params}`);
  if (!response.ok) {
    throw new Error(`Google Maps request failed with status ${response.status}`);
  }

  const data = await response.json();
  if (data.status !== 'OK' || !data.routes?.[0]?.legs?.[0]) {
    throw new Error(`Google Maps directions failed: ${data.status || 'UNKNOWN_ERROR'}`);
  }

  const leg = data.routes[0].legs[0];
  return {
    distanceMeters: leg.distance.value,
    distanceText: leg.distance.text,
    durationSeconds: leg.duration.value,
    durationText: leg.duration.text,
    polyline: data.routes[0].overview_polyline?.points || null,
    startLocation: leg.start_location,
    endLocation: leg.end_location,
  };
}

export function calculateDistanceKm({ pickupLat, pickupLng, dropoffLat, dropoffLng }) {
  const earthRadiusKm = 6371;
  const dLat = toRadians(dropoffLat - pickupLat);
  const dLng = toRadians(dropoffLng - pickupLng);

  const lat1 = toRadians(pickupLat);
  const lat2 = toRadians(dropoffLat);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLng / 2) * Math.sin(dLng / 2) * Math.cos(lat1) * Math.cos(lat2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Number((earthRadiusKm * c).toFixed(2));
}

export function estimateFare(distanceKm, surgeMultiplier = 1.0) {
  const baseFare = 15; // 15 EGP base fare
  const perKm = 6;     // 6 EGP per km
  const surge = surgeMultiplier;
  return Number((baseFare + distanceKm * perKm * surge).toFixed(2));
}

export function calculateDriverOffer(baseFare, distanceKm, driverRating = 4.5) {
  // inDrive-style: drivers can offer prices based on their rating and demand
  const ratingBonus = (driverRating - 4.0) * 0.5; // Higher rated drivers can charge more
  const minOffer = baseFare * 0.8; // Can offer up to 20% discount
  const maxOffer = baseFare * 1.3; // Can charge up to 30% premium
  
  const offer = baseFare + ratingBonus + (Math.random() * 2 - 1); // Small random variation
  
  return Number(Math.max(minOffer, Math.min(maxOffer, offer)).toFixed(2));
}

export function getSurgeMultiplier(hour, dayOfWeek) {
  // Simple surge pricing based on time
  const rushHours = [7, 8, 9, 17, 18, 19, 20]; // Morning and evening rush
  const weekend = dayOfWeek === 0 || dayOfWeek === 6;
  
  if (rushHours.includes(hour)) {
    return weekend ? 1.5 : 1.3;
  }
  
  if (hour >= 22 || hour <= 5) {
    return 1.4; // Night surge
  }
  
  return 1.0; // Normal rate
}
