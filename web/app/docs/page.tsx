import type { Metadata } from "next";
import Terminal from "../Terminal";
import { DownloadCTA } from "../DownloadCTA";

export const metadata: Metadata = {
  title: "Nab · Setup guide",
  description:
    "Install Nab and start sharing immediately with free hosted links, or connect your own S3-compatible bucket (Cloudflare R2 or local MinIO) for full control.",
};

function Step({
  n,
  title,
  children,
}: {
  n: number;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="border-t border-bg1 py-14 first:border-t-0 first:pt-0">
      <div className="flex items-center gap-3">
        <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-orange font-mono text-sm font-bold text-bg0-hard">
          {n}
        </span>
        <h2 className="font-mono text-2xl font-bold tracking-tight text-fg0">
          {title}
        </h2>
      </div>
      <div className="mt-6 space-y-4">{children}</div>
    </section>
  );
}

function P({ children }: { children: React.ReactNode }) {
  return <p className="max-w-2xl leading-relaxed text-fg3">{children}</p>;
}

/** A list item with a terminal-style marker instead of a bare browser bullet. */
function Li({ children }: { children: React.ReactNode }) {
  return (
    <li className="flex gap-2.5 leading-relaxed text-fg3">
      <span aria-hidden className="mt-px select-none font-mono text-orange">
        ›
      </span>
      <span className="max-w-2xl">{children}</span>
    </li>
  );
}

