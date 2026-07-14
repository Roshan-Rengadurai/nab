import { list, del } from "@vercel/blob";
import { NextResponse } from "next/server";
import { isExpired } from "@/lib/blob";

// Daily sweep, deletes blobs whose per-image expiry (encoded in the pathname)
// has passed. Slugs with expiry 0 (never) are kept. Registered as a Vercel Cron
// in vercel.json; Vercel sends `Authorization: Bearer <CRON_SECRET>`.
export const dynamic = "force-dynamic";
export const maxDuration = 60;

export async function GET(request: Request): Promise<NextResponse> {
  const secret = process.env.CRON_SECRET;
  if (secret && request.headers.get("authorization") !== `Bearer ${secret}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const now = Date.now();
  const expired: string[] = [];
  let cursor: string | undefined;
  do {
    const page = await list({ cursor, limit: 1000 });
    for (const blob of page.blobs) {
      if (isExpired(blob.pathname, now)) expired.push(blob.url);
    }
    cursor = page.hasMore ? page.cursor : undefined;
  } while (cursor);

  for (let i = 0; i < expired.length; i += 100) {
    await del(expired.slice(i, i + 100));
  }
  return NextResponse.json({ deleted: expired.length });
}
