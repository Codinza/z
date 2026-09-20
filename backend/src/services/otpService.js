import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import { prisma } from '../db/prisma.js';
import { env } from '../config/env.js';
import { sendSms, isDevSmsProvider } from './smsService.js';
import { normalizePhone, maskPhone } from '../utils/phone.js';
import logger from '../utils/logger.js';

const CODE_LENGTH = 6;
const CODE_PATTERN = /^\d{6}$/;

/** Uniformly random 6-digit code. Math.random is unsuitable for credentials. */
function generateCode() {
  return String(crypto.randomInt(0, 10 ** CODE_LENGTH)).padStart(CODE_LENGTH, '0');
}

function buildMessage(code) {
  return (
    `كود تأكيد ${env.smsSenderId}: ${code}\n` +
    `صالح لمدة ${env.otpExpiryMinutes} دقيقة. لا تشاركه مع أي شخص.`
  );
}

function cooldownError(retryAfterSeconds) {
  const error = new Error('Verification code already sent recently');
  error.code = 'OTP_COOLDOWN';
  error.retryAfterSeconds = retryAfterSeconds;
  return error;
}

/**
 * Issues a fresh code for a phone number and delivers it over SMS.
 *
 * Any previously issued, unconsumed code for the same phone/purpose is
 * discarded so only the newest code is ever valid.
 *
 * @throws error with `code === 'OTP_COOLDOWN'` when called inside the cooldown.
 */
export async function issueOtp({ phone, purpose = 'REGISTRATION' }) {
  const normalized = normalizePhone(phone);

  const latest = await prisma.otpCode.findFirst({
    where: { phone: normalized, purpose, consumedAt: null },
    orderBy: { createdAt: 'desc' },
  });

  if (latest) {
    const cooldownMs = env.otpResendCooldownSeconds * 1000;
    const elapsedMs = Date.now() - latest.createdAt.getTime();
    if (elapsedMs < cooldownMs) {
      throw cooldownError(Math.ceil((cooldownMs - elapsedMs) / 1000));
    }
  }

  const code = generateCode();
  const codeHash = await bcrypt.hash(code, 10);
  const expiresAt = new Date(Date.now() + env.otpExpiryMinutes * 60 * 1000);

  const [, created] = await prisma.$transaction([
    prisma.otpCode.deleteMany({
      where: { phone: normalized, purpose, consumedAt: null },
    }),
    prisma.otpCode.create({
      data: { phone: normalized, codeHash, purpose, expiresAt },
    }),
  ]);

  try {
    await sendSms(normalized, buildMessage(code));
  } catch (error) {
    // Do not leave an undeliverable code behind; let the caller retry cleanly.
    await prisma.otpCode.delete({ where: { id: created.id } }).catch(() => {});
    throw error;
  }

  logger.info('OTP issued', {
    phone: maskPhone(normalized),
    purpose,
    expiresAt: expiresAt.toISOString(),
  });

  return {
    expiresAt,
    resendAfterSeconds: env.otpResendCooldownSeconds,
    // Local convenience only, so the app flow is testable without a gateway.
    devCode: isDevSmsProvider() && env.nodeEnv !== 'production' ? code : undefined,
  };
}

/**
 * Checks a submitted code.
 * @returns {Promise<{ok: true} | {ok: false, reason: string, attemptsLeft?: number}>}
 */
export async function verifyOtp({ phone, code, purpose = 'REGISTRATION' }) {
  const normalized = normalizePhone(phone);
  const submitted = String(code ?? '').trim();

  if (!CODE_PATTERN.test(submitted)) {
    return { ok: false, reason: 'INVALID_FORMAT' };
  }

  const record = await prisma.otpCode.findFirst({
    where: {
      phone: normalized,
      purpose,
      consumedAt: null,
      expiresAt: { gt: new Date() },
    },
    orderBy: { createdAt: 'desc' },
  });

  if (!record) {
    return { ok: false, reason: 'EXPIRED' };
  }

  if (record.attempts >= env.otpMaxAttempts) {
    return { ok: false, reason: 'TOO_MANY_ATTEMPTS' };
  }

  if (!(await bcrypt.compare(submitted, record.codeHash))) {
    const updated = await prisma.otpCode.update({
      where: { id: record.id },
      data: { attempts: { increment: 1 } },
    });

    logger.warn('OTP verification failed', {
      phone: maskPhone(normalized),
      purpose,
      attempts: updated.attempts,
    });

    return {
      ok: false,
      reason:
        updated.attempts >= env.otpMaxAttempts ? 'TOO_MANY_ATTEMPTS' : 'INVALID_CODE',
      attemptsLeft: Math.max(env.otpMaxAttempts - updated.attempts, 0),
    };
  }

  await prisma.otpCode.update({
    where: { id: record.id },
    data: { consumedAt: new Date() },
  });

  logger.info('OTP verified', { phone: maskPhone(normalized), purpose });
  return { ok: true };
}

/** Housekeeping: drops codes that expired more than a day ago. */
export async function cleanupExpiredOtps() {
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const { count } = await prisma.otpCode.deleteMany({
    where: { expiresAt: { lt: cutoff } },
  });
  if (count > 0) logger.info('Expired OTP codes cleaned up', { count });
  return count;
}
