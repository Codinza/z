import 'dotenv/config';

export const config = {
  port: Number(process.env.PORT || 4000),
  nodeEnv: process.env.NODE_ENV || 'development',
  googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY || '',
  dummyUserId: process.env.DUMMY_USER_ID || 'user_dummy_001',
};
