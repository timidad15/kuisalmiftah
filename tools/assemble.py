import glob, json, os, sys, math
from PIL import Image

AX, AY = 480, 560
Q = int(sys.argv[1]) if len(sys.argv) > 1 else 75
SC = float(sys.argv[2]) if len(sys.argv) > 2 else 0.75      # skala tekstur terhadap hasil render
FPS = int(sys.argv[3]) if len(sys.argv) > 3 else 24          # fps pemutaran (sumber 30 fps)
AQ = int(sys.argv[6]) if len(sys.argv) > 6 else Q
VER = sys.argv[4] if len(sys.argv) > 4 else 'v1'
OUT = sys.argv[5] if len(sys.argv) > 5 else '/home/claude/work/fx'
AW = 2048                                                    # lebar atlas
os.makedirs(OUT, exist_ok=True)
# Profil per efek: (skala tekstur, fps sumber, crossfade 0/1). Crossfade antar-frame hanya aman untuk efek lembut/lambat
# (gelembung, kelopak, galaksi, kembang api): efek benda tegas yang bergerak cepat (koin, es, api, komet, petir) jadi berbayang ganda.
# Tinggi atlas harus < 4096 (batas tekstur banyak HP).
PROFILE = {'bubbles': (0.75, 15, 1), 'petals': (0.75, 15, 1), 'galaxy': (0.75, 15, 1), 'fireworks': (0.75, 15, 1),
           'coins': (0.6, 24, 0), 'comet': (0.6, 24, 0)}
DEFAULT = (SC, 24, 0)
KEYS = ['confetti', 'stars', 'bubbles', 'petals', 'coins', 'fireworks', 'fire', 'ice', 'lightning', 'comet', 'galaxy']
meta, total = {}, 0
for k in KEYS:
    SC, FPS, XF = PROFILE.get(k, DEFAULT)
    _all = sorted(glob.glob(f'/home/claude/fxbake/frames/{k}_*.png'))
    fs = [_all[min(len(_all)-1, round(i*30/FPS))] for i in range(math.ceil(len(_all)*FPS/30))]
    crops = []   # (img, dx, dy) dx,dy = pojok kiri-atas relatif jangkar, dalam px tekstur
    for f in fs:
        im = Image.open(f).convert('RGBA')
        if SC != 1: im = im.resize((round(im.width * SC), round(im.height * SC)), Image.LANCZOS)
        bb = im.getchannel('A').point(lambda v: 255 if v > 6 else 0).getbbox()
        if not bb: crops.append((None, 0, 0)); continue
        x0, y0, x1, y1 = max(0, bb[0] - 1), max(0, bb[1] - 1), min(im.width, bb[2] + 1), min(im.height, bb[3] + 1)
        crops.append((im.crop((x0, y0, x1, y1)), x0 - round(AX * SC), y0 - round(AY * SC)))
    # shelf packing berurutan
    x = y = rh = 0; pos = []
    for c, dx, dy in crops:
        if c is None: pos.append(None); continue
        w, h = c.size
        if x + w > AW: x, y, rh = 0, y + rh, 0
        pos.append((x, y)); x += w; rh = max(rh, h)
    H = y + rh
    sheet = Image.new('RGBA', (AW, max(H, 1)), (0, 0, 0, 0))
    fr = []
    for (c, dx, dy), p in zip(crops, pos):
        if c is None: fr.append(0); continue
        sheet.paste(c, p); fr.append([p[0], p[1], c.width, c.height, dx, dy])
    name = f'{k}.{VER}.webp'
    sheet.save(f'{OUT}/{name}', 'WEBP', quality=Q, alpha_quality=AQ, method=int(os.environ.get("WM","4")))
    sz = os.path.getsize(f'{OUT}/{name}'); total += sz
    meta[k] = {'n': name, 'f': fr}
    if SC != DEFAULT[0]: meta[k]['sc'] = SC
    if FPS != DEFAULT[1]: meta[k]['fps'] = FPS
    if XF: meta[k]['x'] = 1   # crossfade antar-frame
    print(f'{k:10s} {len(fr):3d}f atlas {AW}x{H} -> {sz/1024:7.1f} KB')
print('TOTAL', round(total / 1024), 'KB')
json.dump({'fps': DEFAULT[1], 'sc': DEFAULT[0], 'fx': meta}, open('/home/claude/fxbake/meta.json', 'w'), separators=(',', ':'))
