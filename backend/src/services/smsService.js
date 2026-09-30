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

function buildTemplatePayloads(to, template, language, code) {
  const buttonIndex = env.whatsappOtpButtonIndex;
  const withButton = buttonIndex !== '';

  const bodyOnly = [
    {
      type: 'body',
      parameters: [{ type: 'text', text: String(code) }],
    },
  ];

  const bodyAndButton = [
    ...bodyOnly,
    {
      type: 'button',
      sub_type: 'url',
      index: String(buttonIndex || '0'),
      parameters: [{ type: 'text', text: String(code) }],
    },
  ];

  // Authentication templates sometimes accept button OTP only.
  const buttonOnly = [
    {
      type: 'button',
      sub_type: 'url',
      index: String(buttonIndex || '0'),
      parameters: [{ type: 'text', text: String(code) }],
    },
  ];

  const variants = [];
  if (withButton) {
    variants.push({ label: 'body+button', components: bodyAndButton });
    variants.push({ label: 'button-only', components: buttonOnly });
  }
  variants.push({ label: 'body-only', components: bodyOnly });

  return variants.map(({ label, components }) => ({
    label,
    payload: {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to,
      type: 'template',
      template: {
        name: template,
        language: { code: language },
        components,
      },
    },
  }));
}

function extractWhatsAppError(body, status) {
  return (
    body?.error?.error_user_msg ||
    body?.error?.message ||
    body?.error?.error_data?.details ||
    `HTTP ${status}`
  );
}

/**
 * Sends an OTP via Meta WhatsApp Cloud API using an approved template.
 * Tries a few component shapes because Auth vs Utility templates differ.
 * Docs: https://developers.facebook.com/docs/whatsapp/cloud-api
 */
async function sendViaWhatsApp(phone, message, { code } = {}) {
  const token = env.whatsappToken;
  const phoneNumberId = env.whatsappPhoneNumberId;
  const template = env.whatsappOtpTemplate;
  const language = env.whatsappOtpLanguage;

  if (!token || !phoneNumberId) {
    throw new Error(
      'WhatsApp is not configured. Set WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID on Render.'
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
  const variants = buildTemplatePayloads(to, template, language, code);

  let lastDetail = 'Unknown WhatsApp error';
  let lastCode = null;

  for (const variant of variants) {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(variant.payload),
    });

    const body = await response.json().catch(() => ({}));

    if (response.ok) {
      logger.info('WhatsApp OTP sent', {
        to: maskPhone(phone),
        messageId: body?.messages?.[0]?.id,
        template,
        language,
        variant: variant.label,
      });

      return {
        provider: 'whatsapp',
        delivered: true,
        channel: 'whatsapp',
        messageId: body?.messages?.[0]?.id,
      };
    }

    lastDetail = extractWhatsAppError(body, response.status);
    lastCode = body?.error?.code;
    logger.warn('WhatsApp OTP variant failed', {
      to: maskPhone(phone),
      status: response.status,
      detail: lastDetail,
      errorCode: lastCode,
      variant: variant.label,
      template,
      language,
    });

    // Token / permission / unknown template — no point retrying other shapes.
    if (
      lastCode === 190 ||
      lastCode === 102 ||
      lastCode === 10 ||
      String(lastDetail).toLowerCase().includes('template name') ||
      String(lastDetail).toLowerCase().includes('does not exist')
    ) {
      break;
    }
  }

  logger.error('WhatsApp OTP send failed', {
    to: maskPhone(phone),
    detail: lastDetail,
    errorCode: lastCode,
    template,
    language,
  });

  const err = new Error(`WhatsApp send failed: ${lastDetail}`);
  err.whatsappCode = lastCode;
  err.whatsappDetail = lastDetail;
  throw err;
}

/** Twilio Programmable SMS. Needs TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN and TWILIO_FROM (or a messaging service). */
async function sendViaTwilio(phone, message) {
  const sid = env.twilioAccountSid;
  const authToken = env.twilioAuthToken;
  if (!sid || !authToken || (!env.twilioFrom && !env.twilioMessagingServiceSid)) {
    throw new Error(
      'Twilio is not configured. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN and TWILIO_FROM.'
    );
  }

  const params = new URLSearchParams({ To: toE164(phone), Body: message });
  if (env.twilioMessagingServiceSid) {
    params.set('MessagingServiceSid', env.twilioMessagingServiceSid);
  } else {
    params.set('From', env.twilioFrom);
  }

  const response = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${sid}:${authToken}`).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
    }
  );
  const body = await response.json().catch(() => ({}));

  if (!response.ok) {
    const detail = body?.message || `HTTP ${response.status}`;
    logger.error('Twilio SMS failed', {
      to: maskPhone(phone),
      status: response.status,
      detail,
      errorCode: body?.code,
    });
    const err = new Error(`SMS send failed: ${detail}`);
    err.smsDetail = detail;
    throw err;
  }

  logger.info('Twilio SMS sent', { to: maskPhone(phone), sid: body?.sid });
  return { provider: 'twilio', delivered: true, channel: 'sms', messageId: body?.sid };
}

/** SMS Misr (Egypt). Needs SMSMISR_USERNAME, SMSMISR_PASSWORD and SMSMISR_SENDER. */
async function sendViaSmsMisr(phone, message) {
  if (!env.smsMisrUsername || !env.smsMisrPassword || !env.smsMisrSender) {
    throw new Error(
      'SMS Misr is not configured. Set SMSMISR_USERNAME, SMSMISR_PASSWORD and SMSMISR_SENDER.'
    );
  }

  const params = new URLSearchParams({
    environment: env.smsMisrEnvironment,
    username: env.smsMisrUsername,
    password: env.smsMisrPassword,
    language: '2', // Arabic (unicode) message body
    sender: env.smsMisrSender,
    mobile: toE164(phone).replace(/\D/g, ''),
    message,
  });

  const response = await fetch('https://smsmisr.com/api/SMS/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });
  const body = await response.json().catch(() => ({}));

  // SMS Misr answers HTTP 200 with a code; 1901 means the message was accepted.
  if (!response.ok || String(body?.code) !== '1901') {
    const detail = body?.message || `HTTP ${response.status} code=${body?.code}`;
    logger.error('SMS Misr failed', { to: maskPhone(phone), detail, code: body?.code });
    const err = new Error(`SMS send failed: ${detail}`);
    err.smsDetail = detail;
    throw err;
  }

  logger.info('SMS Misr sent', { to: maskPhone(phone) });
  return { provider: 'smsmisr', delivered: true, channel: 'sms' };
}

const providers = {
  console: sendViaConsole,
  whatsapp: sendViaWhatsApp,
  twilio: sendViaTwilio,
  smsmisr: sendViaSmsMisr,
};

export function isDevSmsProvider() {
  return env.smsProvider === 'console';
}

export function getDeliveryChannel() {
  if (env.smsProvider === 'whatsapp') return 'whatsapp';
  if (env.smsProvider === 'twilio' || env.smsProvider === 'smsmisr') return 'sms';
  return 'console';
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
      whatsappCode: error.whatsappCode,
    });
    throw error;
  }
}
