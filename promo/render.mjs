// node render.mjs [fps] [out.mp4] [onlyFrame-seconds,...]
import { createRequire } from 'module';
import { spawn } from 'child_process';
const require = createRequire('/opt/homebrew/lib/node_modules/@playwright/cli/');
const { chromium } = require('playwright-core');
const fps = +(process.argv[2] || 60), out = process.argv[3] || 'yap.mp4', stills = process.argv[4], from = +(process.env.FROM || 0) * fps;
const browser = await chromium.launch({ executablePath: process.env.HOME + '/Library/Caches/ms-playwright/chromium_headless_shell-1243/chrome-headless-shell-mac-arm64/chrome-headless-shell' });
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
await page.goto('file://' + new URL('index.html', import.meta.url).pathname);
await page.waitForLoadState('networkidle');
const total = 15 * fps;
if (stills) {
  const want = new Set(stills.split(',').map(s => Math.round(+s * fps)));
  for (let f = 0; f <= Math.max(...want); f++) {
    await page.evaluate(([t, f]) => render(t, f), [f / fps, f]);
    if (want.has(f)) await page.screenshot({ path: `${process.env.TMPDIR}/still-${(f / fps).toFixed(2)}.png` });
  }
} else {
  const ff = spawn('ffmpeg', ['-y', '-f', 'image2pipe', '-framerate', String(fps), '-i', '-', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', '-preset', 'slow', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });
  for (let f = 0; f < from; f++) await page.evaluate(([t, f]) => render(t, f), [f / fps, f]);
  for (let f = from; f < total; f++) {
    await page.evaluate(([t, f]) => render(t, f), [f / fps, f]);
    const buf = await page.screenshot({ type: 'png' });
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
  }
  ff.stdin.end(); await new Promise(r => ff.on('close', r));
}
await browser.close();
