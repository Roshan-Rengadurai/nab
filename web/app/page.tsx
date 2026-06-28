import { ArrowRight } from "lucide-react";
import CaptureMock from "./CaptureMock";
import Reveal from "./Reveal";

export default function Home() {
  return (
    <div className="relative min-h-dvh font-sans">
      {/* Nav */}
      <header className="sticky top-0 z-40 border-b border-bg1/70 bg-bg0/75 backdrop-blur">
        <nav className="mx-auto flex max-w-5xl items-center justify-between px-6 py-3.5">
          <a
            href="#top"
            className="font-mono text-sm font-semibold tracking-tight text-fg0"
          >
            <span className="text-orange">~/</span>snip
            <span className="ml-0.5 inline-block animate-blink text-orange">
              ▋
            </span>
          </a>
          <div className="flex items-center gap-1 text-sm sm:gap-2">
            <a
              href="/docs"
              className="hidden rounded-md px-3 py-1.5 text-fg3 transition-colors hover:text-fg0 sm:block"
            >
              Docs
            </a>
            <a
              href="/api/download"
              className="btn-lift btn-glow rounded-md bg-orange px-3.5 py-1.5 font-medium text-bg0-hard hover:bg-yellow"
            >
              Download
            </a>
          </div>
        </nav>
      </header>

      <main id="top" className="relative overflow-hidden">
        <div className="bg-ambient absolute inset-0 -z-10 h-215" />
        <div className="bg-grid absolute inset-0 -z-10 h-215" />

        {/* Hero */}
        <section className="mx-auto grid max-w-5xl items-center gap-14 px-6 pb-28 pt-20 lg:grid-cols-[1.05fr_1fr] lg:gap-12 lg:pt-28">
          <div className="animate-rise">
            <span className="inline-flex items-center gap-2 rounded-full border border-bg2 bg-bg0-hard/60 px-3 py-1 font-mono text-xs text-fg3">
              <span className="h-1.5 w-1.5 rounded-full bg-green" />
              macOS menubar utility
            </span>
            <h1 className="mt-5 text-[clamp(2.5rem,6vw,4rem)] font-bold leading-[1.05] tracking-tight text-fg0">
              <span className="text-underline-draw">Snip</span> it. It&apos;s
              already on your{" "}
              <span className="text-shimmer">clipboard</span>.
            </h1>
            <p className="mt-6 max-w-md text-lg leading-relaxed text-fg1">
              A menubar capture tool that drops a clean link onto your clipboard
              the instant you snip. Use Snip hosting out of the box, or
              bring your own R2 / S3 bucket.
            </p>
            <div className="mt-9 flex flex-wrap items-center gap-3">
              <a
                href="/api/download"
                className="btn-lift btn-glow group inline-flex items-center gap-2 rounded-lg bg-orange px-6 py-3 text-sm font-semibold text-bg0-hard hover:bg-yellow"
              >
                Download for macOS
                <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
              </a>
              <a
                href="/docs"
                className="btn-lift rounded-lg border border-bg3 px-6 py-3 text-sm font-medium text-fg1 hover:border-fg3 hover:text-fg0"
              >
                Read the docs
              </a>
            </div>
            <p className="mt-5 font-mono text-xs text-gray">
              requires macOS 13+ · Apple Silicon &amp; Intel
            </p>
          </div>

          {/* Product mock */}
          <div className="animate-rise [animation-delay:120ms]">
            <CaptureMock />
          </div>
        </section>

        {/* Download CTA */}
        <Reveal>
          <section className="px-6 pb-28">
            <div className="bg-ambient mx-auto max-w-3xl rounded-2xl border border-bg2 bg-bg0-hard/40 px-8 py-16 text-center">
              <h2 className="text-3xl font-bold tracking-tight text-fg0 sm:text-4xl">
                Start snipping in seconds.
              </h2>
              <p className="mx-auto mt-4 max-w-lg text-lg leading-relaxed text-fg3">
                Use Snip hosting out of the box — nothing to set up. Want to
                self-host? Connect your own R2 / S3 bucket in 90 seconds.
              </p>
              <a
                href="/api/download"
                className="btn-lift btn-glow mt-9 inline-flex items-center gap-2 rounded-lg bg-orange px-7 py-3 text-sm font-semibold text-bg0-hard hover:bg-yellow"
              >
                Download Snip
                <ArrowRight className="h-4 w-4" />
              </a>
            </div>
          </section>
        </Reveal>

        {/* Footer — TUI modeline */}
        <footer className="border-t border-bg2 bg-bg0-hard">
          <div className="mx-auto flex max-w-5xl flex-wrap items-center gap-x-4 gap-y-1 px-6 py-3 font-mono text-xs">
            <span className="rounded bg-orange px-2 py-0.5 font-semibold text-bg0-hard">
              NORMAL
            </span>
            <span className="text-fg1">snip 0.1.0</span>
            <span className="text-gray">hosted or self-host</span>
            <span className="ml-auto text-gray">~/snip</span>
          </div>
        </footer>
      </main>
    </div>
  );
}
