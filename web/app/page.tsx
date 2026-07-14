import { ArrowRight } from "lucide-react";
import CaptureMock from "./CaptureMock";
import Reveal from "./Reveal";
import { DownloadCTA } from "./DownloadCTA";

/** One aligned line of the `nab --help` cheatsheet: key · what it does · result. */
function HelpRow({
  k,
  children,
  note,
  noteTone = "gray",
}: {
  k: React.ReactNode;
  children: React.ReactNode;
  note?: string;
  noteTone?: "gray" | "orange";
}) {
  return (
    <div className="group grid grid-cols-[5.5rem_1fr] items-baseline gap-x-5 rounded-md px-2 py-1.5 -mx-2 transition-colors hover:bg-bg1/50 sm:grid-cols-[7rem_1fr]">
      <div className="font-mono text-sm text-orange">{k}</div>
      <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-0.5">
        <span className="text-fg1">{children}</span>
        {note && (
          <span
            className={`font-mono text-xs ${noteTone === "orange" ? "text-orange/90" : "text-gray"}`}
          >
            {note}
          </span>
        )}
      </div>
    </div>
  );
}

function HelpGroup({ label }: { label: string }) {
  return (
    <div className="px-2 pt-4 pb-1 font-mono text-[11px] uppercase tracking-[0.14em] text-gray first:pt-0">
      {label}
    </div>
  );
}

