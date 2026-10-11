/* Service worker Al-Miftah.
   - Halaman (/): jaringan dulu supaya selalu versi terbaru. Kalau offline, atau jaringan lambat (lebih dari 4 detik) dan sudah ada salinan,
     tampilkan salinan itu agar aplikasi tetap terbuka. Bila belum ada salinan sama sekali, tampilkan /offline.html.
   - Gambar png/webp: tampil dari cache, diperbarui di belakang layar.
   - Font Google: disimpan agar huruf Arab tetap bagus saat offline.
   - /api/* TIDAK PERNAH disimpan di sini (data murid selalu dari server). Paket soal untuk Latihan Offline disimpan oleh aplikasi
     sendiri di localStorage, bukan oleh service worker.
   Naikkan VERSI bila daftar PRECACHE berubah. */
const VERSI = 'v2', CACHE = 'almiftah-' + VERSI, SHELL = '/', LAMBAT = 4000;
const PRECACHE = ['/offline.html', '/icon-192.png', '/logo.png'];
const FONT = ['fonts.googleapis.com', 'fonts.gstatic.com'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(async c => {
    await c.addAll(PRECACHE);
    // salinan awal halaman utama; kalau gagal, pemasangan tetap lanjut (salinan akan tersimpan saat kunjungan berikutnya)
    try { const r = await fetch(SHELL, { cache: 'reload' }); if (r.ok && !r.redirected) await c.put(SHELL, r); } catch (x) {}
  }).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('almiftah-') && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});

async function halaman(e) {
  const r = e.request, c = await caches.open(CACHE), salinan = await c.match(SHELL);
  const net = fetch(r).then(res => {
    if (res.type === 'opaqueredirect') return res;              // biarkan pengalihan berjalan
    if (res.ok && !res.redirected) { c.put(SHELL, res.clone()); return res; } // simpan versi terbaru
    return salinan || res;                                      // server error: pakai salinan bila ada
  });
  e.waitUntil(net.catch(() => {}));                              // biarkan penyimpanan versi terbaru selesai di belakang layar
  if (!salinan) return net.catch(() => caches.match('/offline.html'));
  return Promise.race([net.catch(() => salinan), new Promise(ok => setTimeout(() => ok(salinan), LAMBAT))]);
}

self.addEventListener('fetch', e => {
  const r = e.request, u = new URL(r.url);
  if (r.method !== 'GET') return;
  if (FONT.includes(u.hostname)) { // font: tampilkan cache, perbarui di belakang layar
    e.respondWith(caches.open(CACHE).then(async c => {
      const hit = await c.match(r);
      const net = fetch(r).then(res => { if (res.ok || res.type === 'opaque') c.put(r, res.clone()); return res; }).catch(() => hit);
      return hit || net;
    }));
    return;
  }
  if (u.origin !== location.origin || u.pathname.startsWith('/api/')) return; // biarkan jaringan
  if (r.mode === 'navigate') { e.respondWith(halaman(e)); return; }
  if (/\.(png|webp)$/.test(u.pathname)) { // gambar: tampilkan cache, perbarui di belakang layar
    e.respondWith(caches.open(CACHE).then(async c => {
      const hit = await c.match(r);
      const net = fetch(r).then(res => { if (res.ok) c.put(r, res.clone()); return res; }).catch(() => hit);
      return hit || net;
    }));
  }
});