export default function Docs() {
  return (
    <div className="relative flex min-h-dvh flex-col font-sans">
      <header className="sticky top-0 z-40 border-b border-bg1/80 bg-bg0/80 backdrop-blur">
        <nav className="mx-auto flex max-w-4xl items-center justify-between px-6 py-3">
          <a href="/" className="font-mono text-sm font-semibold tracking-tight text-fg0">
            <span className="text-orange">~/</span>nab
            <span className="text-gray">/docs</span>
          </a>
          <div className="flex items-center gap-4 font-mono text-xs sm:text-sm">
            <a href="/" className="cursor-pointer text-fg3 transition-colors hover:text-fg0">
              home
            </a>
            <DownloadCTA variant="navlink" />
          </div>
        </nav>
      </header>

      <main className="relative flex-1">
        {/* Warm bloom anchored behind the page header only. */}
        <div className="bg-ambient pointer-events-none absolute inset-x-0 top-0 -z-10 h-96" />

        <div className="mx-auto max-w-4xl px-6">
          <section className="animate-rise pb-14 pt-16 sm:pt-20">
            <p className="font-mono text-sm text-orange">// setup guide</p>
            <h1 className="mt-3 font-mono text-4xl font-bold tracking-tight text-fg0 sm:text-5xl">
              From zero to one nab.
            </h1>
            <p className="mt-5 max-w-2xl text-lg leading-relaxed text-fg1">
              Nab captures a region or your text selection and drops a clean
              link onto your clipboard. Hosted links work the moment you
              install, bring your own bucket only if you want to.
            </p>
          </section>

          <Step n={1} title="Install">
            <P>
              Download the <span className="font-mono text-orange">.dmg</span>,
              open it, and drag Nab onto the Applications folder in the window
              that appears. Requires macOS 13+, Apple Silicon or Intel
              (universal build).
            </P>
            <P>
              Nab is an open-source indie app signed without a paid Apple
              Developer account, so the first launch trips Gatekeeper. This is
              expected, to get past it:
            </P>
            <ul className="space-y-2">
              <Li>
                <span className="font-mono text-aqua">Right-click</span> (or
                Control-click) Nab in Applications and choose{" "}
                <span className="font-mono text-yellow">Open</span>, then confirm
                in the dialog.
              </Li>
              <Li>
                If macOS still blocks it, open{" "}
                <span className="font-mono">System Settings → Privacy &amp;
                Security</span>{" "}
                and click <span className="font-mono text-yellow">Open Anyway</span>.
              </Li>
            </ul>
            <P>
              You only do this once. After that a scissors icon ✂ lives in your
              menubar (no dock icon) and the onboarding window walks you through
              the rest.
            </P>
          </Step>

          <Step n={2} title="Grant permissions">
            <P>
              macOS asks for two permissions. Both live in System Settings →
              Privacy &amp; Security:
            </P>
            <ul className="space-y-2">
              <Li>
                <span className="font-mono text-aqua">Screen Recording</span>:
                required to capture a region.
              </Li>
              <Li>
                <span className="font-mono text-yellow">Accessibility</span>:
                required for the global double-⌘ / double-⌃ gestures and reading
                your text selection.
              </Li>
            </ul>
            <P>
              Capture from the menubar works without Accessibility, you only need
              it for the keyboard gestures.
            </P>
          </Step>

          <Step n={3} title="Pick where links live">
            <P>
              By default, Nab hosts your links, nothing to set up. Prefer
              full control over where your captures live and how long links
              last? Connect your own bucket instead.
            </P>

            <h3 className="pt-2 font-mono text-lg font-semibold text-fg0">
              Nab-hosted <span className="font-normal text-gray">(default)</span>
            </h3>
            <P>
              Capture and share right away, no account, no bucket, nothing to
              configure. Hosted links expire after 30 days.
            </P>

            <h3 className="pt-4 font-mono text-lg font-semibold text-fg0">
              Self-host <span className="font-normal text-gray">(optional)</span>
            </h3>
            <P>
              Point Nab at any S3-compatible bucket in Settings → Storage.
              Links to your own bucket last as long as the object does.
              Cloudflare R2 is the recommended path (zero egress, generous
              free tier), or try a local MinIO bucket with no account at all.
            </P>

            <h4 className="pt-2 font-mono text-base font-semibold text-fg1">
              Option A: Cloudflare R2
            </h4>
            <P>
              Create a bucket, then an R2 API token scoped to it (Object Read &amp;
              Write). In Settings → Storage, choose <strong>R2</strong> and fill
              in:
            </P>
            <Terminal title="Settings → Storage">
              {`Endpoint        https://<ACCOUNT_ID>.r2.cloudflarestorage.com
Bucket          shots
Region          auto
Access Key ID   <token access key>
Secret Key      <token secret>
Public base     https://<your-r2-public-domain>   (optional)
Path-style      ON`}
            </Terminal>
            <P>
              Enable the bucket&apos;s r2.dev public URL or a custom domain so the
              shared links resolve, and set that as the Public base.
            </P>

            <h4 className="pt-4 font-mono text-base font-semibold text-fg1">
              Option B: Local MinIO (no account)
            </h4>
            <Terminal title="terminal">
              {`brew install minio/stable/minio minio/stable/mc

# start a local S3 server
MINIO_ROOT_USER=nab MINIO_ROOT_PASSWORD=nab12345 \\
  minio server ~/.nab-minio --address :9000 --console-address :9001

# create a public-read bucket
mc alias set nabdev http://localhost:9000 nab nab12345
mc mb nabdev/shots
mc anonymous set download nabdev/shots`}
            </Terminal>
            <P>
              Then in Settings → Storage click{" "}
              <span className="font-mono text-orange">
                Load local dev config (MinIO)
              </span>
              . The status dot turns green when you&apos;re ready.
            </P>
          </Step>

          <Step n={4} title="Capture & share">
            <ul className="space-y-3">
              <Li>
                <span className="rounded bg-bg2 px-2 py-1 font-mono text-xs text-fg0">
                  tap ⌘ twice
                </span>
                : capture a region → link copied to your clipboard.
              </Li>
              <Li>
                <span className="rounded bg-bg2 px-2 py-1 font-mono text-xs text-fg0">
                  tap ⌃ twice
                </span>
                : share the current text selection → link copied.
              </Li>
              <Li>
                <span className="font-mono text-xs text-fg0">menubar ✂</span>:
                same actions plus Settings, anytime.
              </Li>
            </ul>
            <P>
              The link previews inline the moment you paste it into Discord or
              Slack, no extra steps.
            </P>
            <P>
              Tune the gesture timing, toast position, naming, and more in
              Settings. Every upload is logged locally under History, re-copy,
              open, or delete.
            </P>
          </Step>

          <Step n={5} title="Troubleshooting">
            <ul className="space-y-2">
              <Li>
                <strong className="text-fg1">Gesture does nothing</strong>, grant
                Accessibility, then toggle the shortcut off/on. The app re-arms the
                tap within a couple seconds of being trusted.
              </Li>
              <Li>
                <strong className="text-fg1">Link returns 403</strong>, only
                relevant when self-hosting: the bucket object isn&apos;t public.
                Enable public read (R2 public domain, or{" "}
                <span className="font-mono text-xs">mc anonymous set download</span>
                ).
              </Li>
              <Li>
                <strong className="text-fg1">Upload failed toast</strong>, if
                self-hosting, check the endpoint, credentials, and that the
                bucket exists.
              </Li>
            </ul>
          </Step>
        </div>
      </main>

      {/* Footer, full-bleed TUI modeline, matching the home page */}
      <footer className="border-t border-bg2 bg-bg0-hard">
        <div className="mx-auto flex max-w-4xl flex-wrap items-center gap-x-4 gap-y-1 px-6 py-3 font-mono text-xs">
          <span className="rounded bg-orange px-2 py-0.5 font-semibold text-bg0-hard">
            NORMAL
          </span>
          <span className="text-fg1">nab 0.2.2</span>
          <span className="text-gray">setup guide</span>
          <a href="/" className="ml-auto cursor-pointer text-gray hover:text-fg0">
            ~/home
          </a>
        </div>
      </footer>
    </div>
  );
}
