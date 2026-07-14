import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Nab · Terms of Service",
  description: "The terms for using Nab and this website.",
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

export default function Terms() {
  return (
    <div className="relative min-h-dvh font-sans">
      <header className="sticky top-0 z-40 border-b border-bg1/80 bg-bg0/80 backdrop-blur">
        <nav className="mx-auto flex max-w-4xl items-center justify-between px-5 py-3">
          <a href="/" className="font-mono text-sm font-semibold tracking-tight text-fg0">
            <span className="text-orange">~/</span>nab
            <span className="text-gray">/terms</span>
          </a>
          <div className="flex items-center gap-4 font-mono text-xs sm:text-sm">
            <a href="/privacy" className="text-fg3 transition-colors hover:text-fg0">
              privacy
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
          <p className="font-mono text-sm text-orange">// terms of service</p>
          <h1 className="mt-2 font-mono text-4xl font-bold tracking-tight text-fg0">
            Terms of Service
          </h1>
          <p className="mt-3 font-mono text-xs text-gray">Effective {EFFECTIVE}</p>
          <p className="mt-4 max-w-2xl text-sm leading-relaxed text-fg3">
            Please read these terms carefully. They include a disclaimer of
            warranties, a limit on our liability, and an agreement by you to
            indemnify us. By using Nab, you accept all of it.
          </p>
        </section>

        <Section title="1. Agreement to these terms">
          <P>
            These Terms of Service (the &quot;Terms&quot;) are a binding agreement
            between you and the developer of Nab (&quot;Nab,&quot;
            &quot;we,&quot; &quot;us&quot;). By downloading, installing, or using
            the Nab application (the &quot;App&quot;) or this website (the
            &quot;Site&quot;), you agree to these Terms and to the{" "}
            <a href="/privacy" className="text-orange hover:underline">
              Privacy Policy
            </a>
            . If you do not agree, do not use the App or the Site.
          </P>
        </Section>

        <Section title="2. Eligibility">
          <P>
            You must be at least 13 years old, and old enough to form a binding
            contract in your jurisdiction, to use Nab. If you use Nab on behalf
            of an organization, you represent that you are authorized to bind that
            organization to these Terms.
          </P>
        </Section>

        <Section title="3. The software and its license">
          <P>
            Nab&apos;s source code is released under the MIT License, included
            with the source as LICENSE.md. That license governs your rights in the
            source code itself. These Terms govern your use of the App and the Site
            as a service. The App is provided to you free of charge.
          </P>
        </Section>

        <Section title="4. Early software">
          <P>
            Nab is early-stage software and may contain bugs, may change without
            notice, and may fail in ways that interrupt uploads or affect your
            data. You should not rely on it as the sole copy or sole delivery
            mechanism for anything important. We may modify, suspend, or
            discontinue any part of the App or Site at any time without liability.
          </P>
        </Section>

        <Section title="5. Bring your own storage, and your responsibilities">
          <P>
            Nab uploads your content directly from your device to a storage
            bucket that you configure and control. We do not host, store, relay,
            or have access to that content at any time. As a result, you are
            solely responsible for all of the following:
          </P>
          <ul className="max-w-2xl list-disc space-y-2 pl-5 text-fg3">
            <li>
              The content you capture, upload, store, and share, and confirming
              you have the legal right to do so.
            </li>
            <li>
              Your storage provider account, including all costs, billing,
              configuration, access controls, retention, and deletion.
            </li>
            <li>
              Complying with your storage provider&apos;s terms and acceptable use
              policy, and with all laws that apply to your content.
            </li>
            <li>
              Choosing appropriate privacy and access settings on your bucket.
              Nab&apos;s links rely on unguessable object keys, which is
              obscurity, not access control. Anyone with a link can open a
              publicly readable object.
            </li>
            <li>
              Keeping your own backups. Nab is not a backup service.
            </li>
          </ul>
        </Section>

        <Section title="6. Acceptable use">
          <P>
            You agree not to use Nab to create, store, share, or transmit content
            that is unlawful, infringing, defamatory, or harmful, or that violates
            the rights of others, and not to use it to break the law or to violate
            your storage provider&apos;s policies. You also agree not to misuse the
            Site, including by attempting to disrupt it or access it in
            unauthorized ways.
          </P>
        </Section>

        <Section title="7. Abuse, infringement, and illegal content">
          <P>
            We do not host user content. Files created with Nab live in your own
            storage account with your own provider. Because of this, complaints
            about specific content, including copyright (DMCA) and illegal-content
            reports, should be directed to the account holder and to the storage
            provider that actually hosts the file, not to us. We have no ability to
            access, alter, or remove content stored in your bucket. Where we can be
            reached about abuse of the App or Site itself, use the contact below.
          </P>
        </Section>

        <Section title="8. Assumption of risk and data loss">
          <P>
            You use the App and Site at your own risk. We are not responsible for
            any loss of data, failed or partial uploads, corrupted files, broken
            or expired links, unexpected storage charges, or exposure of content
            caused by your bucket configuration. You are responsible for verifying
            that uploads succeeded and that your access settings are correct.
          </P>
        </Section>

        <Section title="9. Disclaimer of warranties">
          <P>
            THE APP AND SITE ARE PROVIDED &quot;AS IS&quot; AND &quot;AS
            AVAILABLE,&quot; WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS,
            IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES
            OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
            NON-INFRINGEMENT, AND ANY WARRANTIES ARISING FROM COURSE OF DEALING OR
            USAGE. WE DO NOT WARRANT THAT THE APP OR SITE WILL BE UNINTERRUPTED,
            SECURE, ERROR FREE, OR THAT ANY UPLOAD WILL SUCCEED OR ANY LINK WILL
            REMAIN AVAILABLE. SOME JURISDICTIONS DO NOT ALLOW THE EXCLUSION OF
            CERTAIN WARRANTIES, SO SOME OF THE ABOVE MAY NOT APPLY TO YOU.
          </P>
        </Section>

        <Section title="10. Limitation of liability">
          <P>
            TO THE MAXIMUM EXTENT PERMITTED BY LAW, IN NO EVENT WILL THE AUTHORS,
            COPYRIGHT HOLDERS, OR CONTRIBUTORS OF NAB BE LIABLE FOR ANY INDIRECT,
            INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES, OR
            FOR ANY LOSS OF DATA, FILES, PROFITS, GOODWILL, OR STORAGE COSTS,
            ARISING OUT OF OR RELATED TO YOUR USE OF, OR INABILITY TO USE, THE APP
            OR SITE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
          </P>
          <P>
            TO THE MAXIMUM EXTENT PERMITTED BY LAW, OUR TOTAL CUMULATIVE LIABILITY
            FOR ALL CLAIMS RELATING TO THE APP OR SITE WILL NOT EXCEED THE GREATER
            OF (A) THE AMOUNT YOU PAID US FOR THE APP IN THE TWELVE MONTHS BEFORE
            THE CLAIM, OR (B) FIFTY US DOLLARS ($50). SOME JURISDICTIONS DO NOT
            ALLOW CERTAIN LIMITATIONS, SO PARTS OF THIS SECTION MAY NOT APPLY TO
            YOU.
          </P>
        </Section>

        <Section title="11. Indemnification">
          <P>
            You agree to defend, indemnify, and hold harmless the authors,
            copyright holders, and contributors of Nab from and against any
            claims, liabilities, damages, losses, and expenses, including
            reasonable legal fees, arising out of or related to: (a) your content;
            (b) your use of the App or Site; (c) your violation of these Terms;
            (d) your violation of any law or the rights of any third party; or
            (e) your storage account and your relationship with your storage
            provider.
          </P>
        </Section>

        <Section title="12. Third-party services">
          <P>
            Nab works with third-party storage providers and other services that
            you choose, such as Cloudflare R2, Amazon S3, Backblaze B2, or MinIO.
            We do not control those services and are not responsible for them,
            their availability, their pricing, or their terms. Your use of them is
            governed solely by your agreements with them.
          </P>
        </Section>

        <Section title="13. Termination">
          <P>
            These Terms apply for as long as you use the App or Site. We may
            suspend or stop providing the App or Site, in whole or in part, at any
            time. You may stop using them at any time. The sections that by their
            nature should survive termination, including disclaimers, limitation
            of liability, indemnification, and the general terms below, will
            survive.
          </P>
        </Section>

        <Section title="14. Export and lawful use">
          <P>
            You represent that you are not located in a country subject to an
            embargo that would make your use unlawful, and that you will comply
            with all applicable export-control and sanctions laws in your use of
            the App and Site.
          </P>
        </Section>

        <Section title="15. Changes to these terms">
          <P>
            We may revise these Terms from time to time. When we do, we will update
            the effective date above. Material changes will be posted here before
            they take effect. Your continued use after changes take effect means
            you accept the revised Terms.
          </P>
        </Section>

        <Section title="16. Governing law and disputes">
          <P>
            These Terms are governed by the laws of{" "}
            <span className="text-fg1">[your jurisdiction]</span>, without regard
            to its conflict-of-laws rules. You agree that any dispute will be
            resolved exclusively in the courts located in{" "}
            <span className="text-fg1">[your venue]</span>, and you consent to
            their jurisdiction. Replace both bracketed fields with your actual
            jurisdiction and venue before publishing.
          </P>
        </Section>

        <Section title="17. General">
          <P>
            If any provision of these Terms is found unenforceable, the rest
            remains in effect, and the unenforceable provision will be limited or
            removed to the minimum extent necessary. Our failure to enforce a
            provision is not a waiver of it. You may not assign these Terms without
            our consent; we may assign them in connection with a transfer of the
            project. These Terms, together with the Privacy Policy and the MIT
            License, are the entire agreement between you and us regarding the App
            and Site.
          </P>
        </Section>

        <Section title="18. Contact">
          <P>
            Questions about these Terms? Email{" "}
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
            <a href="/privacy" className="text-gray hover:text-fg0">
              privacy
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
