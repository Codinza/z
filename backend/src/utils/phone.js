const ARABIC_INDIC_OFFSET = 0x0660; // ٠-٩
const EXTENDED_ARABIC_INDIC_OFFSET = 0x06f0; // ۰-۹

const EGYPTIAN_MOBILE_PATTERN = /^01[0125]\d{8}$/;

/**
 * Converts Arabic-Indic and Persian digits to ASCII so numbers typed on an
 * Arabic keyboard normalize the same way as Latin input.
 */
function toAsciiDigits(value) {
  return value.replace(/[\u0660-\u0669\u06f0-\u06f9]/g, (char) => {
    const code = char.charCodeAt(0);
    const offset =
      code >= EXTENDED_ARABIC_INDIC_OFFSET
        ? EXTENDED_ARABIC_INDIC_OFFSET
        : ARABIC_INDIC_OFFSET;
    return String(code - offset);
  });
}

/**
 * Normalizes an Egyptian mobile number to local `01XXXXXXXXX` form.
 *
 * Identifiers that are not Egyptian mobile numbers (legacy logins such as
 * `admin002`) are returned trimmed but otherwise untouched, so existing
 * accounts keep working.
 */
export function normalizePhone(raw) {
  if (typeof raw !== 'string') return '';

  let value = toAsciiDigits(raw.trim()).replace(/[\s\-().]/g, '');

  if (value.startsWith('+20')) {
    value = `0${value.slice(3)}`;
  } else if (value.startsWith('0020')) {
    value = `0${value.slice(4)}`;
  } else if (/^201[0125]\d{8}$/.test(value)) {
    value = `0${value.slice(2)}`;
  } else if (/^1[0125]\d{8}$/.test(value)) {
    value = `0${value}`;
  }

  return value;
}

export function isValidEgyptianMobile(value) {
  return EGYPTIAN_MOBILE_PATTERN.test(normalizePhone(value));
}

/**
 * Converts a local number to E.164 (`+201XXXXXXXXX`) for SMS gateways.
 * Returns the input unchanged when it is not an Egyptian mobile number.
 */
export function toE164(value) {
  const normalized = normalizePhone(value);
  return EGYPTIAN_MOBILE_PATTERN.test(normalized)
    ? `+20${normalized.slice(1)}`
    : normalized;
}

/** Masks a number for logs and UI: `010****5678`. */
export function maskPhone(value) {
  const normalized = normalizePhone(value);
  if (normalized.length < 7) return normalized;
  return `${normalized.slice(0, 3)}****${normalized.slice(-4)}`;
}
