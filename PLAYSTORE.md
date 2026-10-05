# Paket Google Play — Al-Miftah Kuis Nahwu

Isian di bawah adalah **rancangan**. Baca ulang setiap pertanyaan di Play Console dan jawab sesuai kondisi sebenarnya. Persyaratan Google bisa berubah, jadi cek halaman bantuan Play Console sebelum mengirim.

## 1. Data dasar

| Kolom | Isi |
|---|---|
| Nama aplikasi (maks 30) | Al-Miftah Kuis Nahwu |
| Kategori | Pendidikan |
| Jenis | Aplikasi, Gratis |
| Bahasa utama | Indonesia (id) |
| Email kontak | email yang sama dengan di `privasi.html` |
| URL kebijakan privasi | https://DOMAINMU/privasi.html |
| URL hapus akun (Data safety) | https://DOMAINMU/hapus-akun.html |
| Ikon 512×512 | `store-assets/play-icon-512.png` |
| Feature graphic 1024×500 | `store-assets/play-feature-1024x500.png` |
| Tangkapan layar | Ambil 4–8 dari HP (Beranda, kuis, Toko, leaderboard, rank), minimal 2 |

## 2. Deskripsi singkat (maks 80 karakter, 76 karakter)

Kuis nahwu untuk murid madrasah: 4 jilid, kuis harian, Tathbiq, leaderboard.

## 3. Deskripsi lengkap (maks 4000 karakter)

Al-Miftah Kuis Nahwu membantu murid Madrasah Idadiyah Al-Miftah berlatih nahwu dengan cara yang menyenangkan.

✨ Fitur
• 4 jilid dengan 3 tingkat kesulitan (Mudah, Sedang, Sulit)
• Kuis Harian dan Cepat Tepat dengan spin hadiah
• Mode Tathbiq: jawab sebanyak mungkin soal dengan 3 nyawa
• Rank liga dari Bronze sampai Legend, plus pencapaian dan lencana
• Toko efek jawaban dan gaya nama (dibeli dengan Gold hasil belajar, bukan uang asli)
• Leaderboard dan profil pemain
• Laporkan soal yang salah agar bank soal makin baik

🔒 Aman
• Tanpa iklan
• Tidak meminta nama asli, email, atau lokasi
• Akun dan seluruh datanya bisa dihapus sendiri dari dalam aplikasi

Aplikasi memerlukan koneksi internet agar nilai dan XP tersimpan.

## 4. Data safety (rancangan jawaban)

Pastikan setiap jawaban cocok dengan `privasi.html`.

| Pertanyaan | Jawaban rancangan |
|---|---|
| Mengumpulkan data pengguna? | Ya |
| Dibagikan ke pihak ketiga? | Tidak (Neon dan Cloudflare memproses data atas nama kita sebagai penyedia layanan) |
| Data dienkripsi saat transit? | Ya (HTTPS) |
| Pengguna bisa meminta data dihapus? | Ya, dari dalam aplikasi dan lewat URL hapus akun |
| Jenis data | Info pribadi: ID pengguna (username). Foto: foto profil (opsional). Aktivitas aplikasi: interaksi dalam aplikasi (hasil kuis, XP). Konten buatan pengguna: laporan dengan catatan |
| Tujuan | Fungsi aplikasi, manajemen akun. **Bukan** iklan atau pemasaran |
| Wajib atau opsional | Username dan hasil kuis: wajib. Foto pribadi: opsional |

Catatan: huruf diambil dari Google Fonts, sehingga IP perangkat sampai ke Google. Bila ingin jawaban Data safety paling bersih, unduh fontnya dan sajikan dari `public/` (lalu sesuaikan CSP di `_headers`).

## 5. Target audiens dan konten

* **Rentang usia:** tentukan sesuai murid sebenarnya. Kalau ada murid di bawah 13 tahun dan kamu memilih rentang yang mencakup anak, kebijakan **Families** Google berlaku dan lebih ketat. Baca persyaratannya sebelum memilih.
* **Rating konten (IARC):** isi dengan jujur. Aplikasi edukasi tanpa kekerasan, tanpa konten dewasa, dan tanpa transaksi uang asli. Spin hadiah memakai Gold virtual yang diperoleh dari belajar dan tidak bisa dibeli, tetapi jawab pertanyaan tentang unsur acak/simulasi judi apa adanya.
* **Iklan:** Tidak ada.
* **Fitur interaksi pengguna:** ada leaderboard dan profil publik (username, foto). Moderasi: laporan pemain, hapus foto/akun oleh admin.
* **Akses ke aplikasi:** bila Play meminta akun uji untuk peninjau, buat satu akun murid biasa dan isi kredensialnya di **App content → App access**.

## 6. Alur rilis

1. Buat akun developer (biaya pendaftaran sekali bayar, cek nominal di Play Console). Pilih **personal** atau **organisasi**.
2. Buat aplikasi, isi semua bagian **App content** (privasi, Data safety, rating, target audiens, hapus akun).
3. Unggah `.aab` ke **Testing → Closed testing**, **aktifkan Play App Signing**.
4. Salin SHA-256 dari **App signing**, isi `assetlinks.json`, `git push`.
5. **Akun personal baru:** perlu closed test dengan minimal 12 tester yang tetap bergabung selama 14 hari berturut-turut sebelum bisa mengajukan akses produksi. Undang guru, wali murid, atau murid (mereka mendaftar dengan akun Google dan membuka tautan opt-in). Jangan sampai ada yang keluar di tengah jalan. Akun organisasi tidak terkena aturan ini, tetapi memerlukan verifikasi bisnis.
6. Setelah 14 hari, tekan **Apply for production**, lalu tunggu tinjauan.

## 7. Daftar periksa sebelum menekan "Kirim untuk ditinjau"

- [ ] `grep -rn "GANTI_" public` tidak menghasilkan apa-apa
- [ ] `/privasi.html`, `/hapus-akun.html`, `/.well-known/assetlinks.json` terbuka dari domain asli
- [ ] Aplikasi terbuka **tanpa bar alamat** di HP (assetlinks cocok)
- [ ] Daftar, masuk, kuis, Toko, laporan, dan **hapus akun** sudah dicoba dari aplikasi Android
- [ ] Data safety dan privasi.html konsisten
- [ ] Keystore dan passwordnya sudah dicadangkan di tempat aman (di luar GitHub)
