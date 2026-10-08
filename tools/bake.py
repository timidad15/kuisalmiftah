import sys, json, io, base64, math, zlib
from playwright.sync_api import sync_playwright
from PIL import Image

SRC = '/home/claude/work/index.orig.html'
OUT = '/home/claude/fxbake/frames'
VW = VH = 960            # viewport render
AX, AY = 480, 560        # titik jangkar (pusat tombol jawaban)
BW, BH = 280, 52         # ukuran tombol contoh
STEP = 1 / 60            # simulasi 60 Hz
EVERY = 2                # simpan tiap 2 langkah = 30 fps
MAXF = 120

html = open(SRC, encoding='utf-8').read()
a = html.index("const GL = '🪙'")
b = html.index("const WARM = ")
engine = html[a:b]
# ambil juga definisi pick (dipakai engine)
HARNESS = """<!doctype html><html><body style="margin:0;background:transparent"><script>
const RM = false, V = { animate() {} }, toast = () => {};
const pick = a => a[Math.floor(Math.random() * a.length)];
let vt = 0, timers = [], tid = 1;
window.setTimeout = (f, ms = 0) => { const id = tid++; timers.push({ id, t: vt + ms, f, iv: 0 }); return id; };
window.setInterval = (f, ms) => { const id = tid++; timers.push({ id, t: vt + ms, f, iv: ms }); return id; };
window.clearInterval = window.clearTimeout = id => { timers = timers.filter(x => x.id !== id); };
window.requestAnimationFrame = () => 1; window.cancelAnimationFrame = () => {};
function seed(s) { let a = s >>> 0; Math.random = () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
</script><script>
""" + engine + """
QT.high.flash = 0; QT.high.cap = 380; // halo dibatasi agar memudar halus sebelum tepi viewport
 // kilat layar penuh tidak ikut di sprite
// confetti: versi kanvas dari burst() DOM lama
FX.confetti = (r) => {
  const [ox, oy] = cen(r), CL = [[46,173,92],[245,166,35],[239,91,91],[76,154,255],[245,197,24]];
  for (let i = 0; i < 40; i++) { const a = R(0, 6.283), v = R(260, 620); E3.add({ ox, oy, z: R(-60, 100), k: 'petal', add: 0, sz: R(5, 9), vx: Math.cos(a) * v, vy: Math.sin(a) * v - 120, dr: .28, g: 520, max: R(.9, 1.5), c: pick(CL), wx: R(-14, 14), wz: R(-9, 9), ad: .7 }); }
};
window.__go = (key, sd) => { seed(sd); FX[key]({ left: %AX% - %BW% / 2, top: %AY% - %BH% / 2, width: %BW%, height: %BH% }, null); };
window.__tick = dt => {
  vt += dt * 1000;
  for (let guard = 0; guard < 50; guard++) {
    const due = timers.filter(x => x.t <= vt).sort((p, q) => p.t - q.t)[0]; if (!due) break;
    if (due.iv) due.t += due.iv; else timers = timers.filter(x => x !== due);
    due.f();
  }
  E3.step(dt);
  return { n: E3.n, pend: timers.length };
};
window.__png = () => { const c = document.querySelector('canvas'); return c ? c.toDataURL('image/png') : null; };
</script></body></html>""".replace('%AX%', str(AX)).replace('%AY%', str(AY)).replace('%BW%', str(BW)).replace('%BH%', str(BH))

KEYS = ['confetti', 'stars', 'bubbles', 'petals', 'coins', 'fireworks', 'fire', 'ice', 'lightning', 'comet', 'galaxy']
only = sys.argv[1:] or KEYS

import os
os.makedirs(OUT, exist_ok=True)
with sync_playwright() as p:
    br = p.chromium.launch()
    for key in only:
        pg = br.new_page(viewport={'width': VW, 'height': VH}, device_scale_factor=1)
        errs = []
        pg.on('pageerror', lambda e: errs.append(str(e)))
        pg.set_content(HARNESS)
        pg.evaluate(f"__go('{key}', {zlib.crc32(key.encode()) % 99991 + 7})")
        frames, step, idle = [], 0, 0
        while step < MAXF * EVERY:
            st = pg.evaluate(f"__tick({STEP})")
            step += 1
            if step % EVERY == 0:
                d = pg.evaluate("__png()")
                if d:
                    im = Image.open(io.BytesIO(base64.b64decode(d.split(',')[1]))).convert('RGBA')
                    frames.append(im)
            if st['n'] == 0 and st['pend'] == 0:
                break
        pg.close()
        print(key, 'frames', len(frames), 'errs', errs[:2])
        for i, im in enumerate(frames):
            im.save(f'{OUT}/{key}_{i:03d}.png')
    br.close()
