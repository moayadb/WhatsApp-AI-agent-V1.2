import { randomBytes, scrypt, timingSafeEqual, type ScryptOptions } from 'node:crypto';
import { promisify } from 'node:util';

// The bare `promisify(scrypt)` overload drops the options argument, so the
// callback signature is spelled out to keep N/r/p tunable.
const scryptAsync = promisify(
  scrypt as (
    password: string,
    salt: Buffer,
    keylen: number,
    options: ScryptOptions,
    callback: (err: Error | null, derivedKey: Buffer) => void,
  ) => void,
);

// OWASP-recommended scrypt parameters. Chosen over argon2/bcrypt because both
// are native modules: this way the API image needs no compiler, which keeps
// deployment on a plain Contabo box a one-command affair.
const N = 16_384;
const r = 8;
const p = 1;
const KEY_LENGTH = 64;
const MAX_MEM = 64 * 1024 * 1024;

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const key = (await scryptAsync(password, salt, KEY_LENGTH, {
    N,
    r,
    p,
    maxmem: MAX_MEM,
  })) as Buffer;
  return [
    'scrypt',
    N,
    r,
    p,
    salt.toString('base64'),
    key.toString('base64'),
  ].join('$');
}

export async function verifyPassword(
  password: string,
  stored: string,
): Promise<boolean> {
  const parts = stored.split('$');
  if (parts.length !== 6 || parts[0] !== 'scrypt') return false;

  const [, nRaw, rRaw, pRaw, saltB64, keyB64] = parts;
  const salt = Buffer.from(saltB64, 'base64');
  const expected = Buffer.from(keyB64, 'base64');

  const actual = (await scryptAsync(password, salt, expected.length, {
    N: Number(nRaw),
    r: Number(rRaw),
    p: Number(pRaw),
    maxmem: MAX_MEM,
  })) as Buffer;

  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

/** Constant-time compare for shared secrets (internal token, n8n secret). */
export function secretEquals(a: string | undefined, b: string): boolean {
  if (!a || !b) return false;
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}
