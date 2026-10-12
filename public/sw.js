/* Service worker Al-Miftah: shell aplikasi bisa dibuka tanpa internet.
   - Halaman (/)      : jaringan dulu (maks. 4 detik), lalu salinan terakhir yang tersimpan, lalu /offline.html.
   - Font, gambar, ikon: tersimpan, jadi tampilan offline sama persis dengan online.
   - /api/photo        : foto profil disimpan (URL-nya memuat versi, jadi aman disimpan lama).
   - Data lain di /api/* TIDAK disimpan di sini. Salinan data untuk tampilan offline dikelola index.html sendiri (localStorage).
   Naikkan VERSI bila daftar PRECACHE berubah. */
const VERSI = 'v2', CACHE = 'almiftah-' + VERSI, RUNTIME = 'almiftah-rt-' + VERSI;
const CORE = ['/', '/offline.html']; // wajib ada, kalau gagal instalasi dibatalkan
const EXTRA = ['/logo.png', '/icon-192.png', '/icon-512.png', '/apple-touch-icon.png', '/manifest.webmanifest',
  '/fonts/plus-jakarta-sans-latin-wght-normal.woff2', '/fonts/plus-jakarta-sans-latin-ext-wght-normal.woff2',
  '/fonts/amiri-arabic-400-normal.woff2', '/fonts/amiri-arabic-700-normal.woff2',
  ...['bronze', 'silver', 'gold', 'platinum', 'diamond', 'legend'].map(n => '/rank/' + n + '.webp')]; // gagal satu tidak membatalkan yang lain

self.addEventListener('install', e => {
  e.waitUntil((async () => {
    const c = await caches.open(CACHE);
    await c.addAll(CORE);
    await Promise.allSettled(EXTRA.map(u => c.add(u)));
    await self.skipWaiting();
  })());
});
self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    const ks = await caches.keys();
    await Promise.all(ks.filter(k => k.startsWith('almiftah-') && k !== CACHE && k !== RUNTIME).map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});

const withTimeout = (p, ms) => new Promise((ok, no) => { const t = setTimeout(() => no(new Error('timeout')), ms); p.then(v => { clearTimeout(t); ok(v); }, x => { clearTimeout(t); no(x); }); });

async function pageResponse(e) {
  const c = await caches.open(CACHE);
  try {
    const res = await withTimeout(fetch(e.request), 4000);
    if (res.ok && res.type === 'basic') e.waitUntil(c.put('/', res.clone())); // satu salinan shell untuk semua alamat aplikasi
    return res;
  } catch (x) {
    return (await c.match('/')) || (await c.match('/offline.html')) || new Response('Offline', { status: 503 });
  }
}

// cache dulu, perbarui diam-diam di belakang (untuk gambar dan font)
async function staleWhileRevalidate(e, name) {
  const c = await caches.open(name), hit = await c.match(e.request);
  const net = fetch(e.request).then(res => { if (res.status === 200) c.put(e.request, res.clone()); return res; }).catch(() => null);
  if (hit) { e.waitUntil(net); return hit; }
  return (await net) || new Response('', { status: 404 });
}

// cache dulu, tanpa pembaruan (URL berversi / berkas yang tidak berubah)
async function cacheFirst(e, name) {
  const c = await caches.open(name), hit = await c.match(e.request);
  if (hit) return hit;
  try {
    const res = await fetch(e.request);
    if (res.status === 200) e.waitUntil(c.put(e.request, res.clone()));
    return res;
  } catch (x) { return new Response('', { status: 404 }); }
}

self.addEventListener('fetch', e => {
  const r = e.request, u = new URL(r.url);
  if (r.method !== 'GET' || u.origin !== location.origin) return;
  if (u.pathname === '/api/photo') { e.respondWith(cacheFirst(e, RUNTIME)); return; }
  if (u.pathname.startsWith('/api/')) return; // data murid selalu dari server
  if (r.mode === 'navigate') { e.respondWith(pageResponse(e)); return; }
  if (u.pathname.startsWith('/fonts/')) { e.respondWith(cacheFirst(e, CACHE)); return; }
  if (/\.(png|webp|ico)$/.test(u.pathname) || u.pathname === '/manifest.webmanifest') e.respondWith(staleWhileRevalidate(e, CACHE));
});
