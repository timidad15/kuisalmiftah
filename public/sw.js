/* Service worker sederhana: hanya untuk syarat PWA dan halaman offline.
   /api/* TIDAK PERNAH disimpan (data murid selalu dari server). Naikkan VERSI bila daftar PRECACHE berubah. */
const VERSI = 'v1', CACHE = 'almiftah-' + VERSI;
const PRECACHE = ['/offline.html', '/icon-192.png', '/logo.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('almiftah-') && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const r = e.request, u = new URL(r.url);
  if (r.method !== 'GET' || u.origin !== location.origin || u.pathname.startsWith('/api/')) return; // biarkan jaringan
  if (r.mode === 'navigate') { // halaman: selalu jaringan dulu; offline -> halaman offline
    e.respondWith(fetch(r).catch(() => caches.match('/offline.html')));
    return;
  }
  if (/\.(png|webp)$/.test(u.pathname)) { // gambar: tampilkan cache, perbarui di belakang layar
    e.respondWith(caches.open(CACHE).then(async c => {
      const hit = await c.match(r);
      const net = fetch(r).then(res => { if (res.ok) c.put(r, res.clone()); return res; }).catch(() => hit);
      return hit || net;
    }));
  }
});
