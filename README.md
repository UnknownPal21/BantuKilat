# BantuKilat

Aplikasi bantu-tetangga untuk kerusakan rumah kecil: **foto kerusakan → AI menebak jenis kerusakan + rentang harga wajar → teknisi di sekitar mengajukan penawaran → user memilih → tugas selesai.**

Dibuat untuk Hackathon Logicodex 2026.

> **Status:** Backend sudah berjalan dan teruji (26 tes otomatis). Frontend Flutter masih berupa prototipe UI — halaman sudah ada, tetapi belum tersambung ke API. Detail di [Status proyek](#status-proyek).

---

## Daftar isi

- [Masalah yang dipecahkan](#masalah-yang-dipecahkan)
- [Cara kerja singkat](#cara-kerja-singkat)
- [Fitur](#fitur)
- [Arsitektur](#arsitektur)
- [Requirement](#requirement)
- [Menjalankan backend](#menjalankan-backend)
- [Menjalankan frontend](#menjalankan-frontend)
- [Panduan API cepat](#panduan-api-cepat)
- [Struktur folder](#struktur-folder)
- [Konfigurasi](#konfigurasi)
- [Tes](#tes)
- [Script bantu](#script-bantu)
- [Masalah umum](#masalah-umum)
- [Status proyek](#status-proyek)

---

## Masalah yang dipecahkan

Orang awam tidak tahu dua hal saat barang di rumah rusak:

1. **Ini kerusakan apa?** (kran bocor karena seal, atau karena pipa retak?)
2. **Harga wajarnya berapa?** (Rp 50 ribu atau Rp 500 ribu?)

Akibatnya user takut ditipu, dan teknisi harus bolak-balik bertanya lewat chat. BantuKilat memotong dua langkah itu: user cukup **foto + deskripsi singkat**, lalu langsung mendapat dugaan kerusakan dan estimasi harga yang diambil dari data transaksi historis — bukan angka karangan model AI.

## Cara kerja singkat

```
User                     Backend                         Teknisi
 │
 │ 1. Foto kerusakan ───► POST /media          (foto disimpan, bukan base64)
 │
 │ 2. "Kran bocor"  ─────► POST /ai/chats/{id}/messages
 │                          ├─ AI klasifikasi kategori + keparahan
 │                          └─ harga diambil dari price_catalog
 │    ◄── estimate + narasi + saran keselamatan
 │
 │ 3. Buat tawaran  ─────► POST /offers         ──► muncul di /offers/nearby
 │                                                       │
 │                                                       │ 4. Ajukan harga
 │    ◄──────────────────────────   POST /offers/{id}/bids
 │
 │ 5. Terima satu bid ───► POST /bids/{id}/accept   (bid lain otomatis ditolak)
 │
 │ 6. Teknisi selesai ───► POST /offers/{id}/complete
 │                          └─ harga deal masuk katalog → AI makin akurat
```

**Prinsip harga:** model AI **tidak pernah** menulis nominal rupiah. Model hanya menentukan *kategori* dan *keparahan*. Angka rupiah selalu disusun server dari `price_catalog`. Kalau data belum cukup, server bilang tidak tahu — tidak menebak.

## Fitur

### Sudah jalan (backend)

| Fitur | Ringkasan |
|---|---|
| **Auth** | Register/login (USER & TECHNICIAN), JWT, `GET /auth/me`, update nomor HP |
| **Kategori** | 7 kategori seeded (Kelistrikan, Air, Kendaraan, Angkut Barang, Teknologi, Bantuan Lain, Pertukangan) |
| **Tawaran (offer)** | Buat, lihat detail, daftar sekitar berbasis radius (`$geoNear`), daftar milik sendiri, auto-expired setelah 30 menit |
| **Penawaran (bid)** | Teknisi mengajukan harga; satu bid `PENDING` per teknisi per offer; accept atomik (bid lain → `REJECTED`) |
| **Chat AI** | Percakapan + pesan teks/foto, estimasi ber-grounding katalog, saran keselamatan, riwayat 10 pesan sebagai konteks |
| **Media** | Upload JPEG terkompresi (≤1024 px), URL bertanda tangan HMAC + kedaluwarsa, batas harian |
| **Katalog harga** | 2.520 sampel seed + 84 baris katalog; fallback kota → nasional; sampel `DEAL` otomatis dari tawaran selesai |
| **Kuota** | Kuota harian atomik per akun: chat, estimasi, pesan berfoto |

### Belum ada

- Frontend tersambung ke API (login, daftar tawaran, bid, chat AI)
- Ulasan/rating (`reviews` sudah dirancang di skema, belum dikodekan)
- Job cron `EXPIRED` (saat ini offer kedaluwarsa disaring di query, status di DB belum diubah)
- Batal tawaran (`CANCELLED`), tolak/tarik bid manual
- Notifikasi / push

## Arsitektur

```
FrontEnd/bantukilat/     Flutter (Android / iOS / web), rendering UI
        │  HTTP + JWT
        ▼
BackEnd/                 FastAPI (Python 3.12)
        ├── routers/     endpoint HTTP
        ├── services/    logika bisnis (offer, bid, ai, media, harga)
        ├── models/      skema request/response Pydantic
        └── db/          koneksi + index + seed
                │  async (AsyncMongoClient)
                ▼
        MongoDB Atlas
        users · categories · offers · bids
        media · ai_conversations · ai_messages
        price_samples · price_catalog · ai_usage
```

- **Backend:** FastAPI, MongoDB (driver async `AsyncMongoClient`), Python 3.12.
- **AI:** provider apa pun yang bicara **protokol OpenAI-compatible** (Gemini, DeepSeek, OpenAI, OpenRouter, Groq). Diatur lewat tiga env var — tanpa ubah kode.
- **Fallback tanpa API key:** server memakai pengklasifikasi kata kunci lokal (`model: "local-heuristic"`), jadi demo tetap jalan dan gratis.

## Requirement

| Perlu | Versi / catatan |
|---|---|
| Python | **3.12+** |
| [uv](https://docs.astral.sh/uv/) | pengelola paket Python (`pip install uv`) |
| MongoDB | **Atlas** (cloud) atau MongoDB lokal. Wajib mendukung geospatial `2dsphere` |
| Flutter | **3.27+** (project memakai Dart SDK `^3.13.7`) |
| Android Studio / SDK | hanya jika menjalankan di emulator/HP Android |
| (opsional) API key AI | tanpa ini aplikasi tetap jalan dengan fallback lokal |

## Menjalankan backend

### 1. Masuk ke folder backend

```bash
cd BackEnd
```

### 2. Install dependency

```bash
uv sync
```

Perintah ini membuat `.venv` dan memasang semua paket dari `uv.lock`.

### 3. Siapkan `.env`

```bash
cp .env.example .env
```

Lalu isi file `.env`:

```dotenv
MONGO_URL=mongodb+srv://<user>:<password>@<cluster>.mongodb.net
MONGO_DB_NAME=bantukilat
JWT_SECRET=<minimal 32 karakter acak>
JWT_EXPIRE_MINUTES=10080
SERVER_SELECTION_TIMEOUT_MS=5000
```

Membuat `JWT_SECRET` yang aman:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(48))"
```

> Server **menolak start** kalau `JWT_SECRET` kurang dari 32 karakter. Ini disengaja.

Opsional — mengaktifkan AI sungguhan (ganti sesuai provider):

```dotenv
AI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai
AI_MODEL=gemini-2.5-flash
AI_API_KEY=<api key kamu>
```

Contoh provider lain yang sudah dicoba:

| Provider | `AI_BASE_URL` | `AI_MODEL` |
|---|---|---|
| Gemini | `https://generativelanguage.googleapis.com/v1beta/openai` | `gemini-2.5-flash` |
| DeepSeek (via AIport) | `https://aiport.id/v1` | `deepseek-flash` |

### 4. Siapkan database (index + kategori)

```bash
uv run python -m backend.db.setup
```

Perintah ini idempoten — aman dijalankan berkali-kali. Isinya: membuat index dan schema validator, serta mengisi 7 kategori.

### 5. (Opsional) Isi data demo harga

```bash
uv run python scripts/seed_price_samples.py
```

Menambahkan 2.520 sampel harga demo untuk **Surabaya, Jakarta, Bandung**, lalu menghitung `price_catalog`. Tanpa langkah ini, chat AI masih jalan tetapi akan menjawab "data harga belum cukup".

Data nyata (user, offer, bid) tidak disentuh. Untuk menghapus data demo: `db.price_samples.delete_many({"source": "SEED"})` lalu jalankan `scripts/refresh_price_catalog.py`.

### 6. Jalankan server

```bash
uv run fastapi dev src/backend/main.py
```

Server berjalan di **http://127.0.0.1:8000**.

| URL | Isi |
|---|---|
| http://127.0.0.1:8000/docs | Swagger UI — coba semua endpoint dari browser |
| http://127.0.0.1:8000/redoc | Dokumentasi read-only |
| http://127.0.0.1:8000/health | Cek server hidup (`{"status":"ok"}`) |

Cek cepat dari terminal:

```bash
curl http://127.0.0.1:8000/health
# {"status":"ok"}
```

Untuk production-like (tanpa auto-reload):

```bash
uv run fastapi run src/backend/main.py
```

## Menjalankan frontend

### 1. Masuk ke folder app

```bash
cd FrontEnd/bantukilat
```

### 2. Install dependency & jalankan

```bash
flutter pub get
```

Lalu pilih target:

```bash
# Emulator Android (disarankan)
flutter emulators --launch <nama_emulator>
flutter run

# HP Android via USB (aktifkan USB debugging)
flutter devices
flutter run -d <device-id>

# Web (butuh Chrome; set CHROME_EXECUTABLE kalau Chrome tidak di PATH)
export CHROME_EXECUTABLE=$(command -v chromium)
flutter run -d chrome
```

### 3. Build APK

```bash
flutter build apk --debug     # untuk uji coba
flutter build apk --release   # untuk dibagikan
```

Hasil build ada di `build/app/outputs/flutter-apk/`.

> **Catatan penting:** halaman login saat ini masih prototipe. Ketik `user` di kolom email untuk membuka halaman user, atau `teknisi` untuk halaman teknisi. Belum ada pemanggilan ke backend dari sisi Flutter.

### Alamat backend dari emulator/HP

Frontend belum punya konfigurasi base URL. Saat nanti disambungkan, pakai alamat berikut:

| Target | Alamat backend |
|---|---|
| Emulator Android | `http://10.0.2.2:8000` (`10.0.2.2` = localhost komputer) |
| HP fisik di Wi-Fi yang sama | `http://<IP-laptop>:8000` — jalankan server dengan `--host 0.0.0.0` |
| Web / desktop | `http://127.0.0.1:8000` |

Untuk HTTP polos di Android, tambahkan `android:usesCleartextTraffic="true"` pada `<application>` di `android/app/src/main/AndroidManifest.xml`.

## Panduan API cepat

Semua endpoint kecuali `/health` dan `GET /media/{id}` butuh header:

```
Authorization: Bearer <access_token>
```

### 1. Register

```bash
curl -X POST http://127.0.0.1:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "role": "USER",
    "name": "Sari",
    "email": "sari@example.com",
    "phone": "+6281234567890",
    "password": "rahasia123",
    "city": "Surabaya",
    "district": "Mulyorejo"
  }'
```

Untuk teknisi, tambahkan `"skills": ["PLUMBING"]` dan `"terms_accepted": true`.

Response berisi `access_token` dan `user`. Simpan tokennya:

```bash
TOKEN="<access_token dari response>"
```

### 2. Upload foto

Foto dikirim sebagai **data URI base64** dalam JSON. Setelah tersimpan, yang kamu terima hanya `id` dan `url` — base64 tidak pernah masuk database.

```bash
PHOTO_ID=$(base64 -w0 foto-kran.jpg | sed 's|^|data:image/jpeg;base64,|' | \
  jq -R '{data: ., kind: "offers"}' | \
  curl -s -X POST http://127.0.0.1:8000/media \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" -d @- | jq -r .id)
```

### 3. Buat tawaran

```bash
curl -X POST http://127.0.0.1:8000/offers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"category_id\": \"<id dari GET /categories>\",
    \"title\": \"Kran wastafel bocor\",
    \"description\": \"Air menetes terus sejak pagi, lantai basah.\",
    \"photos\": [\"$PHOTO_ID\"],
    \"lng\": 112.7531,
    \"lat\": -7.2412,
    \"address_text\": \"Jl. Mulyorejo Tengah No. 45\",
    \"initial_budget\": 20000
  }"
```

`photos` menerima **id media** atau **URL `/media/<id>`** — keduanya dinormalisasi menjadi id. Data URI mentah ditolak dengan `422 PHOTO_NOT_UPLOADED`.

### 4. Lihat tawaran di sekitar (teknisi)

```bash
curl "http://127.0.0.1:8000/offers/nearby?lat=-7.2412&lng=112.7531&radius=5000" \
  -H "Authorization: Bearer $TOKEN"
```

### 5. Ajukan penawaran (teknisi)

```bash
curl -X POST "http://127.0.0.1:8000/offers/<offer_id>/bids" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount": 35000, "message": "Bisa saya kerjakan sore ini"}'
```

### 6. Terima penawaran (user)

```bash
curl -X POST "http://127.0.0.1:8000/bids/<bid_id>/accept" \
  -H "Authorization: Bearer $TOKEN"
```

### 7. Chat AI

```bash
# Buat percakapan
CHAT_ID=$(curl -s -X POST http://127.0.0.1:8000/ai/chats \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{}' | jq -r ._id)

# Kirim cerita + foto
curl -X POST "http://127.0.0.1:8000/ai/chats/$CHAT_ID/messages" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"Kran wastafel bocor, air menetes terus\", \"photos\": [\"$PHOTO_ID\"]}"
```

Balasan berisi `estimate` (kategori, keparahan, rentang harga + jumlah sampel yang dipakai) dan `assistant_message` (narasi). Kalau provider AI sedang mati, `assistant_message.retryable` bernilai `true` — aman dicoba ulang tanpa mengetik ulang.

### Ringkasan endpoint

| Method | Path | Auth | Keterangan |
|---|---|---|---|
| `GET` | `/health` | – | Cek server |
| `POST` | `/auth/register` | – | Daftar, dapat token |
| `POST` | `/auth/login` | – | Login, dapat token |
| `GET` | `/auth/me` | ✔ | Profil sendiri |
| `PATCH` | `/auth/me/phone` | ✔ | Ubah nomor HP |
| `GET` | `/categories` | – | Daftar kategori aktif |
| `POST` | `/media` | ✔ | Upload satu foto (base64) |
| `GET` | `/media/{id}` | tanda tangan | Ambil foto (`?exp=&sig=`) |
| `POST` | `/offers` | ✔ | Buat tawaran |
| `GET` | `/offers/nearby` | ✔ | Tawaran dalam radius |
| `GET` | `/offers/mine` | ✔ | Tawaran milik sendiri |
| `GET` | `/offers/{id}` | ✔ | Detail tawaran |
| `GET` | `/offers/{id}/bids` | ✔ | Daftar penawaran |
| `POST` | `/offers/{id}/bids` | ✔ teknisi | Ajukan penawaran |
| `POST` | `/bids/{id}/accept` | ✔ | Terima penawaran |
| `POST` | `/offers/{id}/complete` | ✔ teknisi | Tandai selesai |
| `POST` | `/ai/estimate` | ✔ | Estimasi tanpa menyimpan |
| `POST` | `/ai/chats` | ✔ | Buat percakapan |
| `GET` | `/ai/chats` | ✔ | Daftar percakapan |
| `GET` | `/ai/chats/{id}` | ✔ | Isi percakapan |
| `POST` | `/ai/chats/{id}/messages` | ✔ | Kirim pesan |
| `POST` | `/ai/chats/{id}/close` | ✔ | Tutup percakapan |

Error selalu berbentuk:

```json
{ "code": "OFFER_ALREADY_COMPLETED", "message": "Tawaran sudah diselesaikan" }
```

Kode yang sering muncul saat development:

| Kode | HTTP | Arti |
|---|---|---|
| `PHOTO_NOT_UPLOADED` | 422 | Data URI dikirim langsung; upload ke `/media` dulu |
| `PHOTO_NOT_FOUND` | 422 | Id foto bukan milik akun ini |
| `MEDIA_URL_INVALID` / `MEDIA_URL_EXPIRED` | 403 | URL foto rusak atau kedaluwarsa (TTL 1 jam) |
| `AI_RATE_LIMITED` | 429 | Kuota chat/estimasi harian habis |
| `AI_PHOTO_RATE_LIMITED` | 429 | Kuota pesan berfoto harian habis |
| `OFFER_ALREADY_COMPLETED` | 409 | Offer sudah selesai (oleh orang lain) |
| `EMAIL_TAKEN` | 409 | Email sudah terdaftar |

## Struktur folder

```
BantuKilat/
├── README.md                  ← file ini
├── BackEnd/
│   ├── pyproject.toml         dependency & konfigurasi pytest
│   ├── uv.lock                versi paket terkunci
│   ├── .env.example           contoh konfigurasi (copy ke .env)
│   ├── src/backend/
│   │   ├── main.py            entrypoint FastAPI
│   │   ├── core/              config, auth, error, rate limit
│   │   ├── db/                koneksi Mongo, index, seed kategori
│   │   ├── models/            skema Pydantic
│   │   ├── routers/           endpoint HTTP
│   │   └── services/          logika bisnis
│   ├── scripts/               seed, eval AI, bersih-bersih data
│   ├── tests/                 tes otomatis (pytest)
│   └── docs/                  catatan desain (tidak ikut git)
└── FrontEnd/bantukilat/       aplikasi Flutter
    ├── lib/main.dart
    ├── lib/page/              halaman UI
    └── pubspec.yaml
```

## Konfigurasi

Semua setelan backend dibaca dari `BackEnd/.env`. Nilai di bawah adalah default kalau tidak diisi.

| Variabel | Default | Fungsi |
|---|---|---|
| `MONGO_URL` | — **(wajib)** | Connection string MongoDB |
| `MONGO_DB_NAME` | — **(wajib)** | Nama database |
| `JWT_SECRET` | — **(wajib, ≥32 karakter)** | Kunci tanda tangan JWT **dan** URL foto |
| `JWT_EXPIRE_MINUTES` | `1440` | Umur token. Demo memakai `10080` (7 hari) |
| `PUBLIC_BASE_URL` | `http://localhost:8000` | Basis URL foto di response. Ganti dengan domain asli saat deploy |
| `AI_BASE_URL` | endpoint Gemini | Base URL provider OpenAI-compatible |
| `AI_MODEL` | `gemini-2.5-flash` | Nama model |
| `AI_API_KEY` | kosong | Kosong = fallback lokal gratis |
| `AI_ALLOW_LOCAL_FALLBACK` | `true` | Izinkan fallback saat key kosong |
| `AI_TIMEOUT_SECONDS` | `30` | Timeout panggilan provider |
| `AI_DAILY_MESSAGE_LIMIT` | `20` | Kuota pesan chat per hari |
| `AI_DAILY_ESTIMATE_LIMIT` | `40` | Kuota `/ai/estimate` per hari |
| `AI_DAILY_PHOTO_MESSAGE_LIMIT` | `10` | Kuota pesan berfoto per hari |
| `AI_QUOTA_UTC_OFFSET_HOURS` | `7` | Kuota reset tengah malam WIB |
| `MEDIA_URL_TTL_SECONDS` | `3600` | Umur URL foto bertanda tangan |
| `MEDIA_DAILY_VIEW_LIMIT` | `600` | Batas buka foto per IP per hari |
| `MEDIA_DAILY_UPLOAD_LIMIT` | `60` | Batas upload per akun per hari |

> `BackEnd/.env` di-`.gitignore`. Jangan pernah commit file itu.

## Tes

Semua tes berjalan di database terpisah dan **tidak pernah menyentuh data asli**.

```bash
cd BackEnd
uv run pytest -q
```

Ekspektasi: **26 passed**.

Tes memaksa `MONGO_DB_NAME=bantukilat_test`, membuat database itu, lalu menghapusnya setelah selesai. Kalau nama database tidak berakhiran `_test`, tes menolak berjalan.

Cakupan:

| File | Yang diuji |
|---|---|
| `tests/test_media.py` | URL bertanda tangan, tamper, kedaluwarsa, batas harian, purge foto yatim |
| `tests/test_ai_chat.py` | grounding harga, `photo_relevant`, kuota chat/estimate/foto, refund saat provider mati |
| `tests/test_offer_deal.py` | alur offer → bid → accept → complete, sampel harga |

## Script bantu

Semua dijalankan dari folder `BackEnd`:

| Perintah | Fungsi |
|---|---|
| `uv run python -m backend.db.setup` | Buat index, schema validator, dan seed kategori |
| `uv run python scripts/seed_price_samples.py` | Isi 2.520 sampel harga demo (idempoten) |
| `uv run python scripts/refresh_price_catalog.py` | Hitung ulang katalog dari sampel |
| `uv run python scripts/eval_ai.py` | Uji klasifikasi AI pada 12 kasus (`--provider` untuk model sungguhan, `--csv` untuk simpan hasil) |
| `uv run python scripts/purge_orphan_media.py` | Laporan foto yatim; `--apply` untuk menghapus |
| `uv run python scripts/migrate_offer_photos.py` | Migrasi foto lama berbentuk base64 ke collection `media`; `--apply` untuk menulis |

Script yang menulis data **default hanya melaporkan** (dry-run) dan butuh `--apply`.

## Masalah umum

**Server gagal start: `JWT_SECRET minimal 32 karakter`**
Isi `JWT_SECRET` dengan string acak ≥32 karakter. Lihat [langkah 3](#3-siapkan-env).

**`ServerSelectionTimeoutError`**
MongoDB tidak bisa dijangkau. Cek `MONGO_URL`, dan pastikan IP laptop sudah di-whitelist di MongoDB Atlas (Network Access).

**Chat menjawab "data harga belum cukup"**
Belum ada sampel harga untuk kategori/keparahan/kota tersebut. Jalankan `scripts/seed_price_samples.py`. Perhatian: katalog demo hanya punya Surabaya, Jakarta, Bandung — kota lain otomatis memakai data nasional.

**Chat menjawab dengan `model: "local-heuristic"`**
`AI_API_KEY` kosong. Itu normal dan gratis. Isi `AI_API_KEY` kalau ingin memakai model sungguhan.

**Foto menghasilkan `403 MEDIA_URL_INVALID`**
URL foto harus memakai `?exp=&sig=` dari response API. Membuka `/media/<id>` tanpa tanda tangan memang ditolak. URL juga kedaluwarsa setelah 1 jam — ambil ulang dari response offer/chat.

**`429 AI_RATE_LIMITED` / `AI_PHOTO_RATE_LIMITED`**
Kuota harian habis. Kuota reset tengah malam WIB, atau naikkan limit lewat `.env`.

**`flutter doctor` protes Android license / cmdline-tools**
```bash
flutter doctor --android-licenses
```
Kalau `cmdline-tools` masih hilang, pasang lewat Android Studio → SDK Manager → *Android SDK Command-line Tools*.

**`flutter doctor` protes `ninja is required` (Linux desktop)**
Pasang `ninja` dari package manager distro. Hanya perlu kalau menjalankan target Linux desktop.

**`Cannot find Chrome executable`**
```bash
export CHROME_EXECUTABLE=$(command -v chromium)
```

**Emulator Android tidak terdeteksi**
```bash
flutter emulators --launch <nama_emulator>
# atau
~/Android/Sdk/platform-tools/adb devices
```

## Status proyek

| Bagian | Kondisi |
|---|---|
| Backend — auth, offer, bid, media, katalog harga | ✅ Jalan & teruji |
| Backend — chat AI + fallback lokal | ✅ Jalan & teruji |
| Tes otomatis | ✅ 26 lulus |
| Frontend — UI halaman | ⚠️ Prototipe, data masih hardcode |
| Frontend — tersambung API | ❌ Belum ada |
| Ulasan / rating | ❌ Belum dikodekan |
| Job cron offer kedaluwarsa | ❌ Belum ada |

Langkah berikutnya yang paling berdampak: menyambungkan Flutter ke API (login → daftar tawaran → bid → chat AI), lalu membangun ulasan teknologi.
