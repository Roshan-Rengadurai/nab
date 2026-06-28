import { NextResponse } from "next/server";

// Redirects to the latest macOS build. Wired to GitHub Releases.
// Set GITHUB_REPO (e.g. "your-org/snip") in Vercel env.
// Until a release exists, falls back to the releases page.
export const dynamic = "force-dynamic";

export async function GET() {
  const repo = process.env.GITHUB_REPO;
  if (!repo) {
    return NextResponse.json(
      { error: "GITHUB_REPO not configured" },
      { status: 503 },
    );
  }

  try {
    const res = await fetch(
      `https://api.github.com/repos/${repo}/releases/latest`,
      {
        headers: { Accept: "application/vnd.github+json" },
        next: { revalidate: 300 },
      },
    );
    if (res.ok) {
      const release = await res.json();
      const asset = (release.assets ?? []).find(
        (a: { name: string; browser_download_url: string }) =>
          a.name.endsWith(".dmg") || a.name.endsWith(".zip"),
      );
      if (asset) {
        return NextResponse.redirect(asset.browser_download_url);
      }
    }
  } catch {
    // fall through to releases page
  }

  return NextResponse.redirect(`https://github.com/${repo}/releases/latest`);
}
