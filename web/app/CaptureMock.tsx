"use client";

import { useEffect, useRef, useState } from "react";

function Kbd({ children }: { children: React.ReactNode }) {
  return (
    <kbd className="rounded-md border border-bg3 bg-bg1 px-2 py-1 font-mono text-xs text-fg1 shadow-[0_2px_0_0_var(--color-bg0-hard)]">
      {children}
    </kbd>
  );
}

// Drag origin (top-left of the selection) as a % of the capture surface.
const ORIGIN_X = 11;
const ORIGIN_Y = 17;

// A loop of selections at different aspect ratios.
const SHOTS = [
  { w: 56, h: 50, label: "824 × 412", id: "aB3x9" },
  { w: 37, h: 64, label: "468 × 720", id: "kL7p2" },
  { w: 74, h: 32, label: "1280 × 360", id: "9fQ2w" },
  { w: 46, h: 46, label: "600 × 600", id: "Zx4m8" },
];

export default function CaptureMock() {
  const [i, setI] = useState(0);
  const [open, setOpen] = useState(false); // selection dragged out?
  const [captured, setCaptured] = useState(false); // link on clipboard?
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const reduce = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;
    if (reduce) {
      setOpen(true);
      setCaptured(true);
      return;
    }

    let running = false;
    let idx = 0;
    const timers: ReturnType<typeof setTimeout>[] = [];
    const clear = () => {
      timers.forEach(clearTimeout);
      timers.length = 0;
    };
    const after = (ms: number, fn: () => void) =>
      timers.push(setTimeout(fn, ms));

    const cycle = () => {
      if (!running) return;
      setI(idx);
      setCaptured(false);
      setOpen(false); // snap cursor back to origin
      after(420, () => setOpen(true)); // drag the region out
      after(1500, () => setCaptured(true)); // release → copied
      after(3100, () => {
        idx = (idx + 1) % SHOTS.length;
        cycle();
      });
    };

    // Only animate while on-screen and the tab is visible — no wasted CPU/battery
    // looping behind a scrolled-past hero or a backgrounded tab.
    let onScreen = true;
    const sync = () => {
      const shouldRun = onScreen && document.visibilityState === "visible";
      if (shouldRun && !running) {
        running = true;
        cycle();
      } else if (!shouldRun && running) {
        running = false;
        clear();
      }
    };

    const io = new IntersectionObserver(
      ([entry]) => {
        onScreen = entry.isIntersecting;
        sync();
      },
      { threshold: 0.1 },
    );
    const el = ref.current;
    if (el) io.observe(el);
    document.addEventListener("visibilitychange", sync);

    return () => {
      running = false;
      clear();
      io.disconnect();
      document.removeEventListener("visibilitychange", sync);
    };
  }, []);

  const shot = SHOTS[i];
  const w = open ? shot.w : 0;
  const h = open ? shot.h : 0;
  const curX = ORIGIN_X + w; // crosshair / drag-handle position
  const curY = ORIGIN_Y + h;

  return (
    <div
      ref={ref}
      className="overflow-hidden rounded-xl border border-bg2 bg-bg0-hard shadow-2xl shadow-black/40"
    >
      {/* window chrome */}
      <div className="flex items-center gap-2 border-b border-bg1 bg-bg1/60 px-4 py-2.5">
        <span className="h-3 w-3 rounded-full bg-red" />
        <span className="h-3 w-3 rounded-full bg-yellow" />
        <span className="h-3 w-3 rounded-full bg-green" />
        <span className="ml-3 font-mono text-xs text-gray">
          screen — region capture
        </span>
      </div>

      {/* capture surface */}
      <div className="relative h-56 overflow-hidden bg-[repeating-linear-gradient(45deg,#32302f_0_12px,#282828_12px_24px)]">
        {/* dimmed backdrop that clears inside the selection */}
        <div
          className="pointer-events-none absolute inset-0 bg-bg0-hard/45 transition-opacity duration-500"
          style={{ opacity: open ? 1 : 0 }}
        />

        {/* crosshair guide lines — they track the drag handle */}
        <div
          className="crosshair-line pointer-events-none absolute top-0 h-full w-px bg-orange/40"
          style={{
            left: `${curX}%`,
            opacity: captured ? 0 : 1,
          }}
        />
        <div
          className="crosshair-line pointer-events-none absolute left-0 h-px w-full bg-orange/40"
          style={{
            top: `${curY}%`,
            opacity: captured ? 0 : 1,
          }}
        />

        {/* the selection marquee — settles to a solid border once captured */}
        <div
          className={`marquee pointer-events-none absolute rounded-[3px] border-2 bg-orange/10 ${
            captured
              ? "border-solid border-green"
              : "border-dashed border-orange"
          }`}
          style={{
            left: `${ORIGIN_X}%`,
            top: `${ORIGIN_Y}%`,
            width: `${w}%`,
            height: `${h}%`,
          }}
        >
          {/* dimension badge */}
          <span
            className={`absolute -top-6 left-0 whitespace-nowrap rounded px-1.5 py-0.5 font-mono text-[10px] font-semibold text-bg0-hard transition-colors duration-300 ${
              captured ? "bg-green" : "bg-orange"
            }`}
            style={{ opacity: open ? 1 : 0 }}
          >
            {shot.label}
          </span>
          {/* corner handles */}
          <span
            className={`absolute -left-[3px] -top-[3px] h-2 w-2 rounded-[1px] transition-colors duration-300 ${captured ? "bg-green" : "bg-orange"}`}
          />
          <span
            className={`absolute -right-[3px] -top-[3px] h-2 w-2 rounded-[1px] transition-colors duration-300 ${captured ? "bg-green" : "bg-orange"}`}
          />
          <span
            className={`absolute -bottom-[3px] -left-[3px] h-2 w-2 rounded-[1px] transition-colors duration-300 ${captured ? "bg-green" : "bg-orange"}`}
          />
          <span
            className={`absolute -bottom-[3px] -right-[3px] h-2 w-2 rounded-[1px] transition-colors duration-300 ${captured ? "bg-green" : "bg-orange"}`}
          />
        </div>

        {/* the cross cursor at the drag handle */}
        <div
          className="crosshair-line pointer-events-none absolute z-10"
          style={{
            left: `${curX}%`,
            top: `${curY}%`,
            transform: "translate(-50%, -50%)",
            opacity: captured ? 0 : 1,
          }}
        >
          <svg width="22" height="22" viewBox="0 0 22 22" aria-hidden="true">
            <path
              d="M11 1.5v19M1.5 11h19"
              stroke="var(--color-orange)"
              strokeWidth="1.5"
              strokeLinecap="round"
            />
            <circle
              cx="11"
              cy="11"
              r="2.5"
              fill="none"
              stroke="var(--color-orange)"
              strokeWidth="1.5"
            />
          </svg>
        </div>

      </div>

      {/* toast — the confirmation moment. A soft success wash sweeps the row on
          capture, and the whole strip lifts in, so the "copied" state reads
          without a blinding full-screen flash. */}
      <div
        key={captured ? `toast-${i}` : "toast-idle"}
        className={`relative flex items-center gap-3 overflow-hidden border-t border-bg1 bg-bg0 px-4 py-3 ${
          captured ? "animate-toast-in" : ""
        }`}
      >
        {/* success wash — bounded to the toast strip, fully fades */}
        <div
          key={captured ? `wash-${i}` : "nowash"}
          className={`pointer-events-none absolute inset-0 bg-green/10 ${
            captured ? "animate-wash" : "opacity-0"
          }`}
        />
        <span
          className={`relative flex h-7 w-7 shrink-0 items-center justify-center rounded-full font-mono text-sm transition-colors duration-300 ${
            captured ? "bg-green/15 text-green" : "bg-bg2/60 text-gray"
          }`}
        >
          <span key={`chk-${captured}-${i}`} className={captured ? "animate-pop" : ""}>
            {captured ? "✓" : "⣿"}
          </span>
        </span>
        <div className="relative min-w-0 font-mono text-xs">
          <div className="text-fg3">
            {captured ? "copied to clipboard" : "drag to select a region"}
          </div>
          <div
            className="truncate text-fg0 transition-opacity duration-200"
            style={{ opacity: captured ? 1 : 0.35 }}
          >
            nab.sh/<span className="text-orange">{shot.id}</span>.png
          </div>
        </div>
        <div className="relative ml-auto hidden shrink-0 items-center gap-1.5 sm:flex">
          <span className="font-mono text-[10px] text-gray">double-tap</span>
          <Kbd>⌘</Kbd>
        </div>
      </div>
    </div>
  );
}
