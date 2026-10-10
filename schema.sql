-- =====================================================================
--  Al-Miftah Kuis: skema database lengkap (PostgreSQL / Neon)
--
--  Disusun dari seluruh query di backend (functions/api/[[path]].js).
--  Aman dijalankan berulang kali (create ... if not exists), jadi boleh
--  dijalankan di database kosong maupun yang sudah berisi. Di database
--  lama, bagian "Penyesuaian database lama" di akhir menambah kolom yang
--  mungkin belum ada tanpa menghapus data.
--
--  Cara pakai: tempel seluruh isi file ke Neon > SQL Editor > Run.
--
--  Catatan zona waktu: kolom "day" (tipe date) selalu diisi kode dengan
--  tanggal WIB (Asia/Jakarta), jadi tidak ada konversi di sini.
--
--  Kode jilid di tabel attempts:
--     0      = Tathbiq (level 'endless')
--     1-4    = Kuis Tulis jilid 1-4 (level easy / medium / hard)
--     6-11   = Kuis Sorof (pra, t1..t5)
--     12-15  = Kuis Lisan (11 + jilid)
-- =====================================================================


-- ---------------------------------------------------------------------
--  1. Akun
-- ---------------------------------------------------------------------
create table if not exists users (
  id         serial primary key,
  username   text        not null,
  pass_hash  text        not null,                 -- PBKDF2
  salt       text        not null,                 -- base64url
  role       text        not null default 'student' check (role in ('student', 'admin')),
  avatar     text        not null default '🙂',
  fx         text,                                  -- pilihan tampilan profil
  fxa        text        not null default 'confetti', -- efek jawaban benar yang dipakai
  fxn        text,                                  -- efek nama yang dipakai (null = tidak ada)
  on_board   boolean     not null default true,     -- tampil di leaderboard (relevan untuk admin)
  photo_v    int,                                   -- versi foto, untuk cache; null = tidak punya foto
  use_photo  boolean     not null default false,
  badges     text[]      not null default '{}',     -- pencapaian yang dipajang
  created_at timestamptz not null default now()
);
-- username tidak peka huruf besar/kecil (kode selalu memakai lower(username))
create unique index if not exists users_username_ci on users (lower(username));

create table if not exists user_photos (
  user_id    int         primary key references users(id) on delete cascade,
  data       bytea       not null,
  mime       text        not null,
  updated_at timestamptz not null default now()
);

-- Pembatas percobaan login: kunci 'u:<username>' dan sejenisnya
create table if not exists login_attempts (
  key      text        primary key,
  n        int         not null default 1,
  reset_at timestamptz not null
);


-- ---------------------------------------------------------------------
--  2. Bank soal dan hasil Kuis Tulis / Tathbiq / Sorof
-- ---------------------------------------------------------------------
create table if not exists questions (
  id     serial primary key,
  jilid  int    not null,
  bab    text,
  q      text   not null,
  a      text   not null,
  b      text   not null,
  c      text   not null,
  d      text   not null,
  answer text   not null check (answer in ('A', 'B', 'C', 'D'))
);
create index if not exists questions_jilid_bab on questions (jilid, bab);

-- Satu baris per sesi yang diselesaikan. nonce unik mencegah kirim ganda.
create table if not exists attempts (
  id         bigserial   primary key,
  user_id    int         not null references users(id) on delete cascade,
  jilid      int         not null,
  level      text        not null,                  -- easy | medium | hard | endless
  total      int         not null,
  correct    int         not null,
  score      int         not null,                  -- persen, 0-100 (Tathbiq: skor mentah)
  nonce      text        not null unique,
  created_at timestamptz not null default now()
);
create index if not exists attempts_user_quest on attempts (user_id, jilid, level);
create index if not exists attempts_user_time  on attempts (user_id, created_at);

