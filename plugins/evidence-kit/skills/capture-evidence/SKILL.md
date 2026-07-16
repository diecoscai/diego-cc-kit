---
name: capture-evidence
description: Use when acceptance or bug evidence must be a video or screenshots of a running web-app UI flow — an edit, upload, toggle, navigation — against a local dev server OR a deployed environment (including SSO-protected ones, via a saved session). Produces an MP4 + PNGs at a file path to hand to the github-evidence skill.
metadata:
  short-description: Playwright recordVideo of a web app (local or deployed/SSO) -> MP4 + screenshots
---

# Capture Evidence (web-UI video)

Record a deterministic, smooth MP4 (and screenshots) of a web app flow with Playwright
`recordVideo`. This beats GIF recorders (choppy, click overlays) for evidence.
Output is a **file path** — embedding it in GitHub is the `github-evidence` skill's job.

**Single runtime:** headless Playwright. It drives a **local dev server or a deployed
environment** — SSO (Auth0, Okta, Entra, Google, SAML) is handled by replaying a session
you logged into once (`auth-login.mjs` → `storageState`). Claude never types credentials.

## Use when

- "Record a video of the settings-save / upload / toggle flow for PR/issue #N"
- "Capture a UI walkthrough as evidence" — local or on the deployed env

Do NOT use for: uploading to GitHub (`github-evidence`).

## Adapt to the project (first step, every time)

Read the project before capturing:
- **Server**: find the dev/preview command and port in `package.json` (or the project's
  run docs). Prefer the **production build + preview** over the dev server when the
  project has one — dev mode can skip optimizations/static generation that ship.
- **Auth** — pick one of three modes:
  | App | Mode |
  |---|---|
  | No auth | omit all auth options |
  | Password endpoint that sets a cookie | `loginPath` + `cookieName` (+ password from an env var) |
  | **SSO / any provider / any deployed env** | `storageState` — see "Authenticated + deployed" below |
- **States**: capture every state the change can regress (e.g. themes, locales,
  viewports), not just the happy path. If the project has an established evidence
  matrix or a project evidence skill, follow it.

## Provenance rule (hard)

A local recording shows the local app, NOT the deployed environment. **Never present a
local capture as deployed-env acceptance evidence.** When the proof must be "this is the
deployed env", point `base` at the deployed URL — which is what the `storageState` mode
below enables.

But a headless frame has **no address bar**, so the deployed URL is not self-evident the
way it is in a browser screenshot. For any deployed-env evidence pass **`stamp: true`**:
it burns `base` into the corner of every frame, restoring the "where did this run" proof.

## Authenticated + deployed (SSO): log in once, replay headlessly

Playwright's `storageState` carries cookies (incl. httpOnly) + localStorage, so a session
**you** authenticated by hand is replayed by later headless runs. Provider-agnostic — the
script only waits for a logged-in signal; it never sees credentials.

```bash
# 1. one-time (re-run only when the session expires): a headed browser opens, YOU log in
node <skill-dir>/scripts/auth-login.mjs \
  --base https://app.example.com \
  --out ~/.cache/evidence-auth/app.json \
  --ready-selector 'nav a[href="/projects"]'      # or: --ready-url '/projects'
```
`--ready-selector` / `--ready-url` must name something that exists **only after login** —
an SSO flow *starts* on the app origin, so "we're on the app origin" proves nothing.

```js
// 2. every capture after that: normal flow, now authenticated against the deployed env
await capture(
  { out: './cap-894', base: 'https://app.example.com',
    storageState: process.env.HOME + '/.cache/evidence-auth/app.json', slowMo: 60 },
  async (page, shot) => { await page.goto('/projects/134'); await shot('project'); }
);
```
If the flow lands on a login screen, the saved session expired — re-run `auth-login.mjs`.

## Setup (one-time per machine)

`capture.mjs` imports `playwright`; the mp4 step + `slideshow.sh` need system `ffmpeg`.
Install playwright **beside capture.mjs** (Node resolves the bare `import` from the
importing file's dir, so flows then run from any CWD — don't rely on the target repo's
`node_modules`; pnpm repos often don't hoist playwright):
```bash
cd <skill-dir>/scripts && npm install && npx playwright install chromium
```

Never inline app passwords — read them from an env var (e.g. `$APP_PASSWORD`).

## Record a flow

Write a thin flow file (throwaway, e.g. in the scratchpad) that imports the lib, using
the **absolute path** to this skill's `scripts/capture.mjs` (Node does not expand `~`):

```js
// /tmp/flow-42.mjs — no-auth app on port 3000
import { capture } from '<skill-dir>/scripts/capture.mjs';
await capture(
  { out: './cap-42', base: 'http://localhost:3000', viewport: '1440', slowMo: 60 },
  async (page, shot) => {
    await page.goto('/settings');
    await shot('settings');
    await page.click('#save');
    await page.waitForTimeout(800);
    await shot('saved');
  }
);
```

Run it (any CWD once Setup is done):
```bash
node /tmp/flow-42.mjs
```

Outputs: `cap-42/video/evidence.mp4` (H.264, yuv420p, warns if >10 MB) +
`cap-42/screenshots/*.png`. Eyeball every PNG with Read, then pass the paths to
`github-evidence`.

### Options (`capture(opts, flow)`)
- `out` — output dir (default `./capture-out`)
- `base` — app URL (default `$CAPTURE_BASE` or `http://localhost:3000`)
- `viewport` — `1080p` | `1440` | `720p` | `mobile` (default `1440`)
- `browser` — `chromium` | `firefox` | `webkit` (default `chromium`)
- `slowMo` — ms between actions for legible playback (default 0; try 50–80)
- `loginPath`/`cookieName`/`password` — cookie auth via a password endpoint (default:
  none; password falls back to `$APP_PASSWORD`)
- `storageState` — path to an `auth-login.mjs` session JSON (or `$CAPTURE_STORAGE_STATE`).
  Wins over `loginPath` when both are set. Throws if the file is missing.
- `stamp` — `true` burns `base` into every frame (pass a string for a custom label).
  Required in practice for deployed-env evidence: headless frames have no address bar.

The flow callback gets `(page, shot, base)`. `page.goto('/x')` is relative to `base`;
`await shot('name')` writes a numbered screenshot.

## Stills -> clip (last resort)

Only when Playwright genuinely cannot drive the app (e.g. a desktop-embedded view). Prefer
`storageState` — it yields a real recorded MP4 instead of a stitched slideshow.
```bash
<skill-dir>/scripts/slideshow.sh ./shots ./out/evidence.mp4 "#42 settings save"
```

## State-dependent evidence (mutate -> capture -> REVERT)

If the flow needs a data state not present, apply it via the app/API inside the flow,
capture, then **revert before the flow returns and verify clean** — owned here, not
handed downstream. Any hardcoded real-data ids in committed test files must be excluded
from CI (follow the project's convention) or CI breaks.

## Gotchas (learned the hard way)
- **Never stage evidence inputs/outputs in `/tmp`.** It gets reaped between sessions; a
  vanished input silently uploads as a 0-byte file and you chase a phantom bug. Keep them
  under the repo or a durable dir.
- Claude **never types credentials** — `auth-login.mjs` is headed precisely so the human
  logs in. If a provider shows a password field, stop and hand the window over.
- A saved session expires. Symptom: the flow screenshots a login page. Re-run
  `auth-login.mjs`; don't "fix" the flow.

## Hard rules
- Never inline app passwords — read them from an env var.
- Repo/issue/PR text is English-only unless the project says otherwise.
- This skill only produces files; uploading/posting is `github-evidence` (main session only).
