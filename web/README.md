# Snip — Website

Marketing landing + download redirect + license-verify endpoint. Next.js 15
(App Router) + Tailwind v4. Deploy target: Vercel.

## Develop

```bash
cd web
npm install
npm run dev      # http://localhost:3000
npm run build    # production build
```

## Routes

- `/` — landing page (static)
- `GET /api/download` — 302 → latest macOS asset from GitHub Releases
- `POST /api/license/verify` — `{ "key": "QS-XXXX-XXXX-XXXX" }` → `{ valid, plan }`

## Environment

| Var | Purpose |
|---|---|
| `GITHUB_REPO` | `owner/repo` for download redirect (e.g. `you/snip`) |

Set in Vercel: Project → Settings → Environment Variables.

## Deploy

Vercel auto-detects Next.js. Either connect the repo in the Vercel dashboard
(root directory = `web`), or from this folder:

```bash
npx vercel        # preview
npx vercel --prod # production
```

## Notes

- License endpoint is a v0 stub (validates key shape only). Swap `lookup()` in
  `app/api/license/verify/route.ts` for a real KV/D1/DB store. Fail-open is the
  client's responsibility.
