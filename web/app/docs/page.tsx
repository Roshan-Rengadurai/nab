import type { Metadata } from "next";
import Reveal from "../Reveal";

export const metadata: Metadata = {
  title: "Snip — Setup guide",
  description:
    "Install Snip, grant permissions, connect a bucket (Cloudflare R2 or local MinIO), and start sharing.",
};

function Terminal({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="overflow-hidden rounded-xl border border-bg2 bg-bg0-hard">
      <div className="flex items-center gap-2 border-b border-bg1 bg-bg1/70 px-4 py-2.5 font-mono text-xs text-gray">
        <span className="h-3 w-3 rounded-full bg-red" />
        <span className="h-3 w-3 rounded-full bg-yellow" />
        <span className="h-3 w-3 rounded-full bg-green" />
        <span className="ml-3">{title}</span>
      </div>
      <pre className="overflow-x-auto px-5 py-4 font-mono text-[13px] leading-relaxed text-fg1">
        <code>{children}</code>
      </pre>
    </div>
  );
}

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
    <section className="border-t border-bg1 py-12">
      <div className="flex items-center gap-3">
        <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-orange font-mono text-sm font-bold text-bg0-hard">
          {n}
        </span>
        <h2 className="font-mono text-2xl font-bold tracking-tight text-fg0">
          {title}
        </h2>
      </div>
      <div className="mt-5 space-y-4">{children}</div>
    </section>
  );
}

function P({ children }: { children: React.ReactNode }) {
  return <p className="max-w-2xl leading-relaxed text-fg3">{children}</p>;
}

export default function Docs() {
  return (
    <div className="relative min-h-dvh font-sans">
      <header className="sticky top-0 z-40 border-b border-bg1/80 bg-bg0/80 backdrop-blur">
        <nav className="mx-auto flex max-w-4xl items-center justify-between px-5 py-3">
          <a href="/" className="font-mono text-sm font-semibold tracking-tight text-fg0">
            <span className="text-orange">~/</span>snip
            <span className="text-gray">/docs</span>
          </a>
          <div className="flex items-center gap-4 font-mono text-xs sm:text-sm">
            <a href="/" className="cursor-pointer text-fg3 transition-colors hover:text-fg0">
              home
            </a>
            <a
              href="/api/download"
              className="cursor-pointer rounded-md border border-orange/40 bg-orange/10 px-3 py-1 text-orange transition-colors hover:bg-orange/20"
            >
              download
            </a>
          </div>
        </nav>
      </header>

      <main className="bg-grain relative mx-auto max-w-4xl px-5">
        <div className="bg-ambient absolute inset-0 -z-10" />

        <section className="animate-rise pb-8 pt-16">
          <p className="font-mono text-sm text-orange">// setup guide</p>
          <h1 className="mt-2 font-mono text-4xl font-bold tracking-tight text-fg0">
            From zero to one snip.
          </h1>
          <P>
            Snip captures a region or your text selection and drops a clean
            link onto your clipboard — to your own bucket. Here&apos;s the
            90-second setup.
          </P>
        </section>

        <Reveal>
          <Step n={1} title="Install">
            <P>
              Download the latest build and drag Snip to Applications. Launch
              it — a scissors icon appears in your menubar (no dock icon).
            </P>
            <Terminal title="first launch">
              {`# the onboarding window walks you through these steps.
# a scissors icon ✂ lives in your menubar.`}
            </Terminal>
          </Step>
        </Reveal>

        <Reveal>
          <Step n={2} title="Grant permissions">
            <P>
              macOS asks for two permissions. Both live in System Settings →
              Privacy &amp; Security:
            </P>
            <ul className="max-w-2xl space-y-2 text-fg3">
              <li>
                <span className="font-mono text-aqua">Screen Recording</span> —
                required to capture a region.
              </li>
              <li>
                <span className="font-mono text-yellow">Accessibility</span> —
                required for the global double-⌘ / double-⌃ gestures and reading
                your text selection.
              </li>
            </ul>
            <P>
              Capture from the menubar works without Accessibility — you only need
              it for the keyboard gestures.
            </P>
          </Step>
        </Reveal>

        <Reveal>
          <Step n={3} title="Connect storage">
            <P>
              Point Snip at any S3-compatible bucket. Cloudflare R2 is the
              recommended path (zero egress, generous free tier). Want to try it
              with no account? Use a local MinIO bucket.
            </P>

            <h3 className="pt-2 font-mono text-lg font-semibold text-fg0">
              Option A — Cloudflare R2
            </h3>
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

            <h3 className="pt-4 font-mono text-lg font-semibold text-fg0">
              Option B — Local MinIO (no account)
            </h3>
            <Terminal title="terminal">
              {`brew install minio/stable/minio minio/stable/mc

# start a local S3 server
MINIO_ROOT_USER=snip MINIO_ROOT_PASSWORD=snip1234 \\
  minio server ~/.snip-minio --address :9000 --console-address :9001

# create a public-read bucket
mc alias set snipdev http://localhost:9000 snip snip1234
mc mb snipdev/shots
mc anonymous set download snipdev/shots`}
            </Terminal>
            <P>
              Then in Settings → Storage click{" "}
              <span className="font-mono text-orange">
                Load local dev config (MinIO)
              </span>
              . The status dot turns green when you&apos;re ready.
            </P>
          </Step>
        </Reveal>

        <Reveal>
          <Step n={4} title="Capture & share">
            <ul className="max-w-2xl space-y-3 text-fg3">
              <li>
                <span className="rounded bg-bg2 px-2 py-1 font-mono text-xs text-fg0">
                  tap ⌘ twice
                </span>{" "}
                — capture a region → link copied to your clipboard.
              </li>
              <li>
                <span className="rounded bg-bg2 px-2 py-1 font-mono text-xs text-fg0">
                  tap ⌃ twice
                </span>{" "}
                — share the current text selection → link copied.
              </li>
              <li>
                <span className="font-mono text-xs text-fg0">menubar ✂</span> —
                same actions plus Settings, anytime.
              </li>
            </ul>
            <P>
              Tune the gesture timing, toast position, naming, and more in
              Settings. Every upload is logged locally under History — re-copy,
              open, or delete.
            </P>
          </Step>
        </Reveal>

        <Reveal>
          <Step n={5} title="Troubleshooting">
            <ul className="max-w-2xl space-y-2 text-fg3">
              <li>
                <strong className="text-fg1">Gesture does nothing</strong> — grant
                Accessibility, then toggle the shortcut off/on. The app re-arms the
                tap within a couple seconds of being trusted.
              </li>
              <li>
                <strong className="text-fg1">Link returns 403</strong> — the bucket
                object isn&apos;t public. Enable public read (R2 public domain, or{" "}
                <span className="font-mono text-xs">mc anonymous set download</span>
                ).
              </li>
              <li>
                <strong className="text-fg1">Upload failed toast</strong> — check
                the endpoint, credentials, and that the bucket exists.
              </li>
            </ul>
          </Step>
        </Reveal>

        <footer className="border-t border-bg2 bg-bg0-hard">
          <div className="flex flex-wrap items-center gap-x-4 gap-y-1 py-3 font-mono text-xs">
            <span className="rounded bg-orange px-2 py-0.5 font-semibold text-bg0-hard">
              NORMAL
            </span>
            <span className="text-fg1">snip 0.1.0</span>
            <span className="text-gray">setup guide</span>
            <a href="/" className="ml-auto cursor-pointer text-gray hover:text-fg0">
              ~/home
            </a>
          </div>
        </footer>
      </main>
    </div>
  );
}