export default function Home() {
  return (
    <div className="relative min-h-dvh font-sans">
      {/* Nav */}
      <header className="sticky top-0 z-40 border-b border-bg1/70 bg-bg0/75 backdrop-blur">
        <nav className="mx-auto flex max-w-6xl items-center justify-between px-6 py-3.5">
          <a
            href="#top"
            className="font-mono text-sm font-semibold tracking-tight text-fg0"
          >
            <span className="text-orange">~/</span>nab
            <span className="ml-0.5 inline-block animate-blink text-orange">
              ▋
            </span>
          </a>
          <div className="flex items-center gap-1 text-sm sm:gap-2">
            <a
              href="#manual"
              className="hidden rounded-md px-3 py-1.5 text-fg3 transition-colors hover:text-fg0 sm:block"
            >
              Manual
            </a>
            <a
              href="/docs"
              className="hidden rounded-md px-3 py-1.5 text-fg3 transition-colors hover:text-fg0 sm:block"
            >
              Docs
            </a>
            <DownloadCTA variant="nav" />
          </div>
        </nav>
      </header>

      <main id="top" className="relative overflow-hidden">
        {/* Drifting warm aurora behind the hero, the page's fluid pulse. */}
        <div className="hero-aurora" aria-hidden="true">
          <span className="a1" />
          <span className="a2" />
          <span className="a3" />
        </div>
        <div className="bg-grid absolute inset-0 -z-10 h-215" />

        {/* Hero, asymmetric split: copy left, live capture right. Never centered. */}
        <section className="mx-auto grid max-w-6xl grid-cols-1 items-center gap-y-14 px-6 pb-24 pt-14 lg:grid-cols-[1.05fr_1fr] lg:gap-x-16 lg:pt-24">
          <div className="flex max-w-xl flex-col items-start">
            <h1
              className="stagger-item text-[clamp(2.5rem,5.4vw,4.25rem)] font-bold leading-[1.02] tracking-[-0.03em] text-fg0"
              style={{ "--i": 0 } as React.CSSProperties}
            >
              <span className="text-underline-draw">Nab</span> it. It&apos;s
              already on your <span className="hero-accent">clipboard</span>
              <span className="hero-caret animate-blink" aria-hidden="true" />
            </h1>
            <p
              className="stagger-item mt-6 text-lg leading-relaxed text-fg1"
              style={{ "--i": 1 } as React.CSSProperties}
            >
              A menubar capture tool that drops a clean link onto your clipboard
              the instant you nab, and it previews inline in Discord and Slack.
              Use Nab hosting out of the box, or bring your own R2 / S3 bucket.
            </p>
            <div
              className="stagger-item mt-8 flex flex-wrap items-center gap-x-6 gap-y-3"
              style={{ "--i": 2 } as React.CSSProperties}
            >
              <DownloadCTA variant="primary" />
              <a
                href="/docs"
                className="group inline-flex items-center gap-1.5 text-sm font-medium text-fg3 transition-colors hover:text-fg0"
              >
                Read the docs
                <ArrowRight className="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5" />
              </a>
            </div>
            <p
              className="stagger-item mt-5 font-mono text-xs text-gray"
              style={{ "--i": 3 } as React.CSSProperties}
            >
              requires macOS 13+ · Apple Silicon &amp; Intel
            </p>
          </div>

          {/* Product mock, the pitch, playing live */}
          <div
            className="stagger-item w-full lg:justify-self-end"
            style={{ "--i": 2 } as React.CSSProperties}
          >
            <CaptureMock />
          </div>
        </section>

        {/* The manual, the whole tool, as its own `--help` output, next to the
            one bit of proof that matters (it unfurls inline). No feature cards. */}
        <section id="manual" className="mx-auto max-w-6xl px-6 pb-28 pt-4">
          <Reveal>
            <div className="max-w-2xl">
              <h2 className="text-3xl font-bold tracking-[-0.02em] text-fg0 sm:text-[2.6rem]">
                The whole thing fits in{" "}
                <span className="font-mono text-orange">--help</span>.
              </h2>
              <p className="mt-4 max-w-xl text-lg leading-relaxed text-fg3">
                Two taps and a link on your clipboard. There&apos;s nothing to
                learn, so here&apos;s all of it, on one screen.
              </p>
            </div>
          </Reveal>

          <Reveal className="mt-12">
            <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1.15fr_1fr]">
              {/* nab --help cheatsheet, rendered as a terminal window */}
              <div className="overflow-hidden rounded-xl border border-bg2 bg-bg0-hard shadow-2xl shadow-black/40">
                <div className="flex items-center gap-2 border-b border-bg1 bg-bg1/60 px-4 py-2.5 font-mono text-xs text-gray">
                  <span className="h-3 w-3 rounded-full bg-red" />
                  <span className="h-3 w-3 rounded-full bg-yellow" />
                  <span className="h-3 w-3 rounded-full bg-green" />
                  <span className="ml-3">nab · the manual</span>
                </div>
                <div className="px-5 py-5 sm:px-6">
                  <p className="font-mono text-sm">
                    <span className="text-green">~/nab</span>{" "}
                    <span className="text-gray">$</span> nab{" "}
                    <span className="text-fg0">--help</span>
                  </p>
                  <div className="mt-4 space-y-1">
                    <HelpGroup label="gestures" />
                    <HelpRow k="⌘ ⌘" note="link copied">
                      Capture a screen region
                    </HelpRow>
                    <HelpRow k="⌃ ⌃" note="link copied">
                      Share your text selection
                    </HelpRow>
                    <HelpRow k="⇧ +" note="raw link">
                      Hold Shift for the direct image / .txt
                    </HelpRow>

                    <HelpGroup label="where links live" />
                    <HelpRow k="hosted" note="default" noteTone="orange">
                      Zero config, links last 30 days
                    </HelpRow>
                    <HelpRow k="bucket" note="optional">
                      Your R2 / S3, links never expire
                    </HelpRow>

                    <HelpGroup label="runs in" />
                    <HelpRow k="menubar" note="✂">
                      No dock icon, no window to manage
                    </HelpRow>
                  </div>
                </div>
              </div>

              {/* The proof: a shared link unfurling inline in chat */}
              <div className="flex flex-col justify-center gap-4">
                <div className="rounded-xl border border-bg2 bg-bg0-hard/60 p-4 font-mono text-sm">
                  <div className="flex items-center gap-2.5">
                    <span className="flex h-8 w-8 items-center justify-center rounded-full bg-orange/20 text-xs font-bold text-orange">
                      jae
                    </span>
                    <span className="font-semibold text-fg1">jae</span>
                    <span className="text-xs text-gray">today at 2:14 PM</span>
                  </div>
                  <p className="mt-2 pl-[2.75rem] text-fg3">
                    found the bug -{" "}
                    <span className="text-blue underline decoration-bg3 underline-offset-2">
                      nab.sh/aB3x9.png
                    </span>
                  </p>
                  <div className="mt-2 ml-[2.75rem] overflow-hidden rounded-lg border border-bg2">
                    <div className="flex items-center gap-1.5 border-b border-bg1 bg-bg1/50 px-3 py-1.5 text-[11px] text-gray">
                      <span className="h-2 w-2 rounded-full bg-red" />
                      <span className="h-2 w-2 rounded-full bg-yellow" />
                      <span className="h-2 w-2 rounded-full bg-green" />
                      <span className="ml-1.5">aB3x9.png</span>
                    </div>
                    <div className="h-28 w-full bg-[repeating-linear-gradient(45deg,#32302f_0_11px,#282828_11px_22px)]" />
                  </div>
                </div>
                <p className="px-1 text-sm leading-relaxed text-fg3">
                  No click-through, no “open in browser.” The link unfurls into
                  the image right where you paste it, Discord, Slack, a GitHub
                  comment.
                </p>
              </div>
            </div>
          </Reveal>
        </section>

        {/* Closing, a shell prompt, not a “ready to get started?” billboard */}
        <Reveal>
          <section className="mx-auto max-w-6xl px-6 pb-24">
            <div className="flex flex-col items-start justify-between gap-6 border-t border-bg2 pt-12 sm:flex-row sm:items-center">
              <p className="font-mono text-lg text-fg1 sm:text-xl">
                <span className="text-green">~/nab</span>{" "}
                <span className="text-gray">$</span> your next screenshot is a
                link
                <span className="ml-1 inline-block animate-blink text-orange">
                  ▋
                </span>
              </p>
              <DownloadCTA variant="primary" className="shrink-0" />
            </div>
          </section>
        </Reveal>

        {/* Footer, TUI modeline */}
        <footer className="border-t border-bg2 bg-bg0-hard">
          <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-4 gap-y-1 px-6 py-3 font-mono text-xs">
            <span className="rounded bg-orange px-2 py-0.5 font-semibold text-bg0-hard">
              NORMAL
            </span>
            <span className="text-fg1">nab 0.3.0</span>
            <span className="text-gray">hosted or self-host</span>
            <a href="/privacy" className="text-gray transition-colors hover:text-fg0">
              privacy
            </a>
            <a href="/terms" className="text-gray transition-colors hover:text-fg0">
              terms
            </a>
            <span className="ml-auto text-gray">~/nab</span>
          </div>
        </footer>
      </main>
    </div>
  );
}
