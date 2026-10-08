#!/usr/bin/env bash
# ==============================================================================
# Setup .env dengan auto-generate secrets
# Jalankan di VM: chmod +x setup_env.sh && ./setup_env.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

# ── 1. Salin .env.example → .env jika belum ada ─────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
    if [ ! -f "$ENV_EXAMPLE" ]; then
        echo "[ERROR] File .env.example tidak ditemukan!"
        exit 1
    fi
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "[OK] .env.example → .env"
else
    echo "[INFO] .env sudah ada, akan di-update secret-nya."
fi

# ── 2. Generate secrets dengan Python (CSPRNG) ──────────────────────────────
echo ""
echo "==> Generating secrets..."

read -r POSTGRES_PASSWORD POSTGRES_APP_PASSWORD KPR_API_KEY INTERNAL_API_KEY <<< \
    "$(python3 -c "
import secrets
print(
    secrets.token_urlsafe(32),
    secrets.token_urlsafe(32),
    secrets.token_urlsafe(32),
    secrets.token_urlsafe(32),
)
")"

# ── 3. Tulis ke .env menggunakan sed (in-place) ─────────────────────────────
update_env() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$ENV_FILE"; then
        # Replace existing line (kosong atau sudah ada nilainya)
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        # Append jika belum ada
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

update_env "POSTGRES_PASSWORD"     "$POSTGRES_PASSWORD"
update_env "POSTGRES_APP_PASSWORD" "$POSTGRES_APP_PASSWORD"
update_env "KPR_API_KEY"           "$KPR_API_KEY"
update_env "INTERNAL_API_KEY"      "$INTERNAL_API_KEY"

# ── 4. Tampilkan hasil (masked) ──────────────────────────────────────────────
mask() {
    local val="$1"
    echo "${val:0:8}...${val: -4}"
}

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Secrets berhasil di-generate dan ditulis ke .env"
echo "════════════════════════════════════════════════════════════"
echo "  POSTGRES_PASSWORD     = $(mask "$POSTGRES_PASSWORD")"
echo "  POSTGRES_APP_PASSWORD = $(mask "$POSTGRES_APP_PASSWORD")"
echo "  KPR_API_KEY           = $(mask "$KPR_API_KEY")"
echo "  INTERNAL_API_KEY      = $(mask "$INTERNAL_API_KEY")"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "[INFO] File .env: $ENV_FILE"
echo ""

# ── 5. Reminder: variabel lain yang perlu diisi manual ───────────────────────
echo "⚠️  Pastikan isi manual variabel berikut di .env jika diperlukan:"
echo "    - POSTGRES_HOST       (default: 127.0.0.1)"
echo "    - KLASIFIKASI_URL     & KLASIFIKASI_API_KEY"
echo "    - AKTA_CALC_URL       & AKTA_CALC_API_KEY"
echo "    - OCR_RESULT_URL      & OCR_RESULT_API_KEY"
echo ""
echo "📌 Jangan lupa buat user di PostgreSQL dengan password yang sama:"
echo "    psql -h <DB_HOST> -U postgres -c \"ALTER USER kpr_user WITH PASSWORD '\$POSTGRES_PASSWORD';\""
echo "    psql -h <DB_HOST> -U postgres -c \"ALTER USER kpr_app WITH PASSWORD '\$POSTGRES_APP_PASSWORD';\""
echo ""
echo "[DONE] Selanjutnya jalankan: ./deploy.sh"
