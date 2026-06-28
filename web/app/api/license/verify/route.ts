import { NextResponse } from "next/server";

// Serverless license check (plan §25/§48). Fail-open is the CLIENT's job:
// if this endpoint is unreachable, the app grants a grace period and keeps
// working. This route just validates a key's shape/registry.
//
// v0 stub: accepts keys matching QS-XXXX-XXXX-XXXX (base32-ish). Swap the
// `lookup` for a real store (KV / D1 / DB) later. No PII beyond the key.
export const dynamic = "force-dynamic";

const KEY_RE = /^QS-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/;

function lookup(key: string): { valid: boolean; plan: string } {
  // Placeholder registry. Replace with a real lookup.
  if (KEY_RE.test(key)) return { valid: true, plan: "personal" };
  return { valid: false, plan: "none" };
}

export async function POST(req: Request) {
  let key = "";
  try {
    const body = await req.json();
    key = typeof body?.key === "string" ? body.key.trim().toUpperCase() : "";
  } catch {
    return NextResponse.json(
      { valid: false, error: "Invalid JSON body" },
      { status: 400 },
    );
  }

  if (!key) {
    return NextResponse.json(
      { valid: false, error: "Missing 'key'" },
      { status: 400 },
    );
  }

  const result = lookup(key);
  return NextResponse.json(
    { valid: result.valid, plan: result.plan },
    { status: result.valid ? 200 : 402 },
  );
}
