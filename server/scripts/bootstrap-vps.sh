#!/usr/bin/env bash
# Yangi Ubuntu VPS da bir marta: Docker + firewall + loyiha papkasi.
# Qo‘llash:  bash server/scripts/bootstrap-vps.sh
# Oldindan:  reponi VPS ga clone qiling yoki scp qiling; server/ ichida .env bo‘lsin.

set -euo pipefail

SUDO=""
if [[ ${EUID:-0} -ne 0 ]]; then SUDO=sudo; fi

if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | $SUDO sh
  if [[ -n "$SUDO" ]]; then
    $SUDO usermod -aG docker "$USER"
    echo "[OK] Docker o'rnatildi. Agar 'permission denied' bo'lsa, chiqib qayta kiring."
  fi
fi

$SUDO apt-get update -qq
$SUDO apt-get install -y -qq ufw git ca-certificates
$SUDO ufw allow OpenSSH
$SUDO ufw allow 80/tcp
$SUDO ufw allow 443/tcp
echo "[!] Faqat HTTP compose:  $SUDO ufw allow 5050/tcp"
echo "y | $SUDO ufw enable || true"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SERVER_DIR"

if [[ ! -f .env ]]; then
  echo "Xato: $SERVER_DIR/.env yoq. Avval .env.example dan nusxa oling va maxfiy kalitlarni yozing."
  exit 1
fi

echo "HTTPS (Caddy):  export CADDY_DOMAIN=watch.example.com"
echo "  docker compose -f docker-compose.https.yml up -d --build"
echo "HTTP:  docker compose up -d --build"
echo "Hozir HTTP rejimda ishga tushirilmoqda..."
docker compose up -d --build
echo "[OK] DeviceWatch ishga tushdi. Log: docker compose logs -f"
