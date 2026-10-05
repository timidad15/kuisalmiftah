# Al-Miftah Kuis Nahwu — versi PWA + Android (Play Store)

Repo ini adalah **versi baru** yang siap dipasang di GitHub, Neon, dan Cloudflare yang baru, lalu dibungkus menjadi aplikasi Android (Trusted Web Activity) untuk Google Play.

```
Murid (Chrome / aplikasi Android TWA) ──► Cloudflare Pages ──► Neon PostgreSQL
                                          • public/ (halaman + PWA)   • dibuat dari schema.sql
                                          • functions/api/[[path]].js
                                                ▲
                                             GitHub (push = deploy otomatis)
```

## Yang baru dibanding versi lama

| Perubahan | Alasan |
|---|---|
| PWA: `manifest.webmanifest`, `sw.js`, ikon 192/512/maskable, `offline.html` | Syarat dibungkus jadi aplikasi Android |
| `.well-known/assetlinks.json` | Menghubungkan situs dengan aplikasi Android (layar penuh tanpa bar alamat) |
| **Hapus akun sendiri** (`POST /api/account/delete`, tombol di Profil → Bantuan dan akun) + `hapus-akun.html` | Wajib dari Google Play |
| **Laporkan pemain** (`POST /api/player/report`) + tab Laporan admin menampilkan laporan pemain | Kebijakan konten buatan pengguna (username dan foto publik) |
| `privasi.html` (kebijakan privasi) | Wajib dari Google Play |
| `schema.sql` baru, **sinkron dengan kode** (pencapaian, Cepat Tepat, foto, lencana, gold_grants, dst.) | Skema lama tertinggal dari kode |
| Pustaka Excel dihosting sendiri di `/vendor/`; cdnjs dihapus dari CSP | Tidak ada lagi skrip pihak ketiga tanpa SRI |

Satu-satunya rute yang tidak ada di versi lama: `account/delete`, `player/report`, `admin/player-reports`, `admin/player-report-resolve`. Sisanya sama persis.

## 1. Isi repositori

```
repo/
├─ public/                 ← Build output directory
│  ├─ index.html, logo.png, favicon.png, apple-touch-icon.png
│  ├─ icon-192.png, icon-512.png, icon-maskable-512.png
│  ├─ manifest.webmanifest, sw.js, offline.html
│  ├─ privasi.html, hapus-akun.html
│  ├─ _headers
│  ├─ .well-known/assetlinks.json
│  ├─ rank/ (bronze … legend .webp)
│  └─ vendor/xlsx.full.min.js
├─ functions/api/[[path]].js   ← API (kurung siku persis begini)
├─ store-assets/           ← ikon 512 dan feature graphic untuk Play Console
├─ design/ikon-rank.png    ← lembar referensi ikon rank (tidak disajikan ke publik)
├─ schema.sql, package.json, .gitignore
├─ README.md, PLAYSTORE.md
```

## 2. Akun baru

1. **GitHub** (akun baru): https://github.com
2. **Neon** (proyek baru): https://neon.com
3. **Cloudflare** (boleh akun yang sama dengan yang lama, buat proyek Pages baru): https://dash.cloudflare.com

## 3. Neon

1. **Create project**, nama `al-miftah-app`, region **Asia Pacific (Singapore)**.
2. **SQL Editor** → tempel **seluruh isi `schema.sql`** → **Run**. Aman diulang.
3. **Connect** → nyalakan **Connection pooling** (alamat berisi `-pooler`) → salin connection string. Ini nilai `DATABASE_URL`. Jangan taruh di GitHub.

## 4. GitHub

Pakai terminal supaya nama `[[path]].js` dan folder `.well-known` ikut utuh (unggah lewat web sering gagal untuk dua hal ini):

```bash
cd almiftah-app
git init
git add .
git commit -m "Instalasi awal versi PWA + Android"
git branch -M main
git remote add origin https://github.com/USERNAME/NAMA_REPO.git
git push -u origin main
```

Buat repo dulu di GitHub (**New repository**, pilih **Private**, jangan centang README).

## 5. Cloudflare Pages

**Workers & Pages → Create application → Pages → Connect to Git** → pilih repo.

| Kolom | Isi |
|---|---|
| Production branch | `main` |
| Framework preset | None |
| Build command | `npm install` |
| Build output directory | `public` |
| Root directory | *(kosong)* |

Environment variables (tipe **Secret**):

| Nama | Isi |
|---|---|
| `DATABASE_URL` | connection string Neon (baru) |
| `JWT_SECRET` | acak panjang baru: `openssl rand -base64 48` |

**Pakai `JWT_SECRET` yang baru**, jangan menyalin dari proyek lama. Setelah mengubah variabel, deploy ulang (Retry deployment).

### Domain sendiri (wajib untuk Android)
Aplikasi Android terikat ke satu alamat tetap. Pasang domain di **Custom domains**, jangan memakai `*.pages.dev`. Semua contoh di bawah memakai `https://DOMAINMU`.

## 6. Isi placeholder (wajib sebelum rilis)

```bash
grep -rn "GANTI_" public
```

| Placeholder | Di mana | Isi |
|---|---|---|
| `GANTI_EMAIL_KONTAK` | `privasi.html`, `hapus-akun.html` | email yang kamu baca |
| `GANTI_TANGGAL` | `privasi.html` | tanggal terbit |
| `GANTI_PACKAGE_ID`, `GANTI_SHA256_FINGERPRINT` | `.well-known/assetlinks.json` | diisi pada bagian 8 |

