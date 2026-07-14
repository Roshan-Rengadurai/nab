# Nab

Take a screenshot, get a clean link on your clipboard. The twist, and the whole reason Nab exists: the file lands in a storage bucket *you* (can) own, or maybe our own server if you trust us with your data.

Nab is a small macOS menubar app. You press a shortcut, drag a region, and a shareable URL is sitting on your clipboard before you've finished letting go of the mouse. The bytes go straight to your bucket over a presigned upload. Cloudflare R2, AWS S3, Backblaze B2, MinIO, anything that speaks the S3 API works. No account on our end, nothing proxying your files, no monthly storage bill from us.

It does text too. Highlight some code or a paragraph anywhere, tap Control twice, and Nab turns the selection into a tidy little window image (syntax-highlighted when it looks like code, plain and readable when it doesn't) and uploads that instead of raw text.

The look is gruvbox throughout (specifically inspired by VS Code's Gruvbox Dark Hard theme), because that's the theme I use and I love it (Catpucchin comes at a close second)

## What you get

- Region capture by tapping Command twice, or from the menubar.
- Hold Option while you tap Command twice to save the capture to a folder of your choosing (Settings, Capture) instead of uploading it. The file lands on your clipboard too, so Command-V pastes the image itself.
- Text-selection sharing by tapping Control twice. Code gets real syntax highlighting; prose gets clean wrapping. Either way it comes out as a framed window image.
- Upload straight to your own S3-compatible bucket using a hand-rolled SigV4 signer (no heavyweight AWS SDK).
- The link is on your clipboard the instant the object key is decided, so for normal screenshots you can paste before the upload even finishes.
- A settings window with storage setup, capture format, link naming, gesture timing, and toast placement.
- Themed toasts that confirm a copy (or tell you what went wrong), pinned to a corner or following your cursor, your call.
- A local history of everything you've shared, with re-copy, open, and delete. It lives in a plain file on your Mac. We never see it.
- Credentials kept in the macOS Keychain, not in plaintext anywhere.
- A first-run onboarding that walks you through permissions and connecting a bucket.

## Repository layout

```
Sources/NabCore/   Pure, testable core: SigV4, key generation, the upload pipeline, S3 provider
Sources/Nab/        The macOS app: menubar, settings UI, gestures, toasts, snippet rendering
Tests/NabCoreTests/ Unit tests for the core (no app lifecycle needed)
web/                 The marketing site and docs (Next.js + Tailwind)
docs/                Internal planning notes
Package.swift        Swift package manifest
```

The split is deliberate. Anything that can be a plain function lives in `NabCore` and has tests. The app target is the part that has to talk to macOS, and you verify that by running it.

## Getting started

### The app

You need macOS 13 or newer and a Swift 5.9 toolchain (the one bundled with current Xcode is fine).

```bash
swift run Nab
```

A scissors icon appears in your menubar. On a fresh machine the onboarding window opens first and points you at the two permissions and the storage setup. If you ever want to see it again, it's in the menubar menu.

### Trying it without a cloud account

You do not need to sign up for anything to kick the tires. Run a local MinIO bucket, which is just an S3 server on your own machine:

```bash
brew install minio/stable/minio minio/stable/mc

MINIO_ROOT_USER=nab MINIO_ROOT_PASSWORD=nab12345 \
  minio server ~/.nab-minio --address :9000 --console-address :9001

mc alias set nabdev http://localhost:9000 nab nab12345
mc mb nabdev/shots
mc anonymous set download nabdev/shots
```

Then open Settings, go to Storage, and click "Load local dev config." The status dot turns green and you're ready to capture. (Those credentials are throwaway and only ever touch localhost. Please don't reuse them for a real bucket.)

For a real bucket, Cloudflare R2 is the gentlest place to start. The full walkthrough, including R2, lives in the docs site under `/docs`.

### The website

```bash
cd web
npm ci
npm run dev
```

It's a Next.js app. The landing page and the setup guide both live there.

## Permissions

macOS will ask for two things:

- **Screen Recording** lets Nab capture a region. 
- **Accessibility** powers the global double-tap gestures and reading your current text selection. Capture from the menubar still works without it; you just lose the keyboard shortcuts and text sharing.

Nab asks only when you turn on a feature that needs it, and it degrades quietly if you say no.

## How it works

The path is short on purpose. Nab reads the bytes, picks a random unguessable object key, and computes the final public URL right then. Because it controls the key, it knows the link before uploading a single byte, so the clipboard write can happen first. It signs a short-lived PUT URL locally with your Keychain credentials, sends the bytes straight to your bucket, and records the result in local history. For a 300 KB screenshot on a decent connection, the whole thing feels instant.

**Patches are very welcome!**



## Contributing

There's a whole guide in [CONTRIBUTING.md](CONTRIBUTING.md). TL;DR: be kind, keep the core tests green, and match the style of the code around you.

## License

MIT. See [LICENSE.md](LICENSE.md). Go bananas!!!
