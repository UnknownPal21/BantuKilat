# BantuKilat

> **Foto kerusakan rumah → AI menebak jenis kerusakan + rentang harga wajar → teknisi di sekitar mengajukan penawaran → kamu memilih → tugas selesai.**

Aplikasi bantu-tetangga untuk kerusakan rumah kecil (kran bocor, MCB anjlok, printer error, angkat gas, dll).

## Daftar isi

1. [Masalah yang dipecahkan](#1-masalah-yang-dipecahkan)
2. [Arsitektur & alur data](#2-arsitektur-alur-data)
3. [Rancangan data MongoDB](#3-rancangan-data-mongodb)
4. [Mesin harga: kenapa AI tidak menulis rupiah](#4-kenapa-ai-tidak-menulis-rupiah)
5. [Instalasi localhost](#5-instalasi-localhost)
6. [Dokumentasi frontend](#6-dokumentasi-frontend)
7. [Referensi API](#7-referensi-api)
8. [Tes & kualitas](#8-tes-kualitas)
9. [Deploy & status proyek](#9-deploy-status-proyek)

---

## 1. Masalah yang dipecahkan

Orang awam tidak tahu dua hal saat barang di rumah rusak:

1. **Ini kerusakan apa?** kran bocor karena seal, atau karena pipa retak?
2. **Harga wajarnya berapa?** Rp 50 ribu atau Rp 500 ribu?

Akibatnya user takut ditipu, dan teknisi harus bolak-balik bertanya lewat chat.

BantuKilat memotong dua langkah itu: user cukup **foto + deskripsi singkat**, lalu langsung mendapat dugaan kerusakan dan estimasi harga yang diambil dari **data transaksi historis**, bukan angka karangan model AI.

### Alur utama

```
User                          Backend                          Teknisi
 │
 │ 1. Foto kerusakan ────────► POST /media          (foto disimpan, bukan base64)
 │
 │ 2. "Kran bocor" ──────────► POST /ai/chats/{id}/messages
 │                              ├─ AI klasifikasi kategori + keparahan
 │                              └─ harga diambil dari price_catalog
 │    ◄─── estimate + narasi + saran keselamatan
 │
 │ 3. Buat tawaran ──────────► POST /offers        ──►  GET /offers/nearby
 │                                                          │
 │                                                          │ 4. Ajukan harga
 │    ◄────────────────────────────────  POST /offers/{id}/bids
 │
 │ 5. Terima satu bid ───────► POST /bids/{id}/accept   (bid lain → REJECTED)
 │
 │ 6. Teknisi selesai ───────► POST /offers/{id}/complete
 │                              └─ harga deal masuk katalog → AI makin akurat
 │
 │ 7. Ambil pekerjaan ───────► GET /offers/tasks  (ASSIGNED / COMPLETED)
```

### Siklus status tawaran

Semua status punya jalan masuk **dan** jalan keluar. Tidak ada status yang bisa dicapai tanpa endpoint.

```
                 ┌──────────────── reject semua bid ────────────────┐
                 ▼                                                  │
  (baru) ──► WAITING ──bid masuk──► NEGOTIATING ──accept──► ASSIGNED ──complete──► COMPLETED
                │                        │
                │ cancel                 │ cancel
                ▼                        ▼
            CANCELLED ◄─────────────────┘

  WAITING / NEGOTIATING ──expires_at lewat (job)──► EXPIRED
```

| Transisi                          | Endpoint                                                    | Siapa          |
| --------------------------------- | ----------------------------------------------------------- | -------------- |
| `WAITING → NEGOTIATING`           | `POST /offers/{id}/bids`                                    | teknisi        |
| `NEGOTIATING → WAITING`           | `POST /bids/{id}/reject` (semua bid habis) atau `/withdraw` | user / teknisi |
| `NEGOTIATING → ASSIGNED`          | `POST /bids/{id}/accept`                                    | user           |
| `ASSIGNED → COMPLETED`            | `POST /offers/{id}/complete`                                | teknisi        |
| `WAITING/NEGOTIATING → CANCELLED` | `POST /offers/{id}/cancel`                                  | user           |
| `WAITING/NEGOTIATING → EXPIRED`   | job latar belakang                                          | sistem         |

---

## 2. Arsitektur & alur data

```
FrontEnd/bantukilat/        Flutter (UI), penyimpanan token (flutter_secure_storage)
        │
        │  HTTP + JWT (Authorization: Bearer …)
        ▼
BackEnd/src/backend/        FastAPI
        ├── routers/        endpoint HTTP, validasi auth/role
        ├── services/       logika bisnis (offer, bid, ai, media, harga, auth)
        ├── models/         skema Pydantic request & response
        ├── core/           config, JWT, error handler, rate limit, scheduler
        └── db/             koneksi, index, validator, seed kategori
                │
                │  driver async (AsyncMongoClient)
                ▼
        MongoDB Atlas
```

### Contoh nyata: satu request offer, dari Flutter sampai Mongo

Misal Flutter memanggil `POST /offers`.

**1. Flutter** (`lib/services/auth_service.dart`)

```dart
await http.post(Uri.parse('$_baseUrl/offers'),
  headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
  body: jsonEncode({
    'category_id': categoryId,
    'title': 'Kran wastafel bocor',
    'photos': [photoId],          // id hasil POST /media
    'lng': 112.7531, 'lat': -7.2412,
    ...
  }));
```

**2. Router** (`routers/offers.py`), `require_role` tidak dipakai karena
offer boleh dibuat akun apa pun; yang wajib hanya token valid.

```python
user: dict = Depends(get_current_user)   # dari header Bearer
```

**3. Model** (`models/offer.py` → `OfferCreateIn`) memvalidasi panjang teks,
rentang `lng/lat`, dan menolak `extra` field. Field tak dikenal langsung 422.

**4. Service** (`services/offer_service.py::create`)

- `photos` dinormalisasi: id media **atau** URL `/media/<id>` → id.
- Id diverifikasi pemiliknya (`media.owner_id == user`), kalau bukan → `422 PHOTO_NOT_FOUND`.
- Snapshot dibekukan: `requester_snapshot` (nama) dan `category_snapshot` (label, icon).
- `geo_index` diturunkan dari alamat (`city`, `district`) untuk keperluan fallback harga.
- `expires_at = now + 30 menit`, `status = "WAITING"`, `bid_count = 0`.

**5. Mongo** menulis satu dokumen ke `offers`. Validator collection ikut
memeriksa bentuk dokumen; dokumen cacat ditolak database, bukan hanya aplikasi.

**6. Response** dibentuk `_offer_response()`, ObjectId diubah `str`, waktu
diubah ISO-8601 UTC dengan akhiran `Z`, dan `photos` dikembalikan sebagai
**URL bertanda tangan** (bukan id mentah).

Contoh response asli (diambil dari server, id disingkat):

```json
{
  "_id": "6af85a87e1422422ec75f409",
  "requester_id": "6af85a86e1422422ec75f407",
  "requester_snapshot": {
    "name": "Sari",
    "avatar_url": null,
    "rt": null,
    "rw": null
  },
  "category_id": "6af85a84f27de2bc473d4081",
  "category_snapshot": { "code": "PLUMBING", "label": "Air", "icon": "🚰" },
  "title": "Kran wastafel bocor",
  "description": "Air menetes terus sejak pagi, lantai basah.",
  "photos": ["<PUBLIC_BASE_URL>/media/<id>?exp=1794664599&sig=234db4...7fdcf"],
  "location": { "type": "Point", "coordinates": [112.7531, -7.2412] },
  "address_text": "Jl. Mulyorejo Tengah No. 45",
  "geo_index": {
    "rt": null,
    "rw": null,
    "district": "Mulyorejo",
    "city": "Surabaya"
  },
  "is_sos": false,
  "sos_fee": 0,
  "initial_budget": 20000,
  "agreed_price": null,
  "status": "WAITING",
  "accepted_bid_id": null,
  "technician_id": null,
  "bid_count": 0,
  "created_at": "2026-11-14T12:56:39.265371Z",
  "updated_at": "2026-11-14T12:56:39.265371Z",
  "expires_at": "2026-11-14T13:26:39.265371Z",
  "assigned_at": null,
  "completed_at": null,
  "cancelled_at": null,
  "cancel_reason": null
}
```

`distance_m` hanya muncul di `GET /offers/nearby` (hasil `$geoNear`).

---

## 3. Rancangan data MongoDB

**Pendekatan: hybrid reference + display snapshot.**

- Relasi tetap memakai `_id` (normalized), bukan menyalin dokumen utuh.
- Field yang **ditampilkan di layar** dibekukan saat transaksi berlangsung.

Contoh: `bids.technician_snapshot.name` adalah nama teknisi **saat menawar**,
bukan nama sekarang. Ini disengaja — kalau teknisi mengganti nama besok,
penawaran kemarin tetap menampilkan nama yang dilihat user saat memutuskan.

Keuntungannya: satu layar butuh 1–2 query, bukan 6 join.

### Konvensi

| Aturan     | Nilai                                                             |
| ---------- | ----------------------------------------------------------------- |
| `_id`      | `ObjectId`                                                        |
| Waktu      | `datetime` UTC; response selalu ISO-8601 berakhiran `Z`           |
| Uang       | `int` rupiah. Tidak pernah `float`                                |
| Enum       | `UPPER_SNAKE` string                                              |
| Koordinat  | GeoJSON `{"type":"Point","coordinates":[lng, lat]}`, **lng dulu** |
| Email      | lowercase, dinormalisasi di model                                 |
| Nama field | `snake_case`                                                      |

### 10 collection

| Collection         | Isi                                                       | Volume      |
| ------------------ | --------------------------------------------------------- | ----------- |
| `users`            | Akun user & teknisi (satu koleksi, field `role`)          | kecil       |
| `categories`       | Tujuh kategori (6 aktif + `CARPENTRY` sebagai chip skill) | ~7 dokumen  |
| `offers`           | Permintaan bantuan                                        | sedang      |
| `bids`             | Penawaran teknisi                                         | sedang      |
| `media`            | Byte foto (JPEG terkompresi)                              | **besar**   |
| `ai_conversations` | Percakapan chat AI                                        | sedang      |
| `ai_messages`      | Pesan chat + hasil estimasi                               | besar       |
| `ai_usage`         | Counter kuota harian per user                             | TTL 30 hari |
| `price_samples`    | Riwayat harga (seed + deal nyata)                         | 2.520 seed  |
| `price_catalog`    | Agregat harga per kategori × keparahan × kota             | 84 baris    |

`reviews` **belum dibuat**, dirancang tapi belum dikodekan (lihat §9.3).

### Field penting `offers`

| Field                | Tipe        | Catatan                                                                   |
| -------------------- | ----------- | ------------------------------------------------------------------------- |
| `status`             | enum        | `WAITING`, `NEGOTIATING`, `ASSIGNED`, `COMPLETED`, `CANCELLED`, `EXPIRED` |
| `requester_snapshot` | objek       | nama pemohon **saat** offer dibuat                                        |
| `category_snapshot`  | objek       | `code`, `label`, `icon` saat offer dibuat                                 |
| `photos`             | array id    | id media; **diubah jadi URL** di response                                 |
| `bid_count`          | int         | **dihitung ulang** dari bid `PENDING`, bukan `$inc`                       |
| `expires_at`         | date        | 30 menit; dipakai job `EXPIRED` dan filter query                          |
| `cancel_reason`      | enum        | `SUDAH_SELESAI`, `SALAH_INPUT`, `TERLALU_LAMA`, `LAINNYA`, `KEDALUWARSA`  |
| `agreed_price`       | int \| null | harga bid yang diterima                                                   |

### Field penting `bids`

| Field                 | Catatan                                                   |
| --------------------- | --------------------------------------------------------- |
| `status`              | `PENDING`, `ACCEPTED`, `REJECTED`, `WITHDRAWN`, `EXPIRED` |
| `technician_snapshot` | `name`, `avatar_url`, `rating` **saat menawar**           |
| `amount`              | int rupiah                                                |

`technician_snapshot` sengaja **tidak** memuat `_id` teknisi. `technician_id`
sudah ada di level atas dokumen.

### Index yang benar-benar dipasang

Bukan keseluruhan plan, ini yang dibuat `db/setup.py` dan terverifikasi ada
di database:

| Collection      | Index                                                           | Kegunaan                                  |
| --------------- | --------------------------------------------------------------- | ----------------------------------------- |
| `users`         | `email` **unique**                                              | cegah akun ganda                          |
| `users`         | `phone` unique (partial, hanya string)                          | cegah nomor ganda; akun Google boleh null |
| `users`         | `google_sub` unique (partial)                                   | login Google                              |
| `bids`          | `{offer_id, technician_id}` **unique partial** `status=PENDING` | **satu bid aktif per teknisi per offer**  |
| `offers`        | `location` `2dsphere`                                           | `$geoNear` di `/nearby`                   |
| `offers`        | `{status, expires_at}` partial `WAITING/NEGOTIATING`            | job `EXPIRED`                             |
| `offers`        | `{technician_id, updated_at}`                                   | `GET /offers/tasks`                       |
| `offers`        | `{requester_id, status, created_at}`                            | `GET /offers/mine`                        |
| `offers`        | `{status, category_id, created_at}`                             | filter kategori                           |
| `media`         | `{used_at, created_at}`                                         | pembersihan foto yatim                    |
| `ai_usage`      | `{user_id, day}` **unique**                                     | kuota atomik                              |
| `ai_usage`      | `created_at` TTL 30 hari                                        | auto-bersih                               |
| `price_catalog` | `{category_code, severity, city}` **unique**                    | satu baris per kombinasi                  |

**Kenapa index unik parsial `{offer_id, technician_id}` + `status: PENDING`?**

Karena Mongo hanya menjamin keunikan pada dokumen yang cocok filter. Teknisi
boleh punya banyak bid historis (`WITHDRAWN`, `REJECTED`) untuk offer yang sama,
tapi hanya **satu** yang `PENDING`. Tanpa index ini, dua request bersamaan bisa
membuat dua bid aktif, dan harga pesaing jadi terlihat.

### Kenapa `bid_count` dihitung ulang

`sync_after_bid_change()` menjalankan `count_documents(status="PENDING")` lalu
**menulis hasilnya**, bukan `$inc: -1`. Dengan `$inc`, satu kegagalan di tengah
(proses mati, exception) membuat angka menyimpang selamanya, dan offer dengan
`bid_count > 0` padahal bid-nya habis tidak akan pernah kembali ke `WAITING`.

---

## 4. kenapa AI tidak menulis rupiah

**Prinsip inti: model AI tidak pernah menghasilkan nominal rupiah.**

Model hanya menjawab dua hal yang tidak butuh angka presisi:

1. ini kategori apa (`PLUMBING`, `ELECTRICAL`, …)
2. seberapa parah (`RINGAN`, `SEDANG`, `BERAT`)

Rupiah **selalu** disusun server dari `price_catalog`. Kalau data belum cukup,
server bilang tidak tahu, tidak asal menebak. Model bahasa memang buruk dalam
mengestimasi angka pasar lokal, dan kesalahan di sini langsung merugikan user.

### Alur estimasi

```
"Kran wastafel bocor"
        │
        ▼
  AI klasifikasi ──► {category_code: PLUMBING, severity: RINGAN}
        │                        (atau fallback kata kunci lokal)
        ▼
  price_service.estimate(PLUMBING, RINGAN, "Surabaya")
        │
        ├─ ada data kota Surabaya?  → pakai (scope: "city")
        ├─ tidak, ada data nasional? → pakai (scope: "national")
        └─ tidak ada sama sekali     → estimate: null ("belum cukup data")
        │
        ▼
  min / median / max + sample_count + confidence
```

Contoh response asli `POST /ai/estimate`:

```json
{
  "text": "Kran wastafel diduga bocor pada kartrid atau seal, sehingga air terus menetes…\n\nPerkiraan biaya di Surabaya: Rp50.000 - Rp135.000\n(median Rp75.000, dari 40 kasus serupa)\n\nYang memengaruhi: tingkat kerusakan, akses ke lokasi, dan part yang perlu diganti.",
  "estimate": {
    "category_code": "PLUMBING",
    "category_label": "Air",
    "severity": "RINGAN",
    "min": 50000,
    "median": 75000,
    "max": 135000,
    "sample_count": 40,
    "scope": "city",
    "city": "Surabaya",
    "confidence": 0.92,
    "rough": false
  },
  "model": "deepseek-flash",
  "error": null,
  "photo_relevant": null
}
```

`sample_count` sengaja dikembalikan. Angka dari 3 sampel dan angka dari 40
sampel tidak boleh tampil sama yakinkan di UI.

### Katalog belajar sendiri

```
price_samples                     price_catalog
(bukti mentah)                    (agregat siap pakai)
├─ SEED (2.520 demo)  ──────►  refresh()  ──►  84 baris
└─ DEAL (tawaran selesai) ──────────────┘
```

Setiap tawaran yang selesai dengan `agreed_price ≥ batas minimum` menambah
satu sampel `DEAL` (idempoten lewat unique index parsial `offer_id`), lalu
katalog dihitung ulang. Artinya **setiap transaksi nyata membuat estimasi
berikutnya lebih akurat** — tanpa training ulang model apa pun.

### Fallback tanpa API key

Kalau `AI_API_KEY` kosong, server memakai pengklasifikasi kata kunci lokal.
Label `model` di response menjadi `"local-heuristic"`, jujur dan bukan pura-pura
memakai model. Demo tetap jalan penuh tanpa biaya.

---

## 5. Instalasi localhost

### 5.0 Sebelum mulai baca ini dulu

Ada **dua jalur** yang bisa kamu pilih. Pilih sesuai tujuanmu:

| Jalur                              | Cocok untuk                            | Yang bisa dicoba                                    |
| ---------------------------------- | -------------------------------------- | --------------------------------------------------- |
| **A — Backend saja**               | menilai API, desain data, tes otomatis | Semua 26 operasi (24 path) lewat Swagger UI, 42 tes |
| **B — Backend + aplikasi Flutter** | melihat aplikasi utuh                  | UI Flutter asli + backend                           |

Pilihan jalur tidak mengubah cara frontend terhubung ke backend. Itu diatur oleh
**satu konstanta** di `FrontEnd/bantukilat/lib/services/auth_service.dart`
(baris 7–8):

```dart
static const String _baseUrl = '…';
```

Alamat itulah yang ditembak setiap request dari aplikasi. Selama pengembangan
proyek ini, nilainya diarahkan ke **backend yang berjalan lokal di laptop
developer**; setelah deploy, nilainya diarahkan ke **domain cloud**. Tiga
kemungkinan yang perlu kamu pahami:

| Mode                              | Backend berjalan di   | `_baseUrl`                              | Perlu tunnel? |
| --------------------------------- | --------------------- | --------------------------------------- | ------------- |
| **1. Satu laptop**                | laptop yang sama      | `http://localhost:8000` atau `http://10.0.2.2:8000` di emulator | tidak         |
| **2. Kolaborasi (yang dipakai proyek ini)** | laptop developer | domain tunnel, mis. `https://xxxx.opentunnel.xyz` | **ya**        |
| **3. Sudah deploy**               | FastAPI Cloud         | `https://bantukilat.fastapicloud.dev`   | tidak         |

**Mode 1 — satu laptop.** FE dan BE dijalankan di mesin yang sama. `localhost`
memang menunjuk ke laptop itu, jadi tidak ada perantara. Di emulator Android,
pakai `10.0.2.2` karena `localhost` di dalam emulator menunjuk ke emulator itu
sendiri, bukan ke laptop.

**Mode 2 — kolaborasi lewat tunnel** (ini yang dipakai selama pengembangan).
Backend tetap berjalan **lokal di laptop satu orang**, tetapi `localhost` tidak
bisa dipakai dari perangkat lain: `localhost` selalu berarti "mesin ini". Jadi
laptop itu membuat tunnel — sebuah domain publik yang meneruskan trafik ke
`localhost:8000` di mesin tersebut. Alurnya:

```
HP/laptop teman  →  https://xxxx.opentunnel.xyz  →  tunnel  →  localhost:8000 di laptop developer
```

Temanmu menembak domain tunnel, bukan `localhost`, tetapi yang menjawab tetap
backend lokal. Tunnel hanya jembatan; tidak ada server tambahan.

**Mode 3 — sudah deploy.** Backend berjalan di FastAPI Cloud, jadi aplikasi
langsung menunjuk domain `https://bantukilat.fastapicloud.dev` dan tidak
memerlukan laptop siapa pun tetap menyala.

> **Catatan:** alamat di `_baseUrl` **tidak bisa** diganti lewat `--dart-define`;
> harus diedit di kode. Backend juga belum punya middleware CORS, sehingga
> `flutter run -d chrome` diblokir browser — pakai emulator atau perangkat
> Android. Cara memilih alamat untuk tiap mode ada di
> [§6.8.1](#681-memilih-alamat-backend).

---

### 5.1 Requirement

| Perlu                            | Versi / catatan                                          | Cek                 |
| -------------------------------- | -------------------------------------------------------- | ------------------- |
| Python                           | **3.12+**                                                | `python3 --version` |
| [uv](https://docs.astral.sh/uv/) | pengelola paket                                          | `uv --version`      |
| MongoDB                          | Atlas (cloud) **atau** lokal, wajib mendukung `2dsphere` | —                   |
| Git                              | —                                                        | `git --version`     |
| Flutter                          | 3.47+ (hanya Jalur B)                                    | `flutter --version` |

Install `uv` kalau belum ada:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# atau
pip install uv
```

**MongoDB lokal (opsional, tanpa Atlas).** Atlas M0 gratis dan tidak perlu
instal apa pun, jadi ini hanya kalau ingin sepenuhnya offline:

```bash
docker run -d --name mongo-bantukilat -p 27017:27017 mongo:7
# lalu di .env:
# MONGO_URL=mongodb://localhost:27017  (tanpa +srv)
```

---

### 5.2 Clone

```bash
git clone https://github.com/UnknownPal21/BantuKilat.git
cd BantuKilat/BackEnd
```

---

### 5.3 Pasang dependency

```bash
uv sync
```

Perintah ini membuat `.venv` dan memasang paket **persis sesuai `uv.lock`**.
Versi tidak akan bergeser antar mesin.

Output yang diharapkan:

```
Resolved 216 packages in 0.01ms
Installed 90 packages in 1.23s
```

---

### 5.4 Buat file `.env`

```bash
cp .env.example .env
```

Lalu edit `.env`. **Minimal tiga nilai ini wajib diisi:**

```dotenv
MONGO_URL=mongodb+srv://<user>:<password>@<cluster>.mongodb.net
MONGO_DB_NAME=bantukilat
JWT_SECRET=<hasil perintah di bawah>
```

Membuat `JWT_SECRET` yang aman:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(48))"
```

> Server **menolak start** kalau `JWT_SECRET` kurang dari 32 karakter. Ini
> disengaja, secret pendek membuat token bisa dipalsukan. Kunci ini juga
> menandatangani URL foto.

**MongoDB Atlas, kalau belum punya cluster:**

1. Buat akun di <https://www.mongodb.com/cloud/atlas/register> (M0 gratis).
2. **Database Access** → _Add New Database User_ → catat username & password.
   Karakter khusus di password harus di-URL-encode (`@` → `%40`).
3. **Network Access** → _Add IP Address_ → **Allow Access from Anywhere**
   (`0.0.0.0/0`) untuk development.
4. **Connect** → _Drivers_ → salin connection string ke `MONGO_URL`.

Tanpa langkah 3, server gagal dengan `ServerSelectionTimeoutError`.

**Mengaktifkan AI sungguhan (opsional).** Tanpa ini aplikasi tetap jalan
memakai fallback kata kunci lokal:

```dotenv
AI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai
AI_MODEL=gemini-2.5-flash
AI_API_KEY=<api key kamu>
```

Provider apa pun yang bicara protokol OpenAI-compatible bisa dipakai.

### 5.5 Siapkan database

```bash
uv run python -m backend.db.setup
```

Output yang diharapkan:

```
categories: 7
users / offers / bids / media / price_* / ai_* : index terpasang
```

Perintah ini **idempoten** — jalankan berkali-kali tidak merusak apa pun. Yang
dipasang: semua index (§3), validator schema `offers`, dan 7 kategori.

> Kalau lewat, semua endpoint tetap 200 tetapi `GET /offers/nearby` gagal karena
> index `2dsphere` tidak ada.

---

### 5.6 (Opsional) Isi data harga demo

```bash
uv run python scripts/seed_price_samples.py
```

Output:

```
hapus sampel SEED lama: 0
insert 2520 sampel, tulis 84 baris katalog
ringkasan: {'samples': 2520, 'catalog_rows': 84, 'seed_samples': 2520, 'deal_samples': 0}
```

Tanpa langkah ini chat AI masih jalan, tetapi menjawab _"Belum ada cukup data
harga untuk kasus seperti ini"_ — karena katalog memang kosong.

Data demo hanya untuk **Surabaya, Jakarta, Bandung**. Kota lain otomatis memakai
data nasional (`scope: "national"`).

Menghapus data demo (data user/offer tidak tersentuh):

```bash
uv run python - <<'PY'
import asyncio
from backend.db.mongo import db
asyncio.run(db.price_samples.delete_many({"source": "SEED"}))
PY
uv run python scripts/refresh_price_catalog.py
```

---

### 5.7 Jalankan server

```bash
uv run fastapi dev src/backend/main.py
```

Output yang diharapkan:

```
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
INFO:     Application startup complete.
```

Buka:

| URL                            | Isi                                               |
| ------------------------------ | ------------------------------------------------- |
| <http://127.0.0.1:8000/docs>   | **Swagger UI** — coba semua endpoint dari browser |
| <http://127.0.0.1:8000/redoc>  | Dokumentasi read-only                             |
| <http://127.0.0.1:8000/health> | `{"status":"ok"}`                                 |

Verifikasi dari terminal:

```bash
curl http://127.0.0.1:8000/health
# {"status":"ok"}

curl http://127.0.0.1:8000/categories | head -c 200
# [{"_id":"...","code":"ELECTRICAL","label":"Kelistrikan",...}]
```

Untuk mode production-like (tanpa auto-reload):

```bash
uv run fastapi run src/backend/main.py
```

---

### 5.8 Uji alur lengkap dari terminal

Salin tempel berurutan. Butuh `jq` (`sudo apt install jq`).

```bash
BASE=http://127.0.0.1:8000

# 1) Daftar sebagai USER
TOKEN=$(curl -s -X POST $BASE/auth/register \
  -H "Content-Type: application/json" \
  -d '{"role":"USER","name":"Sari","email":"sari@example.com",
       "phone":"+6281234567890","password":"rahasia123",
       "city":"Surabaya","district":"Mulyorejo"}' | jq -r .access_token)

echo "token: ${TOKEN:0:20}..."

# 2) Profil sendiri
curl -s $BASE/auth/me -H "Authorization: Bearer $TOKEN" | jq
```

Output yang diharapkan pada langkah 2:

```json
{
  "_id": "6af85a445e6acca1d4d59749",
  "role": "USER",
  "name": "Sari",
  "email": "sari@example.com",
  "phone": "+6281234567890",
  "avatar_url": null
}
```

Lanjutkan: upload foto → buat offer → teknisi menawar → accept → complete.
Perintah lengkapnya ada di [§7.4 Alur lengkap](#74-alur-lengkap-curl).

---

## 6. Dokumentasi frontend

Aplikasi klien ada di `FrontEnd/bantukilat/`, **Flutter** (Dart), satu basis kode
untuk Android, iOS, dan web. Bagian ini menjelaskan apa yang benar-benar ada di
kode, termasuk batasannya.

### 6.1 Framework & dependency

| Hal                  | Nilai                                                    |
| -------------------- | -------------------------------------------------------- |
| Framework            | Flutter (Material 3), Dart SDK `^3.13.7`                 |
| Versi aplikasi       | `0.1.0+1`                                                |
| State management     | **tanpa paket** — `StatefulWidget` + `setState`          |
| Lapisan data         | satu kelas statis `AuthService`, langsung `package:http` |
| Penyimpanan sesi     | `flutter_secure_storage` (token JWT + profil)            |
| Build target Android | `compileSdk 36`, `applicationId com.example.bantukilat`  |
| Tes otomatis         | **belum ada** — folder `test/` kosong                    |

Dependency (`pubspec.yaml`):

| Paket                    | Versi   | Dipakai untuk                                      |
| ------------------------ | ------- | -------------------------------------------------- |
| `http`                   | ^1.1.0  | semua panggilan REST ke backend                    |
| `flutter_secure_storage` | 11.2.0  | simpan `access_token` & `user_profile`             |
| `image_picker`           | ^1.2.4  | ambil foto dari kamera/galeri                      |
| `flutter_image_compress` | ^2.4.0  | perkecil foto sebelum base64                       |
| `flutter_map`            | ^8.3.2  | peta OpenStreetMap (tile `tile.openstreetmap.org`) |
| `geolocator`             | ^14.1.2 | koordinat user untuk `GET /offers/nearby`          |
| `geocoding`              | ^5.0.1  | koordinat → teks alamat                            |
| `flutter_svg`            | ^2.4.0  | render `assets/logo/logo.svg`                      |

Catatan: `geocoding` dipakai lebih tipis, pencarian alamat
manual memakai **Nominatim** (OpenStreetMap) lewat `http`, lihat `DetailTawaran.dart`,
`HomePageTeknisi.dart`, dan `TawaranSaya.dart`.

### 6.2 Struktur folder

```
FrontEnd/bantukilat/
├── pubspec.yaml                 dependency + daftar aset
├── lib/
│   ├── main.dart                MaterialApp + cek sesi saat start
│   ├── services/
│   │   └── auth_service.dart    SEMUA panggilan API + token (417 baris)
│   └── page/
│       ├── splash_screen.dart   layar transisi
│       ├── loginpage.dart       masuk + tautan daftar
│       ├── registerpage.dart    daftar sebagai USER
│       ├── forgotpassword.dart  halaman lupa kata sandi
│       ├── SideBar.dart         drawer navigasi bersama
│       ├── DetailTawaran.dart   detail tawaran + peta + bid (1499 baris)
│       ├── user/
│       │   ├── HomePageUser.dart     beranda user
│       │   ├── TawaranSaya.dart      buat tawaran + kamera (2041 baris)
│       │   └── ListMyTawaran.dart    daftar tawaran saya + terima bid
│       └── teknisi/
│           ├── HomePageTeknisi.dart  beranda teknisi + peta
│           ├── ListTawaranPage.dart  tawaran di sekitar
│           ├── TugasSaya.dart        tugas yang diambil
│           └── RegisterTeknisi.dart  daftar sebagai teknisi
└── assets/
    ├── logo/   LogoBulat.png, logo.svg, logo.webp
    └── images/ dummy.png (placeholder)
```

Tidak ada folder `models/`, `widgets/`,
atau `providers/`, model data diperlakukan sebagai `Map<String, dynamic>` yang
dikembalikan `AuthService`, dan widget kecil ditulis inline di file halaman.

### 6.3 Alur navigasi

`main.dart` memanggil `AuthService.validateSession()` **sebelum** layar pertama
muncul, lalu memilih rute berdasarkan role:

```
main() → validateSession()
   ├─ token tidak ada / kedaluwarsa ──► SplashScreen → LoginPage
   └─ role TECHNICIAN ────────────────► SplashScreen → HomePageTeknisi
      role USER ──────────────────────► SplashScreen → HomePageUser
```

Dari `LoginPage`: `RegisterPage` (daftar user), `RegisterTeknisi` (daftar
teknisi), `ForgotPasswordPage`. Setelah login sukses, `Navigate.pushAndRemoveUntil`
membuang tumpukan lama supaya tombol _back_ tidak kembali ke halaman login.

### 6.4 Peta layar → endpoint

Setiap layar memanggil `AuthService`, yang menerjemahkannya ke REST backend.
Tabel ini memudahkan menelusuri "layar ini butuh API apa".

| Layar                          | Metode `AuthService` yang dipakai                                              |
| ------------------------------ | ------------------------------------------------------------------------------ |
| `splash_screen.dart`           | `validateSession`                                                              |
| `loginpage.dart`               | `login`                                                                        |
| `registerpage.dart`            | `register` (role `USER`)                                                       |
| `teknisi/RegisterTeknisi.dart` | `register` (role `TECHNICIAN` + `skills`)                                      |
| `user/HomePageUser.dart`       | `getCurrentUser`, `logout`                                                     |
| `user/TawaranSaya.dart`        | `getCategories`, `uploadMedia`, `createOffer`                                  |
| `user/ListMyTawaran.dart`      | `getMyOffers`, `getMediaUrl`, `getOfferBidsByStatus`, `acceptBid`, `rejectBid` |
| `teknisi/HomePageTeknisi.dart` | `getNearbyOffers`, `getOffer`, `getMediaUrl`, `getCurrentUser`, `logout`       |
| `teknisi/ListTawaranPage.dart` | `getNearbyOffers`, `getMediaUrl`                                               |
| `teknisi/TugasSaya.dart`       | `getMyTasks`, `getMediaUrl`, `completeOffer`                                   |
| `DetailTawaran.dart`           | `getOffer`, `getCurrentUser`, `getToken`, `placeBid`, `acceptBid`              |

### 6.5 Cara kerja sesi & token

- `AuthService` adalah kelas dengan **semua anggota statis**; tidak ada instance.
- `login`/`register` menyimpan `access_token` dan `user_profile` (JSON) ke
  `flutter_secure_storage`. Token backend berumur **7 hari** (`expires_in: 604800`).
- Setiap request berautentikasi memakai `_authorizedRequest()`, yang membaca token
  lalu menambahkan header `Authorization: Bearer …`.
- `logout` menghapus kedua kunci dan memaksa kembali ke halaman login.
- `validateSession` memanggil `GET /auth/me`. Jika 401, sesi dianggap mati.

### 6.6 Alur foto (paling sering salah paham)

```
image_picker → flutter_image_compress → base64 (data URI)
        │
        ▼
POST /media   { data: "data:image/png;base64,…", kind: "offers" }
        │                 ← butuh header Authorization
        ▼
{ id, url, width, height, size }        url = PUBLIC_BASE_URL + tanda tangan
        │
        ▼
POST /offers  { photos: ["<id>"] }      kirim ID, bukan data URI
```

Dua hal yang menggagalkan alur ini kalau salah:

1. **Kirim `id`, bukan `url`.** `OfferCreateIn` menolak string yang dimulai
   `data:` atau lebih panjang dari 300 karakter (`models/offer.py`). URL bertanda
   tangan panjangnya bisa melewati batas itu, jadi pakai `response['id']`.
2. **`getMediaUrl(fileId)` di Flutter salah kaprah.** Backend tidak punya endpoint
   `GET /media/<id>/url`; fungsi ini akan selalu gagal. URL foto sebenarnya sudah
   ikut di setiap response: `OfferOut.photos` berisi URL bertanda tangan yang
   dibuat ulang oleh server di setiap request.

### 6.7 Aset

| Path                        | Dipakai di                      |
| --------------------------- | ------------------------------- |
| `assets/logo/logo.svg`      | logo utama (via `flutter_svg`)  |
| `assets/logo/LogoBulat.png` | ikon bulat / splash             |
| `assets/logo/logo.webp`     | cadangan ukuran ringan          |
| `assets/images/dummy.png`   | placeholder saat foto belum ada |

Kedua folder didaftarkan di `pubspec.yaml`. **Menambah aset wajib** memperbarui
daftar `assets:` di file itu, kalau tidak aplikasi gagal memuatnya saat runtime.

### 6.8 Menjalankan frontend

Prasyarat: `Flutter 3.47+` dan backend yang bisa dijangkau (lihat [§5](#5-instalasi-localhost)).

**Yang ditembak aplikasi** ditentukan satu konstanta `_baseUrl` di
`lib/services/auth_service.dart`. Nilainya berbeda per mode kerja — ringkasnya
lihat [§5.0](#50-sebelum-mulai-baca-ini-dulu), alamat lengkapnya di
[§6.8.1](#681-memilih-alamat-backend). Saat ini nilainya adalah domain cloud:

```
https://bantukilat.fastapicloud.dev
```

Artinya `flutter run` langsung bicara dengan server produksi — data yang kamu
buat dari aplikasi masuk ke database sungguhan, bukan salinan lokal.

```bash
cd FrontEnd/bantukilat

# 1) Ambil dependency
flutter pub get

# 2) Cek perangkat yang tersedia
flutter devices

# 3) Jalankan
flutter run            # pilih perangkat dari daftar
flutter run -d chrome  # khusus web, lihat peringatan di bawah
```

Keterbatasan yang harus kamu tahu sebelum menjalankannya:

| Masalah                           | Akibat                                                                              | Status             |
| --------------------------------- | ----------------------------------------------------------------------------------- | ------------------ |
| Base URL **di-hardcode**          | harus diedit di kode; tidak bisa diganti saat build lewat `--dart-define`            | lihat §6.8.1       |
| Backend **tanpa middleware CORS** | `flutter run -d chrome` diblokir browser                                             | belum ditambahkan  |
| Tanpa `usesCleartextTraffic`      | Android menolak `http://` polos; alamat `https://` (tunnel/cloud) aman               | belum diatur       |
| `rating` di model teknisi         | selalu `null` — fitur ulasan belum ada di backend                                    | menunggu fitur     |

### 6.8.1 Memilih alamat backend

Alamat backend **tidak bisa** diubah lewat `--dart-define`. Caranya mengedit satu
konstanta di `lib/services/auth_service.dart` (baris 7–8), lalu jalankan ulang
aplikasi:

```dart
static const String _baseUrl =
    'https://bantukilat.fastapicloud.dev';
```

Pilih nilai sesuai mode (lihat [§5.0](#50-sebelum-mulai-baca-ini-dulu)):

| Mode                                  | Nilai `_baseUrl`                     | Catatan                                              |
| ------------------------------------- | ------------------------------------ | ---------------------------------------------------- |
| **Satu laptop** — emulator Android    | `http://10.0.2.2:8000`               | `localhost` di emulator menunjuk emulator itu sendiri |
| **Satu laptop** — perangkat lain      | `http://<IP-LAN-laptop>:8000`        | mis. `http://192.168.1.10:8000`, satu jaringan Wi-Fi  |
| **Kolaborasi** — lewat tunnel         | `https://<domain-tunnel>`            | domain diteruskan ke `localhost:8000` di laptop developer |
| **Sudah deploy**                      | `https://bantukilat.fastapicloud.dev` | tidak butuh laptop siapa pun tetap menyala           |

Dua hal yang mudah terlewat saat memakai backend lokal:

1. **`PUBLIC_BASE_URL` harus sepasang.** Di `BackEnd/.env`, set nilainya sama
   dengan alamat yang dipakai aplikasi (termasuk domain tunnel). Kalau tidak,
   URL foto di response menunjuk ke host yang salah dan gambar gagal dimuat
   (lihat [§9.1](#91-konfigurasi-lengkap)).
2. **Tunnel harus menyala.** Domain tunnel hanya bekerja selama proses tunnel
   dan backend di laptop developer sama-sama berjalan. Kalau laptop tidur atau
   tunnel ditutup, semua request dari aplikasi gagal.

Untuk mode kolaborasi, alur lengkapnya:

```bash
# di laptop developer (backend lokal)
cd BackEnd
uv run fastapi dev src/backend/main.py        # http://127.0.0.1:8000

# terminal lain, buka tunnel ke port yang sama
<perintah-tunnel> --port 8000                 # menghasilkan https://xxxx.opentunnel.xyz

# set agar URL foto memakai domain tunnel
# BackEnd/.env
PUBLIC_BASE_URL=https://xxxx.opentunnel.xyz

# di mesin teman, arahkan aplikasi ke domain tunnel
# FrontEnd/bantukilat/lib/services/auth_service.dart
static const String _baseUrl = 'https://xxxx.opentunnel.xyz';
```

Setelah backend di-deploy, cukup ganti `_baseUrl` ke domain cloud — tunnel tidak
lagi diperlukan.

Base URL lokal: `http://127.0.0.1:8000`. Semua endpoint kecuali yang ditandai
`–` butuh header:

```
Authorization: Bearer <access_token>
```

## 7. Referensi API

### 7.1 Bentuk error

Semua error — validasi, auth, maupun bisnis — memakai bentuk yang sama:

```json
{ "code": "INVALID_CREDENTIALS", "message": "Email atau password salah" }
```

Bukan `{"detail": ...}` bawaan FastAPI. Kode mesin ada di `code`; teks manusia
di `message`.

| Kode                                      | HTTP | Arti                                                     |
| ----------------------------------------- | ---- | -------------------------------------------------------- |
| `UNAUTHORIZED`                            | 401  | Token hilang/rusak/kedaluwarsa                           |
| `INVALID_CREDENTIALS`                     | 401  | Email atau password salah                                |
| `FORBIDDEN`                               | 403  | Role tidak cocok (mis. user biasa buka endpoint teknisi) |
| `NOT_OFFER_OWNER`                         | 403  | Bukan pembuat tawaran                                    |
| `NOT_BID_OWNER`                           | 403  | Bukan pemilik penawaran                                  |
| `MEDIA_URL_INVALID` / `MEDIA_URL_EXPIRED` | 403  | URL foto rusak / kedaluwarsa                             |
| `EMAIL_TAKEN`                             | 409  | Email sudah terdaftar                                    |
| `PHONE_TAKEN`                             | 409  | Nomor WA sudah terdaftar                                 |
| `OFFER_EXPIRED`                           | 409  | Tawaran sudah lewat `expires_at`                         |
| `OFFER_NOT_OPEN`                          | 409  | Tawaran sudah tidak menerima penawaran                   |
| `OFFER_ALREADY_ASSIGNED`                  | 409  | Sudah ada teknisi; tidak bisa dibatalkan/diambil         |
| `OFFER_ALREADY_COMPLETED`                 | 409  | Sudah diselesaikan                                       |
| `BID_ALREADY_ACCEPTED`                    | 409  | Bid sudah diterima; tidak bisa ditarik                   |
| `BID_NOT_PENDING`                         | 409  | Bid sudah tidak aktif                                    |
| `PHOTO_NOT_UPLOADED`                      | 422  | Data URI dikirim langsung; upload ke `/media` dulu       |
| `PHOTO_NOT_FOUND`                         | 422  | Id foto bukan milik akun ini                             |
| `AI_RATE_LIMITED`                         | 429  | Kuota chat/estimasi harian habis                         |
| `AI_PHOTO_RATE_LIMITED`                   | 429  | Kuota pesan berfoto harian habis                         |

### 7.2 Ringkasan 26 endpoint (24 path)

| Method  | Path                      | Auth         | Keterangan                             |
| ------- | ------------------------- | ------------ | -------------------------------------- |
| `GET`   | `/health`                 | –            | Cek server hidup                       |
| `POST`  | `/auth/register`          | –            | Daftar, langsung dapat token           |
| `POST`  | `/auth/login`             | –            | Login                                  |
| `GET`   | `/auth/me`                | ✔            | Profil sendiri                         |
| `PATCH` | `/auth/me/phone`          | ✔            | Ubah nomor HP                          |
| `GET`   | `/categories`             | –            | Daftar kategori aktif                  |
| `POST`  | `/media`                  | ✔            | Upload satu foto (base64)              |
| `GET`   | `/media/{id}`             | tanda tangan | Ambil foto (`?exp=&sig=`)              |
| `POST`  | `/offers`                 | ✔            | Buat tawaran                           |
| `GET`   | `/offers/nearby`          | ✔            | Tawaran dalam radius (`$geoNear`)      |
| `GET`   | `/offers/mine`            | ✔            | Tawaran milik sendiri                  |
| `GET`   | `/offers/tasks`           | ✔ teknisi    | Tugas teknisi (`ASSIGNED`/`COMPLETED`) |
| `GET`   | `/offers/{id}`            | ✔            | Detail tawaran                         |
| `GET`   | `/offers/{id}/bids`       | ✔            | Daftar penawaran                       |
| `POST`  | `/offers/{id}/bids`       | ✔ teknisi    | Ajukan penawaran                       |
| `POST`  | `/offers/{id}/cancel`     | ✔ pemilik    | Batalkan tawaran                       |
| `POST`  | `/offers/{id}/complete`   | ✔ teknisi    | Tandai selesai                         |
| `POST`  | `/bids/{id}/accept`       | ✔ pemilik    | Terima penawaran                       |
| `POST`  | `/bids/{id}/reject`       | ✔ pemilik    | Tolak satu penawaran                   |
| `POST`  | `/bids/{id}/withdraw`     | ✔ teknisi    | Tarik penawaran sendiri                |
| `POST`  | `/ai/estimate`            | ✔            | Estimasi tanpa menyimpan chat          |
| `POST`  | `/ai/chats`               | ✔            | Buat percakapan                        |
| `GET`   | `/ai/chats`               | ✔            | Daftar percakapan                      |
| `GET`   | `/ai/chats/{id}`          | ✔            | Isi percakapan                         |
| `POST`  | `/ai/chats/{id}/messages` | ✔            | Kirim pesan                            |
| `POST`  | `/ai/chats/{id}/close`    | ✔            | Tutup percakapan                       |

### 7.3 Detail endpoint penting

**`GET /offers/tasks`** — dibuat khusus karena `/nearby` hanya berisi offer
terbuka. Tanpa endpoint ini, pekerjaan yang sudah diterima teknisi tidak pernah
bisa ditampilkan.

```bash
curl "$BASE/offers/tasks?status=ASSIGNED" -H "Authorization: Bearer $TECH"
```

Query: `status` (opsional), `limit` (1–100, default 50). Urutan `updated_at` menurun.

**`POST /offers/{id}/cancel`** — body opsional:

```bash
curl -X POST "$BASE/offers/$OFFER_ID/cancel" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"reason":"SALAH_INPUT","note":"Salah alamat"}'
```

- Hanya pemilik, hanya selama `WAITING`/`NEGOTIATING`.
- Semua bid `PENDING` di dalamnya ikut menjadi `WITHDRAWN`.
- Menekan dua kali tetap **200** (idempoten).

**`POST /bids/{id}/withdraw`** — teknisi menarik penawaran. Kalau bid `PENDING`
terakhir hilang, offer otomatis kembali ke `WAITING` sehingga teknisi lain bisa
menawar lagi.

### 7.4 Alur lengkap (curl)

```bash
BASE=http://127.0.0.1:8000

# --- USER: daftar & siapkan tawaran ---
TOKEN=$(curl -s -X POST $BASE/auth/register -H "Content-Type: application/json" \
  -d '{"role":"USER","name":"Sari","email":"sari@example.com","phone":"+6281234567890",
       "password":"rahasia123","city":"Surabaya","district":"Mulyorejo"}' | jq -r .access_token)

CAT=$(curl -s $BASE/categories | jq -r '.[] | select(.code=="PLUMBING") | ._id')

PHOTO_ID=$(base64 -w0 foto-kran.jpg | sed 's|^|data:image/jpeg;base64,|' \
  | jq -R '{data: ., kind: "offers"}' \
  | curl -s -X POST $BASE/media -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" -d @- | jq -r .id)

OFFER_ID=$(curl -s -X POST $BASE/offers -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d "{
    \"category_id\": \"$CAT\",
    \"title\": \"Kran wastafel bocor\",
    \"description\": \"Air menetes terus sejak pagi, lantai basah.\",
    \"photos\": [\"$PHOTO_ID\"],
    \"lng\": 112.7531, \"lat\": -7.2412,
    \"address_text\": \"Jl. Mulyorejo Tengah No. 45\",
    \"initial_budget\": 20000 }" | jq -r ._id)

# --- TEKNISI: daftar, lihat sekitar, menawar ---
TECH=$(curl -s -X POST $BASE/auth/register -H "Content-Type: application/json" \
  -d '{"role":"TECHNICIAN","name":"Sultan","email":"sultan@example.com",
       "phone":"+6281298765432","password":"rahasia123",
       "city":"Surabaya","district":"Mulyorejo",
       "skills":["PLUMBING"],"terms_accepted":true}' | jq -r .access_token)

curl -s "$BASE/offers/nearby?lat=-7.2412&lng=112.7531&radius=5000" \
  -H "Authorization: Bearer $TECH" | jq '.[].title'

BID_ID=$(curl -s -X POST $BASE/offers/$OFFER_ID/bids \
  -H "Authorization: Bearer $TECH" -H "Content-Type: application/json" \
  -d '{"amount":35000,"message":"Bisa saya kerjakan sore ini"}' | jq -r ._id)

# --- USER: terima ---
curl -s -X POST $BASE/bids/$BID_ID/accept -H "Authorization: Bearer $TOKEN" | jq .status
# "ASSIGNED"

# --- TEKNISI: tugas & selesai ---
curl -s $BASE/offers/tasks -H "Authorization: Bearer $TECH" | jq '.[].status'
# "ASSIGNED"

curl -s -X POST $BASE/offers/$OFFER_ID/complete -H "Authorization: Bearer $TECH" | jq .status
# "COMPLETED"

# --- USER: chat AI dengan foto ---
CHAT_ID=$(curl -s -X POST $BASE/ai/chats -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{}' | jq -r ._id)

curl -s -X POST "$BASE/ai/chats/$CHAT_ID/messages" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"text\":\"Kran wastafel bocor, air menetes terus\",\"photos\":[\"$PHOTO_ID\"]}" \
  | jq '.estimate'
```

### 7.5 Aturan yang mungkin tidak terduga

| Aturan                                                          | Alasan                                                                         |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `photos` saat buat offer menerima **id** atau URL `/media/<id>` | keduanya dinormalisasi; data URI mentah ditolak                                |
| Teknisi **tidak bisa** melihat harga bid teknisi lain           | kalau bisa, cukup tawar 1 rupiah lebih murah                                   |
| Satu teknisi hanya punya **satu bid `PENDING`** per offer       | menawar ulang mengubah nominal bid yang sama                                   |
| Accept bersifat atomik                                          | bid lain otomatis `REJECTED`; dua accept bersamaan tidak bisa sama-sama menang |
| `GET /offers/{id}` boleh dibaca siapa pun yang login            | offer memuat foto & lokasi, jadi wajib token                                   |
| URL foto **kedaluwarsa 1 jam**                                  | id yang bocor lewat log/riwayat tidak cukup membuka foto                       |
| `GET /media/{id}` tanpa `?exp=&sig=` ditolak `403`              | sengaja, bukan bug                                                             |

---

## 8. Tes & kualitas

### 8.1 Suite backend

```bash
cd BackEnd
uv run pytest -q
```

**42 tes** di 5 file, ±60 detik (backend memakai MongoDB sungguhan, bukan mock):

| File                            | Tes | Cakupan                                                           |
| ------------------------------- | --- | ----------------------------------------------------------------- |
| `tests/test_media.py`           | 12  | unggah foto, validasi MIME, tanda tangan URL, kedaluwarsa         |
| `tests/test_ai_chat.py`         | 13  | estimasi AI, kuota harian, fallback tanpa API key                 |
| `tests/test_offer_lifecycle.py` | 12  | cancel, reject, withdraw, job `EXPIRED`, hitung ulang `bid_count` |
| `tests/test_offer_tasks.py`     | 4   | `GET /offers/tasks` untuk pekerjaan teknisi                       |
| `tests/test_offer_deal.py`      | 1   | alur offer → bid → accept → complete                              |

Tes butuh `MONGO_URL` yang bisa ditulisi (lihat [§5.5](#55-siapkan-database)).
Tanpa `AI_API_KEY`, tes AI tetap lulus karena jalur fallback yang diuji.

### 8.2 Status tes frontend

Belum ada tes otomatis: folder `FrontEnd/bantukilat/test/` tidak ada. Verifikasi
UI masih manual lewat `flutter run`. Ini batasan yang disadari, bukan kelalaian
yang tersembunyi.

### 8.3 Pemeriksaan cepat

```bash
# jumlah operasi API yang terekspos
cd BackEnd && uv run python -c "from backend.main import app; s=app.openapi(); print(len(s['paths']), sum(len(v) for v in s['paths'].values()))"
# 24 26
```

---

## 9. Deploy & status proyek

### 9.1 Konfigurasi lengkap

Semua dibaca dari `BackEnd/.env`. Nilai di bawah adalah default kalau kosong.

| Variabel                       | Default                 | Fungsi                                  |
| ------------------------------ | ----------------------- | --------------------------------------- |
| `MONGO_URL`                    | — **(wajib)**           | Connection string MongoDB               |
| `MONGO_DB_NAME`                | — **(wajib)**           | Nama database                           |
| `JWT_SECRET`                   | — **(wajib, ≥32)**      | Kunci JWT **dan** tanda tangan URL foto |
| `JWT_EXPIRE_MINUTES`           | `1440`                  | Umur token                              |
| `SERVER_SELECTION_TIMEOUT_MS`  | `5000`                  | Batas tunggu koneksi Mongo              |
| `PUBLIC_BASE_URL`              | `http://localhost:8000` | Basis URL foto di response              |
| `SETUP_ON_STARTUP`             | `true`                  | Pasang index + seed saat startup        |
| `EXPIRE_JOB_ENABLED`           | `true`                  | Aktifkan job offer kedaluwarsa          |
| `EXPIRE_CHECK_SECONDS`         | `60`                    | Interval job (minimum 5)                |
| `MEDIA_MAX_BYTES`              | `6000000`               | Batas ukuran foto                       |
| `MEDIA_URL_TTL_SECONDS`        | `3600`                  | Umur URL bertanda tangan                |
| `MEDIA_DAILY_VIEW_LIMIT`       | `600`                   | Batas buka foto per hari                |
| `MEDIA_DAILY_UPLOAD_LIMIT`     | `60`                    | Batas upload per akun per hari          |
| `AI_BASE_URL`                  | endpoint Gemini         | Provider OpenAI-compatible              |
| `AI_MODEL`                     | `gemini-2.5-flash`      | Nama model                              |
| `AI_API_KEY`                   | kosong                  | Kosong = fallback lokal gratis          |
| `AI_ALLOW_LOCAL_FALLBACK`      | `true`                  | Izinkan fallback saat key kosong        |
| `AI_TIMEOUT_SECONDS`           | `30`                    | Timeout panggilan provider              |
| `AI_HISTORY_MESSAGES`          | `10`                    | Pesan lama yang dikirim sebagai konteks |
| `AI_DAILY_MESSAGE_LIMIT`       | `20`                    | Kuota chat per hari                     |
| `AI_DAILY_ESTIMATE_LIMIT`      | `40`                    | Kuota `/ai/estimate` per hari           |
| `AI_DAILY_PHOTO_MESSAGE_LIMIT` | `10`                    | Kuota pesan berfoto per hari            |
| `AI_QUOTA_UTC_OFFSET_HOURS`    | `7`                     | Kuota reset tengah malam WIB            |

> `BackEnd/.env` masuk `.gitignore`. Jangan pernah commit file itu.

### 9.2 Deploy ke FastAPI Cloud

Aplikasi ini sudah disiapkan untuk FastAPI Cloud. Yang perlu diketahui:

| Hal                               | Nilai                                                 |
| --------------------------------- | ----------------------------------------------------- |
| Application Directory             | **`BackEnd`** (bukan root repo)                       |
| Entrypoint                        | `backend.main:app` (sudah di `pyproject.toml`)        |
| Build                             | `uv build` — terverifikasi menghasilkan wheel lengkap |
| `Dockerfile` / `requirements.txt` | **tidak perlu**, dan jangan ditambahkan               |

```bash
cd BackEnd
uv build                        # harus sukses
uv run pytest -q                # harus 42 passed
git push
fastapi deploy
```

**Tiga hal yang wajib benar setelah deploy:**

1. **`PUBLIC_BASE_URL` = domain cloud.** Kalau dibiarkan `localhost`, API tetap
   membalas 200 tetapi semua foto di aplikasi gagal dimuat.
2. **`SETUP_ON_STARTUP=true`.** FastAPI Cloud tidak punya hook pre-start, jadi
   index dan kategori dipasang di `lifespan`. Aman dijalankan banyak instance
   karena semua operasi idempoten; kegagalannya hanya dicatat di log dan tidak
   mematikan server.
3. **IP allowlist Atlas** harus mengizinkan koneksi dari FastAPI Cloud.

Verifikasi:

```bash
BASE=https://namaproyek.fastapicloud.dev
curl -s $BASE/health          # {"status":"ok"}
curl -s $BASE/categories      # daftar kategori ter-seed
```

### 9.3 Status proyek

| Bagian                                                      | Kondisi                                          |
| ----------------------------------------------------------- | ------------------------------------------------ |
| Auth (register, login, JWT, profil)                         | ✅ Jalan & teruji                                |
| Media (upload, kompresi, URL bertanda tangan, batas harian) | ✅ Jalan & teruji                                |
| Tawaran (create, nearby, mine, detail, cancel, expire)      | ✅ Jalan & teruji                                |
| Penawaran (bid, accept, reject, withdraw, tasks)            | ✅ Jalan & teruji                                |
| Chat AI + katalog harga historis                            | ✅ Jalan & teruji                                |
| Tes otomatis                                                | ✅ 42 lulus                                      |
| Frontend — UI & tersambung API                              | ✅ Tersambung (12 halaman memakai `AuthService`) |
| Frontend — cara menghubungkan ke backend                    | ✅ 3 mode terdokumentasi (§5.0): satu laptop, tunnel, cloud |
| Frontend — konfigurasi base URL & CORS                      | ⚠️ `_baseUrl` diedit di kode; belum `--dart-define`, tanpa CORS |
| Ulasan / rating teknisi                                     | ❌ Dirancang, belum dikodekan                    |
| Notifikasi / push                                           | ❌ Belum ada                                     |
| Pembatalan setelah `ASSIGNED`                               | ❌ Belum ada alurnya                             |

---

## Lisensi & atribusi

 Kami Member | 2026

Stack: [FastAPI](https://fastapi.tiangolo.com/) · [MongoDB](https://www.mongodb.com/) ·
[Flutter](https://flutter.dev/) · [uv](https://docs.astral.sh/uv/)
