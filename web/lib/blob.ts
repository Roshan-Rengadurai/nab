// Helpers for the hosted-upload path. Stateless: a screenshot lives at Blob
// pathname `<expiryEpoch>-<token>`, so both the per-image expiry (#1) and the
// unguessable access (#2) ride in the path — no database.
//
//   expiryEpoch : unix seconds when the link dies; 0 = never.
//   token       : 22 base62 chars (~131 bits) — not enumerable by guessing.

const ALPHABET =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
const TOKEN_LENGTH = 22; // 62^22 ≈ 1.7e39 ≈ 131 bits

/** Cryptographically-random, unbiased token (rejection sampling over 62 chars). */
export function makeToken(length: number = TOKEN_LENGTH): string {
  const max = 256 - (256 % ALPHABET.length); // largest multiple of 62 ≤ 256
  let out = "";
  while (out.length < length) {
    const bytes = new Uint8Array(length - out.length);
    crypto.getRandomValues(bytes);
    for (const b of bytes) {
      if (b < max) out += ALPHABET[b % ALPHABET.length];
    }
  }
  return out;
}

/** Build a pathname for an upload. ttlSeconds <= 0 → never expires. */
export function makePathname(ttlSeconds: number): string {
  const expiry = ttlSeconds > 0 ? Math.floor(Date.now() / 1000) + ttlSeconds : 0;
  return `${expiry}-${makeToken()}`;
}

/** A valid pathname: <digits>-<22 base62 chars>. */
export const PATH_RE = /^\d{1,12}-[A-Za-z0-9]{22}$/;
export function isValidSlug(s: string): boolean {
  return PATH_RE.test(s);
}

/** Expiry epoch (seconds) encoded in the slug; 0 = never. */
export function expiryOf(slug: string): number {
  const n = Number(slug.split("-")[0]);
  return Number.isFinite(n) ? n : 0;
}

/** True once the slug's expiry has passed. */
export function isExpired(slug: string, nowMs: number = Date.now()): boolean {
  const exp = expiryOf(slug);
  return exp > 0 && nowMs >= exp * 1000;
}

// Allowed TTLs (seconds). "Never" is intentionally NOT offered: every upload
// must expire so storage self-bounds and can't be used to run up the bill.
export const TTL_CHOICES = [
  60 * 60, // 1 hour
  60 * 60 * 24, // 1 day
  60 * 60 * 24 * 7, // 7 days
  60 * 60 * 24 * 30, // 30 days (max)
];
const DEFAULT_TTL = 60 * 60 * 24 * 30;
const MAX_TTL = 60 * 60 * 24 * 30;

/** Snap a requested TTL to the nearest allowed choice; always expires, ≤ 30d. */
export function clampTtl(seconds: number): number {
  if (!Number.isFinite(seconds) || seconds <= 0) return DEFAULT_TTL;
  if (seconds >= MAX_TTL) return MAX_TTL;
  return TTL_CHOICES.reduce((best, t) =>
    Math.abs(t - seconds) < Math.abs(best - seconds) ? t : best,
  );
}

/** MIME types accepted for hosted uploads (mirrors NabCore/ContentType).
 *  text/plain is the raw text-share path — rendered by the viewer page. */
export const ALLOWED_CONTENT_TYPES = [
  "image/png",
  "image/jpeg",
  "image/heic",
  "image/webp",
  "image/gif",
  "text/plain",
];

/** Per-upload size ceiling. Under Vercel's ~4.5MB request-body limit. */
export const MAX_UPLOAD_BYTES = 4 * 1024 * 1024; // 4 MB

/** Public CDN base, derived from BLOB_READ_WRITE_TOKEN's store id unless overridden. */
export function publicBase(): string {
  const explicit = process.env.BLOB_PUBLIC_BASE;
  if (explicit) return explicit.replace(/\/$/, "");
  const storeId = process.env.BLOB_READ_WRITE_TOKEN?.split("_")[3];
  if (!storeId) {
    throw new Error(
      "Cannot resolve Blob public base: set BLOB_PUBLIC_BASE or BLOB_READ_WRITE_TOKEN",
    );
  }
  return `https://${storeId}.public.blob.vercel-storage.com`;
}

/** Direct image URL (the link Discord embeds inline). */
export function imageUrl(slug: string): string {
  return `${publicBase()}/${slug}`;
}

/** Site origin, preferring an explicit domain then Vercel's deploy env. */
export function siteUrl(): string {
  const explicit = process.env.NEXT_PUBLIC_SITE_URL;
  if (explicit) return explicit.replace(/\/$/, "");
  const vercel =
    process.env.VERCEL_PROJECT_PRODUCTION_URL ?? process.env.VERCEL_URL;
  if (vercel) return `https://${vercel.replace(/\/$/, "")}`;
  return "http://localhost:3100";
}

/** Branded viewer-page URL (the link Discord renders as a card). */
export function pageUrl(slug: string): string {
  return `${siteUrl()}/s/${slug}`;
}
