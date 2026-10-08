-- =====================================================================
--  Al-Miftah Kuis Nahwu — SKEMA DATABASE PENUH (Neon / PostgreSQL)
--  Disusun dari audit seluruh query di functions/api/[[path]].js, termasuk Kuis Lisan,
--  Kuis Sorof (6 level), pemakaian Groq, pencapaian, Gold harian/starter, Cepat Tepat,
--  foto profil, lencana, laporan soal/pemain, dan hapus akun.
--
--  * Idempotent: aman dijalankan berulang kali, di database BARU maupun database yang SUDAH ADA.
--    Tabel yang sudah ada tidak diubah dan datanya tidak dihapus.
--  * Satu transaksi: kalau ada yang gagal, tidak ada yang berubah.
--  * Semua tabel anak memakai ON DELETE CASCADE ke users, jadi "Hapus akun" cukup
--    menghapus satu baris di users.
--
--  Peta kode jilid di attempts.jilid (level selalu easy / medium / hard, atau endless untuk Tathbiq):
--    0        Mode Tathbiq (endless)
--    1–4      Kuis Tulis, Jilid 1–4
--    5        TIDAK DIPAKAI (hanya filter Tathbiq di leaderboard)
--    6–11     Kuis Sorof: 6 Pra Tathbiq, 7 Tathbiq 1, 8 Tathbiq 2, 9 Tathbiq 3, 10 Tathbiq 4, 11 Tathbiq 5
--
--  Saldo gold TIDAK disimpan; selalu dihitung:
--    gold = XP rekor (attempts) + gold_total_bonus(user) + SUM(user_achievements.gold) - SUM(purchases.price)
--    gold_total_bonus = hadiah spin (daily + daily_fast) + gold_grants (starter dan bonus harian rank)
--
--  Cara pakai: Neon Console > SQL Editor > tempel seluruh isi file ini > Run.
-- =====================================================================
begin;

-- ---------- 1. Pengguna ----------
create table if not exists users (
  id         serial primary key,
  username   text        not null check (username ~ '^[A-Za-z0-9_]{3,20}$'),
  pass_hash  text        not null,
  salt       text        not null,
  role       text        not null default 'student' check (role in ('student', 'admin')),
  avatar     text        not null default 'a1' check (avatar ~ '^a([1-9]|1[0-2])$'),
  fx         integer     check (fx is null or fx between 0 and 11),  -- efek bingkai profil: NULL = otomatis, 0 = tanpa efek
  fxa        text,                                   -- efek jawaban benar yang dipasang (NULL = konfeti bawaan)
  fxn        text,                                   -- gaya nama di leaderboard (kunci diawali n_)
  on_board   boolean     not null default false,     -- khusus admin: tampil di leaderboard
  photo_v    integer,                                -- versi foto pribadi (detik epoch); NULL = belum pernah unggah
  use_photo  boolean     not null default false,     -- true = foto pribadi dipakai sebagai avatar
  badges     text[]      not null default '{}',      -- sampai 3 lencana terpasang (kunci pencapaian)
  created_at timestamptz not null default now()
);
create unique index if not exists users_username_lower_uq on users (lower(username));

-- ---------- 2. Foto pribadi (satu baris per murid) ----------
create table if not exists user_photos (
  user_id    integer     primary key references users (id) on delete cascade,
  data       bytea       not null,
  mime       text        not null check (mime in ('image/webp', 'image/jpeg')),
  updated_at timestamptz not null default now()
);

-- ---------- 3. Bank soal Kuis Tulis ----------
create table if not exists questions (
  id     serial primary key,
  jilid  integer not null check (jilid between 1 and 4),
  bab    text    check (bab is null or char_length(bab) between 1 and 60),
  q      text    not null,
  a      text    not null,
  b      text    not null,
  c      text    not null,
  d      text    not null,
  answer text    not null check (answer in ('A', 'B', 'C', 'D'))
);
create index if not exists questions_jilid_idx     on questions (jilid);
create index if not exists questions_jilid_bab_idx on questions (jilid, lower(bab));

