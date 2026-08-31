import 'dotenv/config';

export const env = {
  port: Number(process.env.PORT || 4000),
  nodeEnv: process.env.NODE_ENV || 'development',
  databaseUrl: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/rideflow?schema=public',
  googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY || '',
  dummyUserId: process.env.DUMMY_USER_ID || 'user_dummy_001',
  jwtSecret: process.env.JWT_SECRET || 'rideflow_secret_fallback',
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET || 'rideflow_refresh_fallback',
  paymobApiKey: process.env.PAYMOB_API_KEY || '',
  paymobIntegrationId: process.env.PAYMOB_INTEGRATION_ID || '',
  paymobWalletIntegrationId: process.env.PAYMOB_WALLET_INTEGRATION_ID || '',
};
