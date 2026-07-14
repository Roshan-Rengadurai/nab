import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Nab · Privacy Policy",
  description:
    "How Nab handles your data. The short version: the app is built so we never see your files.",
};

const EFFECTIVE = "June 28, 2026";

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="border-t border-bg1 py-10">
      <h2 className="font-mono text-2xl font-bold tracking-tight text-fg0">
        {title}
      </h2>
      <div className="mt-4 space-y-4">{children}</div>
    </section>
  );
}

function P({ children }: { children: React.ReactNode }) {
  return <p className="max-w-2xl leading-relaxed text-fg3">{children}</p>;
}

export default function Privacy() {
  return (
    <div className="relative min-h-dvh font-sans">
      <header className="sticky top-0 z-40 border-b border-bg1/80 bg-bg0/80 backdrop-blur">
        <nav className="mx-auto flex max-w-4xl items-center justify-between px-5 py-3">
          <a href="/" className="font-mono text-sm font-semibold tracking-tight text-fg0">
            <span className="text-orange">~/</span>nab
            <span className="text-gray">/privacy</span>
          </a>
          <div className="flex items-center gap-4 font-mono text-xs sm:text-sm">
            <a href="/terms" className="text-fg3 transition-colors hover:text-fg0">
              terms
            </a>
            <a href="/docs" className="text-fg3 transition-colors hover:text-fg0">
              docs
            </a>
            <a
              href="/api/download"
              className="rounded-md border border-orange/40 bg-orange/10 px-3 py-1 text-orange transition-colors hover:bg-orange/20"
            >
              download
            </a>
          </div>
        </nav>
      </header>

      <main className="relative mx-auto max-w-4xl px-5">
        <div className="bg-ambient absolute inset-0 -z-10" />

        <section className="pb-6 pt-16">
          <p className="font-mono text-sm text-orange">// privacy policy</p>
          <h1 className="mt-2 font-mono text-4xl font-bold tracking-tight text-fg0">
            Privacy Policy
          </h1>
          <p className="mt-3 font-mono text-xs text-gray">Effective {EFFECTIVE}</p>
        </section>

        <Section title="The short version">
          <P>
            Nab is designed so that we cannot see your files. When you capture or
            share something, it uploads directly from your Mac to a storage bucket
            you control. The bytes never pass through us, because there is nothing
            of ours for them to pass through. This is the whole idea behind the
            app, and it is the foundation of this policy.
          </P>
        </Section>

        <Section title="What the app handles">
          <P>
            The Nab macOS app runs on your machine and keeps your data there:
          </P>
          <ul className="max-w-2xl list-disc space-y-2 pl-5 text-fg3">
            <li>
              Your screenshots, files, and shared text upload straight to your own
              S3-compatible bucket using a temporary signed URL. We never receive
              them.
            </li>
            <li>
              Your storage credentials live in the macOS Keychain on your device.
              They are not transmitted to us and are not stored in plain text.
            </li>
            <li>
              Your upload history is saved in a local file in your application
              support directory. It stays on your Mac. We have no copy of it.
            </li>
            <li>
              The app does not include analytics, tracking, or telemetry, and it
              does not phone home.
            </li>
          </ul>
        </Section>

        <Section title="What the website handles">
          <P>
            This website is a marketing and documentation site. Like most
            websites, our hosting provider may automatically record standard
            request information such as IP address, browser type, and the pages
            requested, in order to serve the site and keep it secure. We do not use
            this information to build profiles of visitors.
          </P>
          <P>
            Two endpoints are worth calling out. The download link redirects you to
            the latest release and does not require any information from you. The
            license-verification endpoint, if you use it, receives the license key
            you submit so it can confirm whether the key is valid. It does not ask
            for your name, email, or any other identifying detail. We do not
            currently run user accounts, and we do not set advertising or cross-site
            tracking cookies.
          </P>
        </Section>

        <Section title="You control your content">
          <P>
            For anything you capture or upload through Nab, you are the party
            responsible for that content under data-protection law. It is stored in
            your bucket, under your storage account, subject to your provider&apos;s
            terms. We do not act as a host or processor of that content, because we
            never receive or store it. If you need content accessed, exported, or
            deleted, do that directly with your storage provider. We cannot do it
            for you, and we have no copy to act on.
          </P>
        </Section>

        <Section title="What we do not do">
          <P>
            We do not sell your data. We do not share it with advertisers. We do
            not have access to the contents of your bucket, and we cannot retrieve
            or delete files on your behalf, because we never hold them.
          </P>
        </Section>

        <Section title="Third parties">
          <P>
            Your files live with whichever storage provider you choose, such as
            Cloudflare R2, Amazon S3, Backblaze B2, or your own MinIO server. That
            relationship is between you and your provider, and their privacy policy
            and terms govern how they handle your data. This website is served by a
            hosting provider that processes basic request logs as described above.
          </P>
        </Section>

        <Section title="Data security">
          <P>
            Uploads use HTTPS and short-lived signed URLs, and credentials are kept
            in the macOS Keychain. No method of transmission or storage is
            completely secure, however, and we cannot guarantee absolute security.
            You are responsible for your device security and for the access settings
            on your own bucket.
          </P>
        </Section>

        <Section title="International users">
          <P>
            The website may be hosted on servers located in the United States or
            other countries. If you access it from elsewhere, you understand that
            the limited request information described above may be processed in
            those countries.
          </P>
        </Section>

        <Section title="Your rights">
          <P>
            Depending on where you live, you may have rights to access, correct, or
            delete personal data about you. Because we hold essentially no personal
            data about app users, there is usually nothing for us to act on, and
            requests about your stored content should go to your storage provider.
            For any request relating to data this website may process, contact us
            using the address below.
          </P>
        </Section>

        <Section title="Children">
          <P>
            Nab is not directed at children under 13, and we do not knowingly
            collect personal information from them.
          </P>
        </Section>

        <Section title="Changes to this policy">
          <P>
            If this policy changes, we will update the effective date at the top of
            this page. Meaningful changes will be reflected here before they take
            effect.
          </P>
        </Section>

        <Section title="Contact">
          <P>
            Questions about privacy? Email{" "}
            <a
              href="mailto:roshan.rengadurai@gmail.com"
              className="text-orange hover:underline"
            >
              roshan.rengadurai@gmail.com
            </a>
            .
          </P>
        </Section>

        <footer className="border-t border-bg2 bg-bg0-hard">
          <div className="flex flex-wrap items-center gap-x-4 gap-y-1 py-3 font-mono text-xs">
            <span className="rounded bg-orange px-2 py-0.5 font-semibold text-bg0-hard">
              NORMAL
            </span>
            <span className="text-fg1">nab 0.1.0</span>
            <a href="/terms" className="text-gray hover:text-fg0">
              terms
            </a>
            <a href="/" className="ml-auto text-gray hover:text-fg0">
              ~/home
            </a>
          </div>
        </footer>
      </main>
    </div>
  );
}
