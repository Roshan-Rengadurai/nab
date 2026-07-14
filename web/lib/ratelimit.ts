// Rate limiting with Upstash Redis when env vars are present; falls back to
// in-memory (per-instance, best-effort) for local dev or when Redis isn't
// configured. The hard bill backstop is Vercel Spend Management, set it.

import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

export interface Limit {
  limit: number;
  windowMs: number;
}

export interface RateResult {
  ok: boolean;
  retryAfterSec: number;
}

// ---------------------------------------------------------------------------
// Upstash path, global across all function instances
// ---------------------------------------------------------------------------

let _redis: Redis | null = null;
// One Ratelimit instance per window, keyed by windowMs.
const _limiters = new Map<number, Ratelimit>();

function getLimiter(limit: number, windowMs: number): Ratelimit {
  if (!_redis) _redis = Redis.fromEnv();
  if (!_limiters.has(windowMs)) {
    _limiters.set(
      windowMs,
      new Ratelimit({
        redis: _redis,
        limiter: Ratelimit.slidingWindow(limit, `${windowMs / 1000} s`),
        prefix: "nab:rl",
      }),
    );
  }
  return _limiters.get(windowMs)!;
}

async function rateLimitUpstash(
  key: string,
  limits: Limit[],
): Promise<RateResult> {
  for (const { limit, windowMs } of limits) {
    const result = await getLimiter(limit, windowMs).limit(`${key}:${windowMs}`);
    if (!result.success) {
      const retryAfterMs = result.reset - Date.now();
      return {
        ok: false,
        retryAfterSec: Math.ceil(Math.max(retryAfterMs, 0) / 1000),
      };
    }
  }
  return { ok: true, retryAfterSec: 0 };
}

// ---------------------------------------------------------------------------
// In-memory fallback, per-instance, good enough for local dev
// ---------------------------------------------------------------------------

type Stamps = number[];
const buckets = new Map<string, Stamps>();
const MAX_KEYS = 10_000;

function rateLimitMemory(key: string, limits: Limit[]): RateResult {
  const now = Date.now();
  const maxWindow = Math.max(...limits.map((l) => l.windowMs));
  if (buckets.size > MAX_KEYS) buckets.clear();
  const stamps = (buckets.get(key) ?? []).filter((t) => now - t < maxWindow);
  for (const { limit, windowMs } of limits) {
    const inWindow = stamps.filter((t) => now - t < windowMs);
    if (inWindow.length >= limit) {
      const oldest = Math.min(...inWindow);
      return {
        ok: false,
        retryAfterSec: Math.ceil((windowMs - (now - oldest)) / 1000),
      };
    }
  }
  stamps.push(now);
  buckets.set(key, stamps);
  return { ok: true, retryAfterSec: 0 };
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

const hasUpstash =
  typeof process !== "undefined" &&
  !!process.env.UPSTASH_REDIS_REST_URL &&
  !!process.env.UPSTASH_REDIS_REST_TOKEN;

export async function rateLimit(
  key: string,
  limits: Limit[],
): Promise<RateResult> {
  if (hasUpstash) return rateLimitUpstash(key, limits);
  return rateLimitMemory(key, limits);
}

/** Best-effort client IP from Vercel/edge headers. */
export function clientIp(req: Request): string {
  const xff = req.headers.get("x-forwarded-for");
  if (xff) return xff.split(",")[0].trim();
  return req.headers.get("x-real-ip") ?? "unknown";
}