-- Sesi Tathbiq (nyawa, tahap, soal yang sudah keluar)
create table if not exists endless_runs (
  id         bigserial   primary key,
  user_id    int         not null references users(id) on delete cascade,
  asked      int[]       not null default '{}',     -- id soal yang sudah ditanyakan
  n          int         not null default 1,        -- nomor soal berjalan
  lives      int         not null default 3,
  score      int         not null default 0,
  correct    int         not null default 0,
  cur        text,                                   -- cadangan lama, selalu dikosongkan kode
  cur_run    int         not null default 0,        -- benar beruntun saat ini
  done       boolean     not null default false,
  created_at timestamptz not null default now()
);
create index if not exists endless_runs_user on endless_runs (user_id);

-- Rekor benar beruntun terbaik tiap murid
create table if not exists user_stats (
  user_id  int primary key references users(id) on delete cascade,
  best_run int not null default 0
);

-- Bank kata Kuis Sorof. forms: level "kata" = { madhi, mudhari, ... }, level "tashrif" = { s: [14 bentuk] }
create table if not exists sorof_words (
  id     serial  primary key,
  lv     text    not null,                          -- pra | t1 | t2 | t3 | t4 | t5
  grup   text,
  forms  jsonb   not null,
  active boolean not null default true
);
create index if not exists sorof_words_lv on sorof_words (lv) where active;


-- ---------------------------------------------------------------------
--  3. Kuis Lisan
-- ---------------------------------------------------------------------
create table if not exists oral_items (
  id     serial  primary key,
  jilid  int     not null,
  bab    text,
  lafadz text    not null,
  steps  jsonb   not null,                          -- langkah tanya-jawab beserta bank jawaban
  active boolean not null default true
);
create index if not exists oral_items_jilid on oral_items (jilid) where active;

-- Riwayat murid tetap ada walau soal dihapus (item_id menjadi null)
create table if not exists oral_attempts (
  id         bigserial   primary key,
  user_id    int         not null references users(id) on delete cascade,
  item_id    int         references oral_items(id) on delete set null,
  jilid      int         not null,
  correct    int         not null,
  total      int         not null,
  detail     jsonb,
  ai         boolean     not null default false,    -- true bila dinilai AI (Groq)
  nonce      text        not null unique,
  created_at timestamptz not null default now()
);
create index if not exists oral_attempts_user_time on oral_attempts (user_id, created_at);

-- Pemakaian API Groq (kuota dan token)
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


-- ---------------------------------------------------------------------
--  4. Event harian (satu baris per murid per hari, WIB)
-- ---------------------------------------------------------------------
create table if not exists daily_cfg (
  key text  primary key,                             -- 'events'
  val jsonb not null
);

create table if not exists daily (
  user_id int     not null references users(id) on delete cascade,
  day     date    not null,
  done    boolean not null default false,
  correct int,
  score   int,
  spun    boolean not null default false,
  prize   int,
  primary key (user_id, day)
);

create table if not exists daily_fast (
  user_id int     not null references users(id) on delete cascade,
  day     date    not null,
  done    boolean not null default false,
  correct int,
  score   int,
  spun    boolean not null default false,
  prize   int,
  primary key (user_id, day)
);

create table if not exists daily_sorof (
  user_id int     not null references users(id) on delete cascade,
  day     date    not null,
  done    boolean not null default false,
  correct int,
  score   int,
  spun    boolean not null default false,
  prize   int,
  primary key (user_id, day)
);

create table if not exists daily_oral (
  user_id int     not null references users(id) on delete cascade,
  day     date    not null,
  res     jsonb   not null default '{}'::jsonb,      -- { "<id lafadz>": [benar, total] }
  done    boolean not null default false,
  correct int,
  score   int,
  spun    boolean not null default false,
  prize   int,
  primary key (user_id, day)
);


-- ---------------------------------------------------------------------
--  5. Gold, toko Efek, dan pencapaian
-- ---------------------------------------------------------------------
-- Gold tambahan: 'starter' (sekali, saat daftar) dan 'rank' (sekali per hari)
create table if not exists gold_grants (
  id         bigserial   primary key,
  user_id    int         not null references users(id) on delete cascade,
  kind       text        not null,
  day        date        not null,
  amount     int         not null,
  created_at timestamptz not null default now(),
  unique (user_id, kind, day)
);

