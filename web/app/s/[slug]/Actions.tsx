"use client";

import { useState } from "react";
import { Check, Copy, ClipboardCopy, ImageDown, Loader2 } from "lucide-react";

const BTN =
  "btn-lift inline-flex items-center gap-2 rounded-lg border border-bg3 px-4 py-2 font-mono text-sm text-fg1 hover:border-fg3 hover:text-fg0 disabled:opacity-60";

/** Copy-the-link button for the viewer. */
export function CopyLink({ url }: { url: string }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {
      // Clipboard blocked (insecure context / permissions), no-op; the link
      // is visible in the address bar regardless.
    }
  }

  return (
    <button type="button" onClick={copy} aria-live="polite" className={BTN}>
      {copied ? <Check className="h-4 w-4 text-green" /> : <Copy className="h-4 w-4" />}
      {copied ? "copied" : "copy link"}
    </button>
  );
}

/** Copy the raw snippet text (not the link) to the clipboard. */
export function CopyText({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {
      // Clipboard unavailable, the snippet is selectable on the page.
    }
  }

  return (
    <button type="button" onClick={copy} aria-live="polite" className={BTN}>
      {copied ? (
        <Check className="h-4 w-4 text-green" />
      ) : (
        <ClipboardCopy className="h-4 w-4" />
      )}
      {copied ? "copied" : "copy text"}
    </button>
  );
}

/**
 * Render the snippet card (element `targetId`) to a PNG and download it.
 * html-to-image is imported lazily so it never weighs on the initial page load.
 */
// OS-installed font stacks. The page's fonts come from next/font (hashed family
// names) which don't resolve inside a serialized SVG's foreignObject, the
// fallback there collapses to the default serif. Forcing a stack of fonts that
// actually ship on the OS keeps the exported PNG monospaced (code) / sans
// (prose) with correct spacing.
const MONO_STACK =
  'ui-monospace, Menlo, Monaco, Consolas, "Cascadia Mono", "Liberation Mono", "Courier New", monospace';
const SANS_STACK =
  '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif';

export function ExportPng({
  targetId,
  filename,
  mono = false,
}: {
  targetId: string;
  filename: string;
  /** True for code/terminal snippets, export in a monospace fallback. */
  mono?: boolean;
}) {
  const [busy, setBusy] = useState(false);

  async function exportPng() {
    const node = document.getElementById(targetId);
    if (!node) return;
    setBusy(true);
    // Unclip the inner scroller so a tall snippet exports in full rather than
    // at its 70dvh view height. Restored in `finally` (the swap is ~15ms).
    const scroller = node.firstElementChild as HTMLElement | null;
    const prevMaxH = scroller?.style.maxHeight;
    const prevOverflow = scroller?.style.overflow;
    if (scroller) {
      scroller.style.maxHeight = "none";
      scroller.style.overflow = "visible";
    }
    // Swap to a render-safe font stack just for the capture (restored below).
    const prevFont = node.style.fontFamily;
    node.style.fontFamily = mono ? MONO_STACK : SANS_STACK;
    try {
      // Use html-to-image only to serialize the node to an <svg> data URL, then
      // rasterize it ourselves. html-to-image's own toPng/toCanvas awaits
      // `img.decode()`, which never resolves for foreignObject SVGs in Chrome
      // (the snippet would hang on "exporting…" forever). An onload-based image
      // load into a canvas is reliable.
      const { toSvg } = await import("html-to-image");
      const bg = getComputedStyle(node).backgroundColor || "rgb(29, 32, 33)"; // bg0-hard
      const svgUrl = await toSvg(node, { skipFonts: true });

      const img = await loadImage(svgUrl);
      const rect = node.getBoundingClientRect();
      const w = Math.ceil(rect.width);
      const h = Math.ceil(rect.height);
      const scale = 2; // crisp on HiDPI without ballooning file size
      const canvas = document.createElement("canvas");
      canvas.width = w * scale;
      canvas.height = h * scale;
      const ctx = canvas.getContext("2d");
      if (!ctx) return;
      ctx.fillStyle = bg;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.scale(scale, scale);
      ctx.drawImage(img, 0, 0, w, h);

      const a = document.createElement("a");
      a.href = canvas.toDataURL("image/png");
      a.download = filename;
      a.click();
    } catch {
      // Rendering failed (rare), leave the page untouched.
    } finally {
      node.style.fontFamily = prevFont;
      if (scroller) {
        scroller.style.maxHeight = prevMaxH ?? "";
        scroller.style.overflow = prevOverflow ?? "";
      }
      setBusy(false);
    }
  }

  /** Load a data-URL image via `onload` (not `decode`), with a safety timeout. */
  function loadImage(src: string): Promise<HTMLImageElement> {
    return new Promise((resolve, reject) => {
      const img = new Image();
      const timer = setTimeout(() => reject(new Error("image load timed out")), 15000);
      img.onload = () => {
        clearTimeout(timer);
        resolve(img);
      };
      img.onerror = () => {
        clearTimeout(timer);
        reject(new Error("image load failed"));
      };
      img.src = src;
    });
  }

  return (
    <button
      type="button"
      onClick={exportPng}
      disabled={busy}
      aria-live="polite"
      className={BTN}
    >
      {busy ? (
        <Loader2 className="h-4 w-4 animate-spin" />
      ) : (
        <ImageDown className="h-4 w-4" />
      )}
      {busy ? "exporting…" : "export png"}
    </button>
  );
}
