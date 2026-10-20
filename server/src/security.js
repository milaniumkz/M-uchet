import { randomBytes, scrypt as scryptCallback, timingSafeEqual, createHash } from 'node:crypto';
import { promisify } from 'node:util';
const scrypt = promisify(scryptCallback);
export const hashToken = value => createHash('sha256').update(value).digest('hex');
export const newToken = () => randomBytes(32).toString('base64url');
export async function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');
  const hash = await scrypt(password, salt, 64);
  return `${salt}:${hash.toString('hex')}`;
}
export async function verifyPassword(password, stored) {
  const [salt, hex] = stored.split(':');
  const actual = await scrypt(password, salt, 64);
  return timingSafeEqual(actual, Buffer.from(hex, 'hex'));
}
export function fail(statusCode, code) {
  throw Object.assign(new Error(code), { statusCode, code });
}
export function text(value, field, max = 200) {
  if (typeof value !== 'string' || !value.trim() || value.length > max) fail(400, `invalid_${field}`);
  return value.trim();
}
export function integer(value, field, minimum = 0) {
  if (!Number.isSafeInteger(value) || value < minimum || value > 1_000_000_000_000) fail(400, `invalid_${field}`);
  return value;
}
export function scope(value = 'ACCOUNTING') {
  if (!['ACCOUNTING', 'MANAGEMENT', 'BOTH'].includes(value)) fail(400, 'invalid_ledger_scope');
  return value;
}

export function businessDate(value, timezone = 'Asia/Almaty') {
  if (value === undefined) {
    const parts = new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date());
    const get = type => parts.find(p => p.type === type).value;
    value = `${get('year')}-${get('month')}-${get('day')}`;
  }
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) || !Number.isFinite(Date.parse(value)) || new Date(value).toISOString().slice(0,10) !== value) fail(400, 'invalid_business_date');
  return value;
}
