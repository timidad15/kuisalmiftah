/* Service worker sederhana: hanya untuk syarat PWA dan halaman offline.
   /api/* TIDAK PERNAH disimpan (data murid selalu dari server). Naikkan VERSI bila daftar PRECACHE berubah. */
const VERSI = 'v2', CACHE = 'almiftah-' + VERSI, FXC = 'almiftah-fx'; // FXC: sprite efek berversi di nama berkas, jadi tidak pernah perlu dihapus
const PRECACHE = ['/offline.html', '/icon-192.png', '/logo.png'];
const FX_DEFAULT = '/fx/confetti.v1.webp'; // efek bawaan ikut diunduh di awal (gagal pun tidak membatalkan pemasangan)

self.addEventListener('install', e => {
  e.waitUntil(Promise.all([caches.open(CACHE).then(c => c.addAll(PRECACHE)), caches.open(FXC).then(c => c.add(FX_DEFAULT)).catch(() => {})]).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('almiftah-') && k !== CACHE && k !== FXC).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const r = e.request, u = new URL(r.url);
  if (r.method !== 'GET' || u.origin !== location.origin || u.pathname.startsWith('/api/')) return; // biarkan jaringan
  if (r.mode === 'navigate') { // halaman: selalu jaringan dulu; offline -> halaman offline
    e.respondWith(fetch(r).catch(() => caches.match('/offline.html')));
    return;
  }
  if (u.pathname.startsWith('/fx/')) { // sprite efek: cache dulu selamanya (nama berkas memuat versi)
    e.respondWith(caches.open(FXC).then(async c => {
      const hit = await c.match(r); if (hit) return hit;
      const res = await fetch(r); if (res.ok) c.put(r, res.clone()); return res;
    }));
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
