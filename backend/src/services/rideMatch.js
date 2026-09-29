export function normalizeRideClass(ride) {
  const explicit = String(ride?.rideClass || '').toLowerCase();
  if (explicit === 'comfort' || explicit === 'travel' || explicit === 'standard') {
    return explicit;
  }
  if (String(ride?.tripType || '').toLowerCase() === 'intercity') return 'travel';
  return 'standard';
}

export function normalizeRideTier(tier) {
  return String(tier || '').toLowerCase() === 'comfort' ? 'comfort' : 'standard';
}

/** Comfort car drivers take every car order. Standard drivers take standard city orders only. */
export function driverMatchesRide(ride, vehicleCategory, rideTier) {
  const vehicle = String(ride?.vehicleType || 'car').toLowerCase() === 'motorcycle'
    ? 'motorcycle'
    : 'car';
  const category = String(vehicleCategory || 'car').toLowerCase() === 'motorcycle'
    ? 'motorcycle'
    : 'car';
  if (vehicle === 'motorcycle') return category === 'motorcycle';
  if (category !== 'car') return false;
  if (normalizeRideTier(rideTier) === 'comfort') return true;
  return normalizeRideClass(ride) === 'standard';
}