-- ---------- 4. Percobaan kuis (Tulis, Sorof, Tathbiq) ----------
-- jilid = 0 dan level = 'endless' untuk Tathbiq (score = XP sesi itu); jilid 1–4 Kuis Tulis; jilid 6–11 Kuis Sorof (lihat peta di atas).
-- nonce unik: cegah kirim ganda dan menjadi target ON CONFLICT pada Tathbiq. JANGAN dihapus: XP, rank, gold dihitung dari sini.
create table if not exists attempts (
  id         bigserial   primary key,
  user_id    integer     not null references users (id) on delete cascade,
  jilid      integer     not null check (jilid between 0 and 4 or jilid between 6 and 11),
  level      text        not null check (level in ('easy', 'medium', 'hard', 'endless')),
  total      integer     not null,
  correct    integer     not null,
  score      integer     not null,
  nonce      text        not null unique,
  created_at timestamptz not null default now(),
  constraint attempts_total_pos check (level = 'endless' or total > 0)
);
create index if not exists attempts_user_best_idx on attempts (user_id, jilid, level) include (correct, total, score);
create index if not exists attempts_user_time_idx on attempts (user_id, created_at desc);
create index if not exists attempts_created_idx   on attempts (created_at);

-- ---------- 5. Sesi Mode Tathbiq ----------
create table if not exists endless_runs (
  id         serial primary key,
  user_id    integer     not null references users (id) on delete cascade,
  asked      integer[]   not null default '{}',   -- id soal yang sudah dikirim ke klien, BERURUTAN
  n          integer     not null default 1,      -- nomor soal berikutnya yang harus dijawab
  cur        integer,                             -- tidak dipakai lagi (selalu NULL)
  cur_run    integer     not null default 0,      -- jawaban benar beruntun yang sedang berjalan
  lives      integer     not null default 3,
  score      integer     not null default 0,
  correct    integer     not null default 0,
  done       boolean     not null default false,
  created_at timestamptz not null default now()
);
create index if not exists endless_runs_user_idx on endless_runs (user_id) include (n);

-- ---------- 6. Toko ----------
create table if not exists purchases (
  user_id    integer     not null references users (id) on delete cascade,
  item       text        not null,
  price      integer     not null check (price >= 0),
  created_at timestamptz not null default now(),
  primary key (user_id, item)
);

-- ---------- 7. Kuis harian + spin, dan Cepat Tepat ----------
-- Satu baris per murid per hari (WIB). Baris dibuat saat kuis DIMULAI.
create table if not exists daily (
  user_id    integer     not null references users (id) on delete cascade,
  day        date        not null,
  done       boolean     not null default false,
  correct    integer,
  score      integer     check (score between 0 and 100),
  spun       boolean     not null default false,
  prize      integer     check (prize >= 0),
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);
create table if not exists daily_fast (
  user_id    integer     not null references users (id) on delete cascade,
  day        date        not null,
  done       boolean     not null default false,
  correct    integer,
  score      integer     check (score between 0 and 100),
  spun       boolean     not null default false,
  prize      integer     check (prize >= 0),
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);

-- ---------- 8. Pemberian Gold di luar XP dan spin ----------
-- kind 'starter' = Gold awal saat daftar; 'rank' = bonus harian sesuai rank (maksimal satu per hari).
create table if not exists gold_grants (
  user_id    integer     not null references users (id) on delete cascade,
  kind       text        not null check (kind in ('starter', 'rank')),
  day        date        not null,
  amount     integer     not null check (amount >= 0),
  created_at timestamptz not null default now(),
  primary key (user_id, kind, day)
);

-- ---------- 9. Pencapaian dan statistik ----------
create table if not exists user_achievements (
  user_id     integer     not null references users (id) on delete cascade,
  key         text        not null,
  gold        integer     not null default 0 check (gold >= 0),
  seen        boolean     not null default true,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, key)
);
create table if not exists user_stats (
  user_id  integer primary key references users (id) on delete cascade,
  best_run integer not null default 0
);

-- ---------- 10. Pembatas percobaan login ----------
create table if not exists login_attempts (
  key      text        primary key,
  n        integer     not null default 0,
  reset_at timestamptz not null
);

