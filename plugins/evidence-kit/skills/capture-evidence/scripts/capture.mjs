// Portable Playwright capture lib for web-UI evidence (video + screenshots).
// Headless Playwright against a local OR deployed app. Three auth modes: none, a
// password-login endpoint (loginPath/cookieName), or a saved storageState from
// auth-login.mjs — the latter covers SSO (Auth0, Okta, Entra, ...). See SKILL.md.
//
// Requires `playwright` + `ffmpeg` resolvable. A skill dir has no node_modules, so run
// with the CWD set to a repo that has playwright installed, or `npm i playwright` in
// this skill's scripts dir first. See SKILL.md "Setup".
//
// Usage from a thin flow file:
//   import { capture } from '<skill>/scripts/capture.mjs';
//   await capture({ out: './out', base: 'http://localhost:3000' }, async (page, shot) => {
//     await page.goto('/dashboard'); await shot('dashboard');
//   });
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const VIEWPORTS = {
  '1080p': { width: 1920, height: 1080 },
  '1440':  { width: 1440, height: 900 },
  '720p':  { width: 1280, height: 720 },
  mobile:  { width: 390,  height: 844 },
};

export async function capture(opts, flow) {
  const {
    out = './capture-out',
    base = process.env.CAPTURE_BASE || 'http://localhost:3000',
    viewport = '1440',
    browser: browserName = process.env.CAPTURE_BROWSER || 'chromium',
    slowMo = Number(process.env.CAPTURE_SLOWMO || 0),
    // auth: app-password login -> cookie. Default is NO auth; pass all three for apps
    // with a password endpoint, e.g. { loginPath: '/api/login', cookieName: 'app_auth' }.
    loginPath = null,
    cookieName = null,
    password = process.env.APP_PASSWORD,
    // auth (SSO / any provider): path to a storageState JSON produced by auth-login.mjs.
    // Replays a real logged-in session headlessly. Wins over loginPath when both are set.
    storageState = process.env.CAPTURE_STORAGE_STATE || null,
    // Headless frames have no address bar, so a deployed-env capture can't prove WHERE it
    // ran. `stamp: true` burns `base` into the corner of every frame (pass a string to
    // override the label). Use it for any deployed-env evidence. See the provenance rule.
    stamp = false,
  } = opts;

  const vp = VIEWPORTS[viewport] || VIEWPORTS['1440'];
  const ssDir = path.join(out, 'screenshots');
  const vrawDir = path.join(out, 'video-raw');
  const vidDir = path.join(out, 'video');
  for (const d of [ssDir, vrawDir, vidDir]) fs.mkdirSync(d, { recursive: true });

  const { chromium, firefox, webkit } = await import('playwright');
  const engine = { chromium, firefox, webkit }[browserName] || chromium;

  if (storageState && !fs.existsSync(storageState)) {
    throw new Error(`storageState not found: ${storageState} — run auth-login.mjs first`);
  }

  // app-password login -> cookie (skipped when a storageState session is supplied)
  let cookies = [];
  if (!storageState && loginPath && cookieName && password) {
    const res = await fetch(`${base}${loginPath}`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ password }),
    });
    if (!res.ok) throw new Error(`login failed ${res.status} (check $APP_PASSWORD / base)`);
    const m = new RegExp(`${cookieName}=([^;]+)`).exec(res.headers.get('set-cookie') || '');
    if (!m) throw new Error(`no ${cookieName} cookie in login response`);
    cookies = [{ name: cookieName, value: m[1], domain: new URL(base).hostname, path: '/' }];
  }

  const b = await engine.launch({ headless: true, slowMo });
  const ctx = await b.newContext({
    viewport: vp,
    recordVideo: { dir: vrawDir, size: vp },
    ...(storageState ? { storageState } : {}),
  });
  if (cookies.length) await ctx.addCookies(cookies);

  if (stamp) {
    const label = typeof stamp === 'string' ? stamp : base;
    await ctx.addInitScript((text) => {
      if (window.top !== window.self) return;   // init scripts run in EVERY frame; stamp once
      const add = () => {
        if (!document.body || document.getElementById('__cap_stamp__')) return;
        const d = document.createElement('div');
        d.id = '__cap_stamp__';
        d.textContent = text;
        d.style.cssText = 'position:fixed;bottom:0;left:0;z-index:2147483647;background:#111;' +
          'color:#fff;font:12px/1.7 monospace;padding:2px 10px;pointer-events:none;opacity:.9';
        document.documentElement.appendChild(d);
      };
      if (document.readyState !== 'loading') add();
      document.addEventListener('DOMContentLoaded', add);
    }, label);
  }

  const page = await ctx.newPage();
  page.setDefaultTimeout(15000);   // per-action default; a flow can override via page.setDefaultTimeout()
  // navigate relative to base
  const origGoto = page.goto.bind(page);
  page.goto = (u, o) => origGoto(/^https?:/.test(u) ? u : `${base}${u}`, o);

  let n = 0;
  const shot = async (name) => {
    const p = path.join(ssDir, `${String(++n).padStart(2, '0')}-${name}.png`);
    await page.screenshot({ path: p });
    console.log('SHOT', p);
    return p;
  };

  let err = null;
  try {
    await flow(page, shot, base);
  } catch (e) {
    err = e;
    console.error('FLOW_ERROR', e.message);
    try { await shot('error-state'); } catch {}
  }

  const video = page.video();
  await ctx.close();   // flush the webm
  await b.close();

  try {
    const webm = video ? await video.path() : null;
    if (webm && fs.existsSync(webm)) {
      try { execFileSync('ffmpeg', ['-version'], { stdio: 'ignore' }); }
      catch { throw new Error('ffmpeg not found — install it; the webm is at ' + webm); }
      const mp4 = path.join(vidDir, 'evidence.mp4');
      const vf =
        `scale=${vp.width}:${vp.height}:force_original_aspect_ratio=decrease,` +
        `pad=${vp.width}:${vp.height}:(ow-iw)/2:(oh-ih)/2,format=yuv420p`;
      execFileSync('ffmpeg', [
        '-y', '-loglevel', 'error', '-i', webm,
        '-vf', vf, '-r', '24',
        '-c:v', 'libx264', '-crf', '23', '-movflags', '+faststart', mp4,
      ]);
      console.log('VIDEO', mp4);
      const bytes = fs.statSync(mp4).size;
      if (bytes > 10_000_000) console.warn(`WARN video ${bytes}B > 10MB cap — raise -crf or scale down`);
    } else {
      console.log('NO_VIDEO_FILE');
    }
  } catch (e) {
    console.error('VIDEO_CONV_ERR', e.message);
  }

  if (err) process.exitCode = 2;
}
