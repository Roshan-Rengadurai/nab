import { ArrowRight, Command, Crosshair, Database, MessageSquare } from "lucide-react";
import CaptureMock from "./CaptureMock";
import Reveal from "./Reveal";
import Terminal from "./Terminal";
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";

function FeatureCard({
  icon: Icon,
  iconClassName,
  title,
  className,
  index = 0,
  children,
}: {
  icon: React.ElementType;
  iconClassName: string;
  title: string;
  className?: string;
  index?: number;
  children: React.ReactNode;
}) {
  return (
    <div
      className={`stagger-item card-lift rounded-2xl border border-bg2 bg-bg0-hard/40 p-6 sm:p-7 ${className ?? ""}`}
      style={{ "--i": index } as React.CSSProperties}
    >
      <Icon className={`h-6 w-6 ${iconClassName}`} />
      <h3 className="mt-4 text-lg font-semibold tracking-tight text-fg0">
        {title}
      </h3>
      <div className="mt-2 leading-relaxed text-fg3">{children}</div>
    </div>
  );
}

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
            <span className="text-orange">~/</span>nab
            <span className="ml-0.5 inline-block animate-blink text-orange">
              ▋
            </span>
          </a>
          <div className="flex items-center gap-1 text-sm sm:gap-2">
            <a
              href="#features"
              className="hidden rounded-md px-3 py-1.5 text-fg3 transition-colors hover:text-fg0 sm:block"
            >
              Features
            </a>
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

        {/* Hero — centered composition, staggered entrance */}
        <section className="mx-auto flex max-w-3xl flex-col items-center px-6 pb-24 pt-20 text-center lg:pt-28">
          <span
            className="stagger-item inline-flex items-center gap-2 rounded-full border border-bg2 bg-bg0-hard/60 px-3 py-1 font-mono text-xs text-fg3"
            style={{ "--i": 0 } as React.CSSProperties}
          >
            <span className="h-1.5 w-1.5 rounded-full bg-green" />
            macOS menubar utility
          </span>
          <h1
            className="stagger-item mt-6 text-[clamp(2.5rem,6vw,4rem)] font-bold leading-[1.05] tracking-tight text-fg0"
            style={{ "--i": 1 } as React.CSSProperties}
          >
            <span className="text-underline-draw">Nab</span> it. It&apos;s
            already on your{" "}
            <span className="text-shimmer">clipboard</span>.
          </h1>
          <p
            className="stagger-item mt-6 max-w-xl text-lg leading-relaxed text-balance text-fg1"
            style={{ "--i": 2 } as React.CSSProperties}
          >
            A menubar capture tool that drops a clean link onto your clipboard
            the instant you nab — and it previews inline in Discord and Slack.
            Use Nab hosting out of the box, or bring your own R2 / S3 bucket.
          </p>
          <div
            className="stagger-item mt-9 flex flex-wrap items-center justify-center gap-3"
            style={{ "--i": 3 } as React.CSSProperties}
          >
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
          <p
            className="stagger-item mt-5 font-mono text-xs text-gray"
            style={{ "--i": 4 } as React.CSSProperties}
          >
            requires macOS 13+ · Apple Silicon &amp; Intel
          </p>

          {/* Product mock — centered below the copy */}
          <div
            className="stagger-item mt-16 w-full max-w-xl"
            style={{ "--i": 5 } as React.CSSProperties}
          >
            <CaptureMock />
          </div>
        </section>

        {/* Features */}
        <section id="features" className="mx-auto max-w-5xl px-6 pb-28">
          <Reveal>
            <div className="mx-auto max-w-xl text-center">
              <span className="font-mono text-sm text-orange">// why nab</span>
              <h2 className="mt-3 text-3xl font-bold tracking-tight text-fg0 sm:text-4xl">
                Built to disappear.
              </h2>
              <p className="mt-4 text-lg leading-relaxed text-fg3">
                No workflow to learn, no settings to fight before your first
                capture lands where you need it.
              </p>
            </div>
          </Reveal>

          <div className="mt-14 grid gap-4 md:grid-cols-12">
              <FeatureCard
                icon={Crosshair}
                iconClassName="text-orange"
                title="One motion, one link"
                className="md:col-span-7"
                index={0}
              >
                Drag a region or grab your current text selection — by the
                time you let go, a clean link is already sitting on your
                clipboard. No dialog, no export step.
              </FeatureCard>

              <FeatureCard
                icon={MessageSquare}
                iconClassName="text-aqua"
                title="Inline everywhere"
                className="md:col-span-5"
                index={1}
              >
                <p>
                  Paste into Discord or Slack and it unfurls immediately —
                  nobody has to click through to see what you sent.
                </p>
                <div className="mt-4 rounded-lg border border-bg2 bg-bg0-hard/80 p-3 font-mono text-xs">
                  <div className="flex items-center gap-2">
                    <span className="flex h-6 w-6 items-center justify-center rounded-full bg-orange/20 text-[10px] font-bold text-orange">
                      JD
                    </span>
                    <span className="font-semibold text-fg1">jae</span>
                    <span className="text-gray">today at 2:14 PM</span>
                  </div>
                  <p className="mt-1.5 text-fg3">
                    check this out — nab.sh/aB3x9.png
                  </p>
                  <div className="mt-2 h-20 w-full rounded-md bg-[repeating-linear-gradient(45deg,#32302f_0_10px,#282828_10px_20px)]" />
                </div>
              </FeatureCard>

              <FeatureCard
                icon={Database}
                iconClassName="text-yellow"
                title="Your bucket, your rules"
                className="md:col-span-5"
                index={2}
              >
                <p>
                  Hosted by default, so links work immediately. Connect
                  Cloudflare R2 or any S3-compatible bucket and links stop
                  expiring.
                </p>
                <a
                  href="#self-host"
                  className="mt-4 inline-flex items-center gap-1.5 text-sm font-medium text-orange transition-colors hover:text-yellow"
                >
                  See self-host setup
                  <ArrowRight className="h-3.5 w-3.5" />
                </a>
              </FeatureCard>

              <FeatureCard
                icon={Command}
                iconClassName="text-green"
                title="Lives in your menubar"
                className="md:col-span-7"
                index={3}
              >
                <p>
                  No dock icon, no window to manage. It sits in your menubar
                  until you need it.
                </p>
                <div className="mt-4 flex flex-wrap gap-2">
                  <Badge variant="secondary" className="font-mono">
                    ⌘⌘ region
                  </Badge>
                  <Badge variant="secondary" className="font-mono">
                    ⌃⌃ text selection
                  </Badge>
                </div>
              </FeatureCard>
            </div>
        </section>

        {/* Hosted vs. self-host */}
        <Reveal>
          <section id="self-host" className="px-6 pb-28">
            <div className="mx-auto max-w-3xl text-center">
              <h2 className="text-3xl font-bold tracking-tight text-fg0 sm:text-4xl">
                Start nabbing in seconds.
              </h2>
              <p className="mx-auto mt-4 max-w-lg text-lg leading-relaxed text-fg3">
                Nab hosts your links for free — nothing to set up. Want full
                control instead? Point it at your own R2 or S3 bucket.
              </p>
            </div>

            <div className="bg-ambient mx-auto mt-10 max-w-3xl rounded-2xl border border-bg2 bg-bg0-hard/40 p-6 sm:p-8">
              <Tabs defaultValue="hosted" className="items-center">
                <TabsList>
                  <TabsTrigger value="hosted">Hosted</TabsTrigger>
                  <TabsTrigger value="self-host">Self-host</TabsTrigger>
                </TabsList>
                <TabsContent value="hosted" className="mt-6 w-full">
                  <Terminal title="zero config">
                    {`✂  tap ⌘ twice → drag a region
✓  link copied — nab.sh/aB3x9.png

no account, no bucket, nothing to configure.
hosted links expire after 30 days.`}
                  </Terminal>
                </TabsContent>
                <TabsContent value="self-host" className="mt-6 w-full">
                  <Terminal title="Settings → Storage">
                    {`Endpoint   https://<ACCOUNT_ID>.r2.cloudflarestorage.com
Bucket     shots
Region     auto

your bucket, your links — they never expire.`}
                  </Terminal>
                </TabsContent>
              </Tabs>
            </div>

            <div className="mt-8 text-center">
              <a
                href="/docs"
                className="btn-lift inline-flex items-center gap-2 rounded-lg border border-bg3 px-6 py-3 text-sm font-medium text-fg1 hover:border-fg3 hover:text-fg0"
              >
                Read the setup guide
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
            <span className="text-fg1">nab 0.1.0</span>
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
