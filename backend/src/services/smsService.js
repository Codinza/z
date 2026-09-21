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
        'Set SMS_PROVIDER=whatsapp and configure WhatsApp Cloud API before real signups.',
      { to: maskPhone(phone) }
    );
  }

  logger.info(line);
  return { provider: 'console', delivered: false, channel: 'console' };
}

/** WhatsApp Cloud API expects digits only, e.g. 2010xxxxxxxx */
function toWhatsAppRecipient(phone) {
  return toE164(phone).replace(/\D/g, '');
}

/**
 * Sends an OTP via Meta WhatsApp Cloud API using an approved template.
 * Docs: https://developers.facebook.com/docs/whatsapp/cloud-api
 */
async function sendViaWhatsApp(phone, message, { code } = {}) {
  const token = env.whatsappToken;
  const phoneNumberId = env.whatsappPhoneNumberId;
  const template = env.whatsappOtpTemplate;
  const language = env.whatsappOtpLanguage;

  if (!token || !phoneNumberId) {
    throw new Error(
      'WhatsApp is not configured. Set WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID.'
    );
  }

  if (!code) {
    const match = String(message).match(/\b(\d{6})\b/);
    code = match?.[1];
  }
  if (!code) {
    throw new Error('WhatsApp OTP requires a 6-digit code');
  }

  const to = toWhatsAppRecipient(phone);
  const url = `https://graph.facebook.com/${env.whatsappGraphVersion}/${phoneNumberId}/messages`;

  const components = [
    {
      type: 'body',
      parameters: [{ type: 'text', text: String(code) }],
    },
  ];

  // Authentication templates usually require the OTP in the URL button too.
  if (env.whatsappOtpButtonIndex !== '') {
    components.push({
      type: 'button',
      sub_type: 'url',
      index: String(env.whatsappOtpButtonIndex),
      parameters: [{ type: 'text', text: String(code) }],
    });
  }

  const payload = {
    messaging_product: 'whatsapp',
    recipient_type: 'individual',
    to,
    type: 'template',
    template: {
      name: template,
      language: { code: language },
      components,
    },
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const body = await response.json().catch(() => ({}));

  if (!response.ok) {
    const detail =
      body?.error?.message ||
      body?.error?.error_user_msg ||
      `HTTP ${response.status}`;
    logger.error('WhatsApp OTP send failed', {
      to: maskPhone(phone),
      status: response.status,
      detail,
      errorCode: body?.error?.code,
    });
    throw new Error(`WhatsApp send failed: ${detail}`);
  }

  logger.info('WhatsApp OTP sent', {
    to: maskPhone(phone),
    messageId: body?.messages?.[0]?.id,
    template,
  });

  return {
    provider: 'whatsapp',
    delivered: true,
    channel: 'whatsapp',
    messageId: body?.messages?.[0]?.id,
  };
}

const providers = {
  console: sendViaConsole,
  whatsapp: sendViaWhatsApp,
};

export function isDevSmsProvider() {
  return env.smsProvider === 'console';
}

export function getDeliveryChannel() {
  return env.smsProvider === 'whatsapp' ? 'whatsapp' : 'console';
}

/**
 * Sends a verification message through the configured provider.
 * For WhatsApp, pass `{ code }` so the approved template can be filled.
 */
export async function sendSms(phone, message, options = {}) {
  const provider = providers[env.smsProvider];

  if (!provider) {
    throw new Error(
      `Unknown SMS_PROVIDER "${env.smsProvider}". Supported: ${Object.keys(providers).join(', ')}.`
    );
  }

  try {
    return await provider(phone, message, options);
  } catch (error) {
    logger.error('OTP delivery failed', {
      provider: env.smsProvider,
      to: maskPhone(phone),
      error: error.message,
    });
    throw error;
  }
}
