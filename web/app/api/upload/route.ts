import { put } from "@vercel/blob";
import { NextResponse } from "next/server";
import { lookup, normalizeKey } from "@/lib/license";
import {
  ALLOWED_CONTENT_TYPES,
  MAX_UPLOAD_BYTES,
  clampTtl,
  imageUrl,
  makePathname,
  pageUrl,
} from "@/lib/blob";
import { clientIp, rateLimit } from "@/lib/ratelimit";

// Per-IP rate limits. Generous for a human, hostile to a script.
const LIMITS = [
  { limit: 15, windowMs: 60_000 }, // 15 / minute
  { limit: 150, windowMs: 60 * 60_000 }, // 150 / hour
];

// Hosted upload for "Nab hosting". The macOS app POSTs the image bytes once,
// authenticated by a license key. The server owns the two guarantees:
//   #1 expiry , x-nab-ttl (seconds, 0=never) → encoded in the pathname.
//   #2 access , a 131-bit token in the pathname; not enumerable by guessing.
// Returns the direct image URL (inline embed) and the viewer URL (rich card).
export const dynamic = "force-dynamic";
export const maxDuration = 60;

export async function POST(request: Request) {
  // Rate limit first, cheapest rejection, blocks floods before any work.
  const rl = await rateLimit(`upload:${clientIp(request)}`, LIMITS);
  if (!rl.ok) {
    return NextResponse.json(
      { error: "Rate limit exceeded" },
      { status: 429, headers: { "Retry-After": String(rl.retryAfterSec) } },
    );
  }

  // #2 auth: valid license key required.
  const key = normalizeKey(request.headers.get("x-nab-key"));
  if (!lookup(key).valid) {
    return NextResponse.json(
      { error: "Invalid or missing license key" },
      { status: 401 },
    );
  }

  const contentType = (request.headers.get("content-type") ?? "")
    .split(";")[0]
    .trim()
    .toLowerCase();
  if (!ALLOWED_CONTENT_TYPES.includes(contentType)) {
    return NextResponse.json(
      { error: `Unsupported content-type: ${contentType || "(none)"}` },
      { status: 415 },
    );
  }

  const body = Buffer.from(await request.arrayBuffer());
  if (body.byteLength === 0) {
    return NextResponse.json({ error: "Empty body" }, { status: 400 });
  }
  if (body.byteLength > MAX_UPLOAD_BYTES) {
    return NextResponse.json(
      { error: `Too large (max ${MAX_UPLOAD_BYTES} bytes)` },
      { status: 413 },
    );
  }

  // #1 expiry: client-requested TTL, snapped to an allowed choice.
  const ttl = clampTtl(Number(request.headers.get("x-nab-ttl")));
  const pathname = makePathname(ttl);

  try {
    const blob = await put(pathname, body, {
      access: "public",
      addRandomSuffix: false,
      contentType,
      cacheControlMaxAge: 60 * 60 * 24 * 365,
    });
    return NextResponse.json({
      slug: pathname,
      imageUrl: blob.url || imageUrl(pathname),
      pageUrl: pageUrl(pathname),
      expiresAt: ttl > 0 ? Math.floor(Date.now() / 1000) + ttl : null,
    });
  } catch (error) {
    return NextResponse.json(
      { error: (error as Error).message },
      { status: 500 },
    );
  }
}
