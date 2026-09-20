import { env } from '../config/env.js';
import logger from '../utils/logger.js';
import { toE164, maskPhone } from '../utils/phone.js';

/**
 * Development provider: never contacts a gateway, just writes the message to
 * the log so the OTP flow is testable without a paid SMS account.
 */
async function sendViaConsole(phone, message) {
  const line = `[SMS:console] to=${toE164(phone)} | ${message}`;

  if (env.nodeEnv === 'production') {
    logger.warn(
      'SMS_PROVIDER is "console" in production - no message was actually delivered. ' +
        'Configure a real provider before accepting real signups.',
      { to: maskPhone(phone) }
    );
  }

  // Intentionally logged at info so the code is easy to find during local work.
  logger.info(line);
  return { provider: 'console', delivered: false };
}

const providers = {
  console: sendViaConsole,
};

export function isDevSmsProvider() {
  return env.smsProvider === 'console';
}

/**
 * Sends an SMS through the configured provider.
 * Throws when the provider name is unknown so misconfiguration fails loudly
 * instead of silently dropping verification codes.
 */
export async function sendSms(phone, message) {
  const provider = providers[env.smsProvider];

  if (!provider) {
    throw new Error(
      `Unknown SMS_PROVIDER "${env.smsProvider}". Supported: ${Object.keys(providers).join(', ')}.`
    );
  }

  try {
    return await provider(phone, message);
  } catch (error) {
    logger.error('SMS send failed', {
      provider: env.smsProvider,
      to: maskPhone(phone),
      error: error.message,
    });
    throw error;
  }
}
