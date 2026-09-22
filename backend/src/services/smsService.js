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
      'WhatsApp is not configured. Set WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID on Railway.'
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
      whatsappCode: error.whatsappCode,
    });
    throw error;
  }
}
