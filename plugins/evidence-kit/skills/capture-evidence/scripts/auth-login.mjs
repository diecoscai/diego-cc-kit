#!/usr/bin/env node
// One-time interactive login -> Playwright storageState JSON (provider-agnostic).
//
// Opens a HEADED browser at --base. YOU complete the login by hand — any provider
// (Auth0, Okta, Entra, Google, SAML, a plain form). This script NEVER types credentials.
// Once the logged-in signal appears it saves cookies + localStorage to --out, which
// capture.mjs then replays headlessly via { storageState }, so a normal recorded flow
// works against an authenticated remote environment.
//
// Re-run only when the saved session expires.
//
//   node auth-login.mjs --base https://app.example.com \
//     --out ~/.cache/evidence-auth/app.json --ready-selector 'nav a[href="/projects"]'
//   node auth-login.mjs --base https://app.example.com --out ./auth.json --ready-url '/projects'

import fs from 'node:fs';
import path from 'node:path';

const argv = process.argv.slice(2);
const arg = (k, d = null) => { const i = argv.indexOf(`--${k}`); return i >= 0 ? argv[i + 1] : d; };

const base = arg('base');
const out = arg('out');
const readySelector = arg('ready-selector');
const readyUrl = arg('ready-url');
const timeout = Number(arg('timeout', 300000));
const browserName = arg('browser', 'chromium');

if (!base || !out) {
  console.error('usage: --base <url> --out <file> (--ready-selector <css> | --ready-url <substr>)' +
                ' [--timeout ms] [--browser chromium|firefox|webkit]');
  process.exit(1);
}
// An SSO flow STARTS on the app origin, so "we are on the app origin" proves nothing.
// The caller must name a signal that only exists after login.
if (!readySelector && !readyUrl) {
  console.error('need --ready-selector or --ready-url — a signal that appears ONLY once logged in ' +
                '(e.g. an avatar/nav link, or the post-login route)');
  process.exit(1);
}

const { chromium, firefox, webkit } = await import('playwright');
const engine = { chromium, firefox, webkit }[browserName] || chromium;

const b = await engine.launch({ headless: false });
const ctx = await b.newContext();
const page = await ctx.newPage();
page.setDefaultTimeout(timeout);
// An interactive login redirects through the IdP and back; the default 30s `load` wait
// is the wrong clock here. Settle on first paint and let --timeout govern the journey.
await page.goto(base, { waitUntil: 'domcontentloaded', timeout });

console.log(`\n>>> Complete the login in the browser window. Waiting up to ${Math.round(timeout / 1000)}s...\n`);

try {
  if (readySelector) await page.waitForSelector(readySelector, { timeout });
  else await page.waitForURL((u) => String(u).includes(readyUrl), { timeout });
} catch {
  console.error('TIMEOUT — logged-in signal never appeared. Nothing saved.');
  await b.close();
  process.exit(2);
}

await page.waitForTimeout(1500);   // let post-login cookies/tokens settle before snapshotting
fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
await ctx.storageState({ path: out });   // includes httpOnly cookies
await b.close();
console.log('STORAGE_STATE', out);
