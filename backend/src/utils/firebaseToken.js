import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

const CERTS_URL =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

let cachedCerts = null;
let cachedUntil = 0;

async function getGoogleCerts() {
  if (cachedCerts && Date.now() < cachedUntil) return cachedCerts;

  const response = await fetch(CERTS_URL);
  if (!response.ok) {
    throw new Error(`Could not load Google certificates (HTTP ${response.status})`);
  }
  const maxAge = /max-age=(\d+)/.exec(response.headers.get('cache-control') || '');
  cachedCerts = await response.json();
  cachedUntil = Date.now() + (maxAge ? Number(maxAge[1]) : 3600) * 1000;
  return cachedCerts;
}

export function isFirebaseAuthEnabled() {
  return Boolean(env.firebaseProjectId);
}

/**
 * Verifies a Firebase ID token (signed by Google) without needing a service
 * account. Returns the phone number Firebase confirmed by SMS.
 */
export async function verifyFirebaseIdToken(idToken) {
  const projectId = env.firebaseProjectId;
  if (!projectId) {
    throw new Error('Firebase is not configured (FIREBASE_PROJECT_ID missing)');
  }

  const decodedHeader = jwt.decode(idToken, { complete: true })?.header;
  if (!decodedHeader?.kid) {
    throw new Error('Malformed Firebase token');
  }

  const certs = await getGoogleCerts();
  const cert = certs[decodedHeader.kid];
  if (!cert) {
    throw new Error('Unknown Firebase signing key');
  }

  const payload = jwt.verify(idToken, cert, {
    algorithms: ['RS256'],
    audience: projectId,
    issuer: `https://securetoken.google.com/${projectId}`,
  });

  if (!payload.sub) {
    throw new Error('Firebase token has no subject');
  }
  if (!payload.phone_number) {
    throw new Error('Firebase token has no phone number');
  }

  return { uid: payload.sub, phoneNumber: String(payload.phone_number) };
}
