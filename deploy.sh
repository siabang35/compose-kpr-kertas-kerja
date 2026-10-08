#!/usr/bin/env bash
# ==============================================================================
# Deployment Script untuk VM gc-bribrain-dev-vai-face-01
# Menjalankan autentikasi Artifact Registry & Docker Compose
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f .env ]; then
    echo "(!) File .env belum ditemukan. Menyalin dari .env.example..."
    cp .env.example .env
    echo "(!) Harap periksa dan lengkapi konfigurasi di .env sebelum melanjutkan."
fi

echo "==> 1. Konfigurasi kredensial Docker untuk Google Artifact Registry..."
gcloud auth configure-docker asia-southeast2-docker.pkg.dev --quiet

echo "==> 2. Memastikan network docker (kpr-network) tersedia..."
docker network create kpr-network 2>/dev/null || true

echo "==> 3. Menarik (pull) image terbaru dari Artifact Registry..."
docker compose pull

echo "==> 4. Menjalankan container dengan Docker Compose..."
docker compose up -d --remove-orphans

echo "==> 5. Status container yang berjalan:"
docker compose ps

echo "==> 6. Uji konektivitas health check..."
sleep 3
if curl -fsS http://localhost:8000/health >/dev/null 2>&1; then
    echo "[OK] Service KPR Kertas Kerja sehat dan dapat diakses di http://localhost:8000/health"
else
    echo "[INFO] Container baru saja start. Silakan jalankan 'curl http://localhost:8000/health' beberapa saat lagi."
fi