create table if not exists purchases (
  user_id    int         not null references users(id) on delete cascade,
  item       text        not null,
  price      int         not null,
  created_at timestamptz not null default now(),
  primary key (user_id, item)
);

create table if not exists user_achievements (
  user_id     int         not null references users(id) on delete cascade,
  key         text        not null,
  gold        int         not null default 0,        -- hadiah Gold saat dibuka
  seen        boolean     not null default false,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, key)
);

-- Total Gold bonus di luar XP rekor dan hadiah pencapaian:
-- hadiah spin dari keempat event harian ditambah baris gold_grants.
create or replace function gold_total_bonus(uid int) returns int
language sql stable as $$
  select (
      coalesce((select sum(amount) from gold_grants  where user_id = uid), 0)
    + coalesce((select sum(prize)  from daily        where user_id = uid and spun), 0)
    + coalesce((select sum(prize)  from daily_fast   where user_id = uid and spun), 0)
    + coalesce((select sum(prize)  from daily_sorof  where user_id = uid and spun), 0)
    + coalesce((select sum(prize)  from daily_oral   where user_id = uid and spun), 0)
  )::int
$$;


-- ---------------------------------------------------------------------
--  6. Laporan
-- ---------------------------------------------------------------------
-- kind: kunci | ketik | ambigu | lain. Satu laporan terbuka per murid per soal.
create table if not exists question_reports (
  id          serial      primary key,
  question_id int         not null references questions(id) on delete cascade,
  user_id     int         not null references users(id) on delete cascade,
  kind        text        not null check (kind in ('kunci', 'ketik', 'ambigu', 'lain')),
  note        text,
  status      text        not null default 'open' check (status in ('open', 'done')),
  accepted    boolean     not null default false,   -- true bila admin menerima laporan
  created_at  timestamptz not null default now()
);
create unique index if not exists question_reports_open_uq on question_reports (question_id, user_id) where status = 'open';
create index if not exists question_reports_status on question_reports (status);

create table if not exists player_reports (
  id          serial      primary key,
  target_id   int         not null references users(id) on delete cascade,
  reporter_id int         not null references users(id) on delete cascade,
  note        text,
  status      text        not null default 'open' check (status in ('open', 'done')),
  created_at  timestamptz not null default now()
);
create unique index if not exists player_reports_open_uq on player_reports (target_id, reporter_id) where status = 'open';
create index if not exists player_reports_status on player_reports (status);


-- ---------------------------------------------------------------------
--  7. Penyesuaian database lama (aman dijalankan di database kosong)
--     Menambah kolom yang mungkin belum ada karena fitur ditambahkan bertahap.
-- ---------------------------------------------------------------------
alter table users         add column if not exists fxa       text    not null default 'confetti';
alter table users         add column if not exists fxn       text;
alter table users         add column if not exists on_board  boolean not null default true;
alter table users         add column if not exists photo_v   int;
alter table users         add column if not exists use_photo boolean not null default false;
alter table users         add column if not exists badges    text[]  not null default '{}';
alter table users         add column if not exists created_at timestamptz not null default now();
alter table endless_runs  add column if not exists cur_run   int     not null default 0;
alter table oral_attempts add column if not exists ai        boolean not null default false;
alter table oral_attempts add column if not exists detail    jsonb;
alter table question_reports add column if not exists accepted boolean not null default false;


-- ---------------------------------------------------------------------
--  8. Setelah menjalankan: jadikan satu akun sebagai admin
--     (daftar dulu lewat aplikasi, lalu jalankan baris ini, ganti namanya)
-- ---------------------------------------------------------------------
-- update users set role = 'admin' where lower(username) = lower('NAMA_ADMIN');


-- ---------------------------------------------------------------------
--  9. Opsional: bandingkan dengan database yang sedang berjalan
--     Menampilkan semua kolom per tabel untuk dicocokkan dengan file ini.
-- ---------------------------------------------------------------------
-- select table_name, string_agg(column_name || ' ' || data_type, ', ' order by ordinal_position)
-- from information_schema.columns where table_schema = 'public' group by table_name order by table_name;
