import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { head, BlobNotFoundError } from "@vercel/blob";
import { ArrowUpRight, Download } from "lucide-react";
import { expiryOf, imageUrl, isExpired, isValidSlug, pageUrl } from "@/lib/blob";
import { classify, highlight, titleFor } from "@/lib/snippet";
import CopyLink from "./Actions";

type Params = { params: Promise<{ slug: string }> };

const TITLE = "Shared with Nab";
const DESC = "A screenshot shared with Nab.";
const TEXT_DESC = "A snippet shared with Nab.";

/** Human label for the slug's expiry, e.g. "expires Jun 30" or "never expires". */
function expiryLabel(slug: string): string {
  const exp = expiryOf(slug);
  if (exp <= 0) return "never expires";
  const d = new Date(exp * 1000);
  return `expires ${d.toLocaleDateString("en-US", { month: "short", day: "numeric" })}`;
}

/** True when the blob holds a raw text share rather than an image. */
function isTextShare(contentType?: string): boolean {
  return (contentType ?? "").split(";")[0].trim().toLowerCase() === "text/plain";
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { slug } = await params;
  if (!isValidSlug(slug)) return { title: "Nab" };

  const img = imageUrl(slug);

  // Text shares get a plain card (no og:image pointing at a .txt file).
  let text = false;
  try {
    text = isTextShare((await head(img)).contentType);
  } catch {
    // Missing/expired — the page 404s; metadata just falls back to the image shape.
  }
  const desc = text ? TEXT_DESC : DESC;
  return {
    title: TITLE,
    description: desc,
    openGraph: {
      type: "website",
      title: TITLE,
      description: desc,
      url: pageUrl(slug),
      ...(text ? {} : { images: [{ url: img }] }),
    },
    twitter: {
      card: text ? "summary" : "summary_large_image",
      title: TITLE,
      description: desc,
      ...(text ? {} : { images: [img] }),
    },
  };
}

export default async function ScreenshotPage({ params }: Params) {
  const { slug } = await params;
  if (!isValidSlug(slug) || isExpired(slug)) notFound();

  const img = imageUrl(slug);

  // 404 cleanly for missing or expired (swept) links. Real misconfig errors
  // (e.g. no token) surface as a 500 rather than masquerading as not-found.
  let contentType: string | undefined;
  try {
    contentType = (await head(img)).contentType;
  } catch (err) {
    if (err instanceof BlobNotFoundError) notFound();
    throw err;
  }

  // Raw text share → render it in this page's window chrome with gruvbox
  // highlighting (selectable, copyable) — one window, not a window-in-a-window.
  let snippet: { kind: ReturnType<typeof classify>; text: string } | null = null;
  if (isTextShare(contentType)) {
    const res = await fetch(img, { cache: "no-store" });
    if (!res.ok) notFound();
    const text = await res.text();
    snippet = { kind: classify(text), text };
  }

  return (
    <div className="relative flex min-h-dvh flex-col font-sans">
      <header className="border-b border-bg1/70 bg-bg0/75 backdrop-blur">
        <nav className="mx-auto flex max-w-4xl items-center justify-between px-6 py-3.5">
          <a
            href="/"
            className="font-mono text-sm font-semibold tracking-tight text-fg0"
          >
            <span className="text-orange">~/</span>nab
          </a>
          <a
            href="/api/download"
            className="btn-lift btn-glow rounded-md bg-orange px-3.5 py-1.5 text-sm font-medium text-bg0-hard hover:bg-yellow"
          >
            Get Nab
          </a>
        </nav>
      </header>

      <main className="mx-auto flex w-full max-w-4xl flex-1 flex-col px-6 py-10">
        {/* Window-chrome frame around the shot / snippet */}
        <figure className="overflow-hidden rounded-xl border border-bg2 bg-bg0-hard shadow-2xl shadow-black/40">
          <div className="flex items-center gap-2 border-b border-bg1 bg-bg1/60 px-4 py-2.5">
            <span className="h-3 w-3 rounded-full bg-red" />
            <span className="h-3 w-3 rounded-full bg-yellow" />
            <span className="h-3 w-3 rounded-full bg-green" />
            <span className="ml-3 truncate font-mono text-xs text-gray">
              {snippet ? titleFor(snippet.kind) : slug}
            </span>
          </div>
          {snippet ? (
            snippet.kind === "prose" ? (
              <div className="max-h-[70dvh] overflow-auto px-6 py-5 text-[15px] leading-7 whitespace-pre-wrap text-fg1">
                {snippet.text}
              </div>
            ) : (
              <pre className="max-h-[70dvh] overflow-auto px-6 py-5 font-mono text-sm leading-6 text-fg1">
                <code>
                  {highlight(snippet.text).map((t, i) =>
                    t.className ? (
                      <span key={i} className={t.className}>
                        {t.text}
                      </span>
                    ) : (
                      t.text
                    ),
                  )}
                </code>
              </pre>
            )
          ) : (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={img}
              alt="Screenshot shared with Nab"
              className="mx-auto block max-h-[70dvh] w-auto max-w-full bg-bg0-hard object-contain"
            />
          )}
        </figure>

        {/* Actions */}
        <div className="mt-6 flex flex-wrap items-center gap-3">
          <a
            href={img}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-lift inline-flex items-center gap-2 rounded-lg border border-bg3 px-4 py-2 font-mono text-sm text-fg1 hover:border-fg3 hover:text-fg0"
          >
            <ArrowUpRight className="h-4 w-4" />
            open original
          </a>
          <a
            href={img}
            download
            className="btn-lift inline-flex items-center gap-2 rounded-lg border border-bg3 px-4 py-2 font-mono text-sm text-fg1 hover:border-fg3 hover:text-fg0"
          >
            <Download className="h-4 w-4" />
            download
          </a>
          <CopyLink url={pageUrl(slug)} />
        </div>
      </main>

      {/* Footer — TUI modeline */}
      <footer className="border-t border-bg2 bg-bg0-hard">
        <div className="mx-auto flex max-w-4xl flex-wrap items-center gap-x-4 gap-y-1 px-6 py-3 font-mono text-xs">
          <span className="rounded bg-orange px-2 py-0.5 font-semibold text-bg0-hard">
            NORMAL
          </span>
          <span className="text-fg1">shared with nab</span>
          <span className="text-gray">{expiryLabel(slug)}</span>
          <a href="/" className="ml-auto text-gray transition-colors hover:text-fg0">
            ~/nab
          </a>
        </div>
      </footer>
    </div>
  );
}