-- ---------- 11. Laporan soal salah ----------
-- kind: kunci | ketik | ambigu | lain. accepted = laporan benar (soal diedit/dihapus admin) -> kredit pencapaian "Mata Elang".
-- Hanya untuk soal Kuis Tulis dan Tathbiq. Soal Sorof dibuat otomatis, jadi tidak bisa dilaporkan.
create table if not exists question_reports (
  id          bigserial   primary key,
  question_id integer     not null references questions (id) on delete cascade,
  user_id     integer     not null references users (id) on delete cascade,
  kind        text        not null check (kind in ('kunci', 'ketik', 'ambigu', 'lain')),
  note        text        check (note is null or char_length(note) <= 200),
  status      text        not null default 'open' check (status in ('open', 'done')),
  accepted    boolean     not null default false,
  created_at  timestamptz not null default now()
);
create unique index if not exists question_reports_open_uq      on question_reports (question_id, user_id) where status = 'open';
create index        if not exists question_reports_status_idx   on question_reports (status, created_at desc);
create index        if not exists question_reports_user_idx     on question_reports (user_id, created_at desc);
create index        if not exists question_reports_question_idx on question_reports (question_id);

-- ---------- 12. Laporan pemain (username/foto yang tidak pantas) ----------
-- Satu murid hanya punya satu laporan TERBUKA per pemain. Pemain/pelapor dihapus = laporannya ikut terhapus.
create table if not exists player_reports (
  id          bigserial   primary key,
  target_id   integer     not null references users (id) on delete cascade,
  reporter_id integer     not null references users (id) on delete cascade,
  note        text        check (note is null or char_length(note) <= 200),
  status      text        not null default 'open' check (status in ('open', 'done')),
  created_at  timestamptz not null default now()
);
create unique index if not exists player_reports_open_uq      on player_reports (target_id, reporter_id) where status = 'open';
create index        if not exists player_reports_status_idx   on player_reports (status, created_at desc);
create index        if not exists player_reports_reporter_idx on player_reports (reporter_id, created_at desc);

-- ---------- 13. Kuis Lisan: bank lafadz ----------
-- steps = [{ "q": "Kalimat apa?", "a": ["Isim", "اسم"], "n": "catatan untuk penilai (opsional)" }, ...]  (1–12 langkah)
create table if not exists oral_items (
  id     serial  primary key,
  jilid  integer not null check (jilid between 1 and 4),
  bab    text    check (bab is null or char_length(bab) between 1 and 60),
  lafadz text    not null check (char_length(lafadz) between 1 and 100),
  steps  jsonb   not null check (jsonb_typeof(steps) = 'array'),
  active boolean not null default true
);
create index if not exists oral_items_jilid_idx on oral_items (jilid) where active;

-- ---------- 14. Kuis Lisan: riwayat jawaban murid ----------
-- item_id menjadi NULL bila lafadz dihapus admin (riwayat murid tetap ada). nonce = "<token sesi>:<item_id>", unik: cegah penilaian ganda.
-- detail = [{ "s": jawaban murid, "ok": true/false, "fb": umpan balik }, ...]; ai = true bila ada langkah yang dinilai AI.
create table if not exists oral_attempts (
  id         bigserial   primary key,
  user_id    integer     not null references users (id) on delete cascade,
  item_id    integer     references oral_items (id) on delete set null,
  jilid      integer     not null check (jilid between 1 and 4),
  correct    integer     not null check (correct >= 0),
  total      integer     not null check (total > 0),
  detail     jsonb,
  ai         boolean     not null default false,
  nonce      text        not null unique,
  created_at timestamptz not null default now(),
  constraint oral_attempts_correct_le_total check (correct <= total)
);
create index if not exists oral_attempts_user_item_idx on oral_attempts (user_id, item_id);
create index if not exists oral_attempts_user_time_idx on oral_attempts (user_id, created_at desc);
create index if not exists oral_attempts_created_idx   on oral_attempts (created_at);

