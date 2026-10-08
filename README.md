# Compose KPR Kertas Kerja

Repositori orkestrasi Docker Compose untuk menjalankan dan meroutingkan service **KPR Kertas Kerja Analis** di VM Google Cloud Compute Engine (`gc-bribrain-dev-vai-face-01`).

Container image ditarik langsung dari **Google Cloud Artifact Registry**:
- **API**: `asia-southeast2-docker.pkg.dev/common-cicd-dev-01/gc-bribrain-dev-gar-temp-01/kpr-kertas-kerja-api:latest`
- **Nginx Reverse Proxy**: `asia-southeast2-docker.pkg.dev/common-cicd-dev-01/gc-bribrain-dev-gar-temp-01/kpr-kertas-kerja-nginx:latest`

---

## 📁 Struktur Repositori

```text
compose-kpr-kertas-kerja/
├── docker-compose.yml        # Compose Terpadu (API + Nginx dalam 1 stack)
├── docker-compose.api.yml    # Compose Terpisah: Khusus Service API
├── docker-compose.nginx.yml  # Compose Terpisah: Khusus Reverse Proxy Nginx
├── nginx/
│   └── nginx.conf            # Konfigurasi reverse proxy & routing ke API
├── .env.example              # Template variabel lingkungan & registry image
├── deploy.sh                 # Script otomatisasi deploy & gcloud auth di VM
├── .gitignore
└── README.md
```

---

## 🚀 Panduan Deploy di VM (`gc-bribrain-dev-vai-face-01`)

### 1. Clone Repositori di VM
Masuk ke VM Anda, lalu clone repositori ini:
```bash
git clone https://github.com/siabang35/compose-kpr-kertas-kerja.git
cd compose-kpr-kertas-kerja
```

### 2. Konfigurasi Autentikasi GCP Artifact Registry
Agar Docker di VM memiliki izin pull image dari Google Cloud Artifact Registry:
```bash
gcloud auth configure-docker asia-southeast2-docker.pkg.dev --quiet
```

### 3. Salin dan Lengkapi Variabel Lingkungan (`.env`)
```bash
cp .env.example .env
nano .env
```
Sesuaikan parameter berikut:
- `POSTGRES_HOST`: IP database PostgreSQL / Cloud SQL
- `POSTGRES_APP_PASSWORD`: Password database untuk user runtime `kpr_app`
- `KPR_API_KEY`: Kunci API untuk header `X-API-Key`
- `INTERNAL_API_KEY`: Kunci API internal

---

## 🛠️ Cara Menjalankan Service

Anda dapat memilih salah satu dari dua metode di bawah ini:

### Opsi 1: Unified Compose (Rekomendasi - Sekaligus Up)
Menjalankan kedua service (`kpr-kertas-kerja-api` dan `kpr-kertas-kerja-nginx`) dalam satu network terintegrasi:

```bash
# Menarik image terbaru
docker compose pull

# Menjalankan container di background
docker compose up -d
```
Atau cukup gunakan script otomatisasi:
```bash
chmod +x deploy.sh
./deploy.sh
```

---

### Opsi 2: Dua Compose Terpisah (Modular)
Jika Anda ingin mengontrol lifecycle container API dan Nginx secara terpisah:

1. **Buat network bersama:**
   ```bash
   docker network create kpr-network
   ```

2. **Jalankan Service API:**
   ```bash
   docker compose -f docker-compose.api.yml pull
   docker compose -f docker-compose.api.yml up -d
   ```

3. **Jalankan Service Nginx:**
   ```bash
   docker compose -f docker-compose.nginx.yml pull
   docker compose -f docker-compose.nginx.yml up -d
   ```

---

## 🔍 Arsitektur Routing

```
[Permintaan Masuk: Port 8000]
            │
            ▼
┌───────────────────────────────┐
│   kpr-kertas-kerja-nginx      │  Port 80 (Host Port 8000)
│   (Reverse Proxy & Security)  │
└──────────────┬────────────────┘
               │  proxy_pass http://kpr-kertas-kerja-api:8000
               ▼
┌───────────────────────────────┐
│     kpr-kertas-kerja-api      │  FastAPI Backend (Port 8000)
│     (Kalkulasi & Analisis)    │
└───────────────────────────────┘
```

- **Health Check**: Port `8000/health` diteruskan langsung ke API.
- **Initial Kertas Kerja**: Endpoint `/api/v1/kpr/initial-kertas-kerja` memiliki timeout khusus **150 detik** untuk mengakomodasi pemrosesan LLM klasifikasi mutasi.
- **Isolasi Internal**: Endpoint `/internal/` diblokir di layer Nginx dan mengembalikan `404 Not Found` berformat JSON standar BRIspot.

---

## ✅ Verifikasi & Uji Konektivitas

Setelah container running, verifikasi status dengan perintah:

```bash
# Cek status container
docker compose ps

# Tes Endpoint Health
curl -fsS http://localhost:8000/health
# Output yang diharapkan: {"status":"ok"}

# Tes Endpoint Ready
curl -fsS http://localhost:8000/ready
# Output yang diharapkan: {"status":"ready","db":"up"}

# Cek Log API
docker logs -f kpr-kertas-kerja-api

# Cek Log Nginx
docker logs -f kpr-kertas-kerja-nginx
```

---

## 🔄 Pembaruan Versi (Update / Rollout)
Bila terdapat update image baru di Artifact Registry:
```bash
docker compose pull
docker compose up -d
```