# Contributing to Snip

First off: thank you for even reading this.

## The one real rule

Be kind. To other contributors, to people opening issues, to your past self who wrote the code you're now refactoring.

## Getting set up

Everything you need to build and run is in the [README](README.md). The fastest loop for hacking on the app:

```bash
swift run Snip      # build and launch
swift test          # run the core test suite
```

For the website:

```bash
cd web && npm ci && npm run dev
```

If you want a working bucket without signing up for anything, the README's local MinIO section gets you there in about a minute.

## How the code is laid out

Two halves, and the line between them matters.

`SnipCore` is the pure part. Signing, key generation, content types, the upload pipeline, the S3 provider. If a thing can be a function that takes inputs and returns outputs, it belongs here, and it should have a test. This is where most logic changes should land.

`Sources/Snip` is the macOS app. The menubar, the settings window, the gesture monitor, the toast panel, the snippet image renderer. This part talks to the operating system, so you verify it by running the app and watching it work, not with unit tests.

When you're adding something, ask which half it belongs in. Pushing logic down into `SnipCore` (where it's testable) is almost always the right move.

## Tests

The core has tests, and they're fast. Please keep them green:

```bash
swift test
```

If you're adding behavior to `SnipCore`, write the test alongside it. You don't have to be dogmatic about test-first, but a change to the signer or the pipeline that ships without a test is going to get asked about.

The app layer doesn't have automated tests, and that's expected. If you change capture, gestures, or the settings UI, run the app and confirm it does the thing. A short note in your pull request about what you checked goes a long way.

## Style

Match the code around you. The Swift here leans on small structs, explicit initializers, and plain `is`/`has` over clever indirection. The web side is standard Next.js with Tailwind and the gruvbox tokens defined in `globals.css`. There's no separate formatter config to fight with; just read the neighbors and blend in.

A few specifics that come up:

- Colors come from the gruvbox palette already defined (`Gruv` in Swift, the `--color-*` tokens in CSS). Reach for those rather than fresh hex values.
- The snippet classifier and syntax highlighter in `SnippetImage.swift` are heuristics. They will be wrong sometimes. Improving them (more languages, better detection) is a great place to start, and you can verify your work headlessly with `swift run Snip render-snippet <in.txt> <out.png>`.
- Keep credentials out of the repo. The MinIO dev credentials are intentionally weak and local-only; never wire real keys into code or tests.

## Sending a change

1. Branch off `main`.
2. Make the change. Keep it focused. One idea per pull request is easier to review and easier to revert if it goes sideways.
3. Run `swift test` (and the app, if you touched it).
4. Open a pull request and say what you changed and why. If it's visual, a screenshot is worth a thousand words of description.

Small, well-described changes get merged faster (mostly because they're more of a pleasure to review)

## Good places to start

If you want to help but don't have a specific itch:

- Teach the syntax highlighter another language, or improve the code-vs-prose detection.
- Add remote-object deletion to the history view (the local record already deletes; the bucket object doesn't yet).
- Move history from its JSON file to SQLite without changing the public behavior.
- Improve the onboarding copy or the docs site.

## Questions

Open an issue. "How does X work" and "is this the right place for Y" are perfectly good issues. Asking early saves everyone time, and it's never an imposition.

Happy programming \(ᵔᵕᵔ)/
