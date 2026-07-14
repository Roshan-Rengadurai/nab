"use client";

import { useEffect, useState } from "react";
import { ArrowRight, Check, Copy } from "lucide-react";

type Variant = "nav" | "primary" | "navlink";

/**
 * Download call-to-action. Nab is a macOS-only app, so on a phone/tablet a real
 * download is useless, instead the button copies the page link (fitting: Nab's
 * whole job is putting links on your clipboard) so the visitor can open it on a
 * Mac. Detection is client-side, so the static desktop markup is the SSR
 * default and mobile swaps in after mount.
 */
export function DownloadCTA({
  variant = "primary",
  className,
}: {
  variant?: Variant;
  className?: string;
}) {
  const [isMobile, setIsMobile] = useState(false);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    const ua = navigator.userAgent;
    const phoneOrTablet =
      /Android|iPhone|iPod|iPad|Mobile|Silk/i.test(ua) ||
      // iPadOS 13+ reports a desktop Mac UA but exposes touch points.
      (navigator.maxTouchPoints > 1 && /Macintosh/.test(ua));
    setIsMobile(phoneOrTablet);
  }, []);

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(window.location.origin);
      setCopied(true);
      setTimeout(() => setCopied(false), 2200);
    } catch {
      // Clipboard blocked, no-op; the URL is in the address bar regardless.
    }
  }

  const base = {
    nav: "btn-lift btn-glow rounded-md bg-orange px-3.5 py-1.5 font-medium text-bg0-hard hover:bg-yellow",
    primary:
      "btn-lift btn-glow group inline-flex items-center gap-2 rounded-lg bg-orange px-6 py-3 text-sm font-semibold text-bg0-hard hover:bg-yellow",
    navlink: "cursor-pointer text-fg3 transition-colors hover:text-fg0",
  }[variant];

  const cls = `${base}${className ? ` ${className}` : ""}`;

  // Desktop (and SSR / no-JS default): a genuine download link.
  if (!isMobile) {
    if (variant === "navlink") {
      return (
        <a href="/api/download" className={cls}>
          download
        </a>
      );
    }
    if (variant === "nav") {
      return (
        <a href="/api/download" className={cls}>
          Download
        </a>
      );
    }
    return (
      <a href="/api/download" className={cls}>
        Download for macOS
        <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
      </a>
    );
  }

  // Mobile: copy the link to open on a Mac instead of downloading a .dmg.
  if (variant === "navlink") {
    return (
      <button type="button" onClick={copyLink} aria-live="polite" className={cls}>
        {copied ? "link copied" : "copy link"}
      </button>
    );
  }
  if (variant === "nav") {
    return (
      <button type="button" onClick={copyLink} aria-live="polite" className={cls}>
        {copied ? "Copied ✓" : "Copy link"}
      </button>
    );
  }
  return (
    <button
      type="button"
      onClick={copyLink}
      aria-live="polite"
      className={cls}
      aria-label="Nab is a macOS app, copy the link to open on your Mac"
    >
      {copied ? (
        <>
          <Check className="h-4 w-4" />
          Copied, open on your Mac
        </>
      ) : (
        <>
          <Copy className="h-4 w-4" />
          Copy link for your Mac
        </>
      )}
    </button>
  );
}