-- ---------- 15. Kuis Sorof: bank sorof (6 level mengikuti file Tathbiq) ----------
-- Satu baris = satu fiil.
--   lv pra, t1, t2, t3 (Pra Tathbiq – Tathbiq 3)  -> forms = { "madhi": ["نَصَرَ"], "fail": ["نَاصِرٌ"], ... }
--       kunci sighot: madhi, mudhari, masdar (ghairu mim), masdar_mim, fail, maful, amar, nahi, zaman, alat; tiap sighot berupa larik alternatif.
--   lv t4, t5 (Tathbiq 4 dan 5, tashrif)          -> forms = { "s": [14 bentuk fiil untuk 14 dhamir; "" = tidak ada] }
-- grup = pola (level kata, mis. "فَعَلَ يَفْعُلُ") atau nama bagian (level tashrif, mis. "Mudhari 1").
-- Versi migrasi Sorof yang lama (kolom "kelas", tiga level) belum punya fitur impor sehingga tabelnya pasti kosong: dibuang agar diganti bentuk baru.
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'sorof_words' and column_name = 'kelas') then
    drop table public.sorof_words;
  end if;
end $$;
create table if not exists sorof_words (
  id     serial  primary key,
  lv     text    not null check (lv in ('pra', 't1', 't2', 't3', 't4', 't5')),
  grup   text    not null check (char_length(grup) between 1 and 80),
  forms  jsonb   not null check (jsonb_typeof(forms) = 'object'),
  active boolean not null default true
);
create index if not exists sorof_words_lv_idx on sorof_words (lv) where active;

-- ---------- 16. Pemakaian Groq (penilai AI Kuis Lisan) ----------
-- Satu baris per panggilan; dibaca tab "Groq" di panel admin. Backend juga membuatnya sendiri bila belum ada.
create table if not exists ai_usage (
  id                bigserial   primary key,
  created_at        timestamptz not null default now(),
  model             text        not null,
  status            int         not null,
  ok                boolean     not null,
  prompt_tokens     int,
  completion_tokens int,
  total_tokens      int,
  ms                int,
  rem_req           int,
  lim_req           int,
  rem_tok           int,
  lim_tok           int,
  reset_req         text
);
create index if not exists ai_usage_t on ai_usage (created_at desc);

-- ---------- 17. Fungsi gold_total_bonus ----------
-- Total Gold di luar XP rekor dan hadiah pencapaian: hadiah spin (kuis harian + Cepat Tepat) + gold_grants.
-- Mengembalikan integer supaya driver Neon memberi angka biasa ke JavaScript.
create or replace function public.gold_total_bonus(p_user integer) returns integer
language sql stable
as $f$
  select (
    coalesce((select sum(prize)  from daily       where user_id = p_user and spun), 0) +
    coalesce((select sum(prize)  from daily_fast  where user_id = p_user and spun), 0) +
    coalesce((select sum(amount) from gold_grants where user_id = p_user), 0)
  )::integer
$f$;

-- ---------- 18. PEMUTAKHIRAN database yang SUDAH ADA ----------
-- Pada database lama, attempts.jilid hanya boleh 0–4. Batasan itu diganti supaya kode jilid Sorof 6–11 diterima.
-- Nama batasan dicari lewat isinya (bukan namanya), jadi aman untuk database baru maupun lama.
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.attempts'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%jilid%'
  loop
    execute format('alter table public.attempts drop constraint %I', c.conname);
  end loop;
  alter table public.attempts add constraint attempts_jilid_check check (jilid between 0 and 4 or jilid between 6 and 11);
end $$;

analyze;
commit;

-- =====================================================================
--  LANGKAH MANUAL (jalankan sendiri, satu per satu)
-- =====================================================================
-- A) Jadikan akun admin (daftar dulu lewat aplikasi, lalu):
--    update users set role = 'admin' where lower(username) = lower('NAMA_ADMIN');
-- B) Isi bank soal lewat Panel Admin: "Kelola soal" (Kuis Tulis), "Soal lisan", dan "Bank Sorof" (bank-sorof.xlsx).
-- C) Perawatan berkala (opsional):
--    delete from login_attempts where reset_at < now() - interval '1 day';
--    delete from question_reports where status = 'done' and created_at < now() - interval '90 days';
--    delete from player_reports   where status = 'done' and created_at < now() - interval '90 days';
--    delete from ai_usage         where created_at < now() - interval '30 days';
--
--  PEMERIKSAAN (jalankan terpisah setelah commit):
--    select table_name from information_schema.tables where table_schema = 'public' order by 1;   -- harus ada 18 tabel
--    select pg_get_constraintdef(oid) from pg_constraint where conrelid = 'attempts'::regclass and contype = 'c';   -- jilid ... 4 ... 6 ... 11