## 7. Setelah deploy

1. Buka situs → daftar akun admin.
2. Jadikan admin di Neon SQL Editor:
   ```sql
   update users set role = 'admin' where lower(username) = lower('NAMA_ADMIN');
   ```
3. **Pindahkan soal dari aplikasi lama:** di panel admin lama klik **Unduh semua soal** (Excel), lalu di panel admin baru **Unggah** file itu. Formatnya sama.
4. Coba satu kuis, 🚩 Lapor soal, 🚩 Laporkan pemain (lewat leaderboard → klik pemain), dan **Hapus akun** pakai akun uji (bukan admin).
5. Buka `https://DOMAINMU/privasi.html`, `/hapus-akun.html`, dan `/.well-known/assetlinks.json` untuk memastikan ketiganya terbuka.

> **Data murid lama tidak ikut pindah** karena Neon-nya baru. Murid mendaftar ulang (mereka mendapat Gold awal lagi). Kalau ingin memindahkan akun, XP, dan pembelian, itu bisa dilakukan lewat `pg_dump` dari Neon lama, tapi skema lama berbeda dari skema baru, jadi perlu skrip migrasi khusus.

## 8. Membuat aplikasi Android (TWA)

**Cek PWA dulu:** buka situs di Chrome → DevTools → **Application → Manifest**. Ikon harus tampil tanpa peringatan, dan **Service Workers** harus berstatus *activated*.

### Cara termudah: PWABuilder (tanpa Android Studio)
1. Buka https://www.pwabuilder.com, masukkan `https://DOMAINMU`.
2. **Package for stores → Android**. Isi:
   - Package ID: huruf kecil, mis. `id.almiftah.kuis` (tidak bisa diubah setelah terbit)
   - App name: `Al-Miftah Kuis Nahwu`, Launcher name: `Al-Miftah`
   - **Signing key: Create new**, lalu **simpan file `.keystore` dan passwordnya di tempat aman** (jangan di GitHub)
3. Unduh paket. Di dalamnya ada file **`.aab`** (untuk Play Store) dan **`assetlinks.json`** contoh.

### Alternatif: Bubblewrap (terminal)
```bash
npm i -g @bubblewrap/cli
bubblewrap init --manifest=https://DOMAINMU/manifest.webmanifest
bubblewrap build
```

### Hubungkan aplikasi dengan situs (assetlinks)
1. Daftarkan aplikasi di Play Console dan unggah `.aab` ke closed testing (lihat `PLAYSTORE.md`).
2. Di Play Console → **Setup → App signing**, salin **SHA-256 certificate fingerprint** milik *App signing key* Google.
3. Isi `public/.well-known/assetlinks.json` dengan package ID dan fingerprint itu (boleh dua fingerprint: *app signing key* dan *upload key*), lalu `git push`.
4. Bila alamat bar masih tampil di dalam aplikasi, artinya assetlinks belum cocok. Periksa package ID dan fingerprint, lalu pastikan `https://DOMAINMU/.well-known/assetlinks.json` terbuka tanpa pengalihan.

## 9. Memperbarui aplikasi

* Perubahan situs/API: `git push`, otomatis sampai ke aplikasi Android (tanpa rilis ulang Play Store).
* Rilis ulang `.aab` hanya perlu bila mengubah ikon, nama, package, atau saat Google menaikkan target API (naikkan `appVersionCode`).
* Bila daftar `PRECACHE` di `sw.js` berubah, naikkan `VERSI` di dalamnya.
* Pengaturan yang bisa diubah di `functions/api/[[path]].js`: `GOLD_RATE`, `STARTER_GOLD`, `RANK_PAY`, `PASS_PCT`, `DAILY_N`/`DAILY_PASS`, `RARE`/`PITY`, `LOGIN_MAX`/`LOGIN_MIN`, `REPORT_DAY`, harga `SHOP`/`NSHOP`.

## 10. Pemecahan masalah

| Gejala | Penyebab umum | Solusi |
|---|---|---|
| Daftar/masuk gagal, error server | `DATABASE_URL`/`JWT_SECRET` belum diisi | Isi, lalu deploy ulang |
| `/api/...` 404 | Berkas API salah nama/folder | Harus `functions/api/[[path]].js` di akar repo |
| `relation ... does not exist` | `schema.sql` belum dijalankan | Jalankan di Neon SQL Editor |
| Aplikasi Android menampilkan bar alamat | `assetlinks.json` belum cocok | Lihat bagian 8 langkah 3–4 |
| Perubahan situs tidak muncul di aplikasi | Cache service worker/browser | Tutup aplikasi sepenuhnya lalu buka lagi; periksa `sw.js` tidak ter-cache lama (`_headers` sudah `no-cache`) |
| "Terlalu banyak percobaan gagal" | 8 kali salah dalam 15 menit | Tunggu, atau `delete from login_attempts where key = 'u:namauser';` |
| Excel admin gagal dimuat | `vendor/xlsx.full.min.js` tidak ikut terunggah | Pastikan folder `public/vendor/` ada di repo |

## 11. Keamanan

* Jangan menaruh `DATABASE_URL`, `JWT_SECRET`, atau file `.keystore` di GitHub atau tangkapan layar. Kehilangan keystore berarti tidak bisa merilis pembaruan di bawah kunci yang sama (kecuali memakai Play App Signing, yang sangat disarankan).
* Rekomendasi tambahan: di Cloudflare buat **Rate Limiting rule** untuk `/api/login` dan `/api/register`, karena pembatas bawaan hanya per username.
