import 'dotenv/config';

function required(name) {
  const value = process.env[name];
  if (!value || !String(value).trim()) {
    throw new Error(
      `Missing required environment variable: ${name}. ` +
        'Set it in backend/.env (and on your host) before starting the server.'
    );
  }
  return value.trim();
}

function requiredSecret(name, { minLength = 32 } = {}) {
  const value = required(name);
  if (value.length < minLength) {
    throw new Error(
      `${name} must be at least ${minLength} characters. Generate a strong random value.`
    );
  }
  if (
    value === 'rideflow_secret_fallback' ||
    value === 'rideflow_refresh_fallback' ||
    value === 'replace-with-a-long-random-secret' ||
    value === 'replace-with-another-long-random-secret'
  ) {
    throw new Error(
      `${name} is still set to a known placeholder. Generate a fresh random secret.`
    );
  }
  return value;
}

export const env = {
  port: Number(process.env.PORT || 4000),
  nodeEnv: process.env.NODE_ENV || 'development',
  databaseUrl: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/rideflow?schema=public',
  googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY || '',
  dummyUserId: process.env.DUMMY_USER_ID || 'user_dummy_001',
  jwtSecret: requiredSecret('JWT_SECRET'),
  jwtRefreshSecret: requiredSecret('JWT_REFRESH_SECRET'),
  paymobApiKey: process.env.PAYMOB_API_KEY || '',
  paymobIntegrationId: process.env.PAYMOB_INTEGRATION_ID || '',
  paymobWalletIntegrationId: process.env.PAYMOB_WALLET_INTEGRATION_ID || '',
  smsProvider: process.env.SMS_PROVIDER || 'console',
  smsSenderId: process.env.SMS_SENDER_ID || 'Zoon',
  otpExpiryMinutes: Number(process.env.OTP_EXPIRY_MINUTES || 10),
  otpMaxAttempts: Number(process.env.OTP_MAX_ATTEMPTS || 5),
  otpResendCooldownSeconds: Number(process.env.OTP_RESEND_COOLDOWN_SECONDS || 60),
};
