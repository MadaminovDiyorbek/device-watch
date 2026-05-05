# DeviceWatch server — cloudga chiqarish

Server — Node (Express + Socket.io), ma’lumotlar Docker volume dagi `data/state.json` da.

## Windows (mahalliy): bir buyruq

Repoda (masalan `D:\CM`):

```powershell
powershell -ExecutionPolicy Bypass -File tools\deploy\Setup-DeviceWatch.ps1 -TryDocker
```

Bu `server/.env` va `agent/.env` ni xavfsiz kalitlar bilan yangilaydi (zaif default bo‘lsa). Admin parol va `ENROLLMENT_KEY`: `server/.deploy-credentials.txt` (gitga tushmaydi).

Cloud URL ni agentga yozish:

```powershell
powershell -ExecutionPolicy Bypass -File tools\deploy\Setup-DeviceWatch.ps1 -CloudUrl https://watch.sizning-domen.uz
```

## Talablar

- VPS yoki cloud VM (masalan Ubuntu 22.04+), **ommaviy IP**
- Docker Engine + Docker Compose plugin
- Domen (HTTPS uchun): DNS **A** yozuvi shu server IP ga

## Render (tez sinov)

Repo rootida `render.yaml` qo'shildi, Render Blueprint orqali bir marta bosib ko'tarish mumkin.

1. Kodni GitHub'ga joylang (Render repodan tortib oladi).
2. Renderda **New + -> Blueprint** tanlang.
3. Repo'ni ulang, `device-watch-server` service chiqadi, deploy qiling.
4. Deploy tugagach URL oching: `https://<render-subdomain>/admin/`.
5. Render dashboard -> Environment bo'limidan:
   - `ADMIN_PASSWORD`
   - `ENROLLMENT_KEY`
   ni nusxalab saqlang.
6. Agent/mobil ilovada `SERVER_URL=https://<render-subdomain>` qilib qo'ying.

Muhim:
- Free plan ba'zan sleep holatiga o'tadi; birinchi so'rovda 20-60s kechikish bo'lishi mumkin.
- `DATA_DIR=/tmp/device-watch-data` vaqtinchalik. Redeploy/restartdan keyin state yo'qolishi mumkin.
- Doimiy saqlash va 24/7 uchun VPS yoki Render paid + disk tavsiya etiladi.

## 1. Serverni tayyorlash

```bash
git clone <repo> && cd <repo>/server
cp .env.example .env
nano .env   # yoki boshqa muharrir
```

`.env` da kamida quyilarni **ishlab chiqarish** uchun almashtiring:

- `JWT_SECRET` — uzun tasodifiy qator
- `ENROLLMENT_KEY` — agent va mobil ilova bilan bir xil maxfiy kalit
- `ADMIN_USERNAME` / `ADMIN_PASSWORD` — superadmin kirish

## 2A. Variant: faqat HTTP (port 5050)

Masalan, oldinda boshqa reverse proxy bo‘lsa yoki ichki test:

```bash
docker compose up -d --build
```

- Panel: `http://SERVER_IP:5050/admin/`
- Agentlar: `SERVER_URL=http://SERVER_IP:5050` (internetda **HTTPS tavsiya etiladi**)

Boshqa port: `HOST_PORT=8080 docker compose up -d --build`

## 2B. Variant: HTTPS (Caddy + Let’s Encrypt)

1. Domenni server IP ga qarang.
2. `80` va `443` portlari tashqaridan ochiq bo‘lsin.
3. Ishga tushiring:

```bash
export CADDY_DOMAIN=watch.sizning-domen.uz
docker compose -f docker-compose.https.yml up -d --build
```

- Panel: `https://watch.sizning-domen.uz/admin/`
- Agent / mobil: `SERVER_URL=https://watch.sizning-domen.uz`

Birinchi marta sertifikat olish biroz vaqt olishi mumkin.

## 3. Firewall (misol, ufw)

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
# Agar faqat HTTP compose ishlatsangiz:
# sudo ufw allow 5050/tcp
sudo ufw enable
```

## 4. Backup

Volume nomi odatda `<loyiha_papkasi>_device_watch_data`. Ma’lumotni saqlash:

```bash
docker run --rm -v server_device_watch_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/device-watch-data.tgz -C /data .
```

(`server` o‘rniga `docker compose ls` dagi loyiha nomi bo‘lishi mumkin.)

## 5. Yangilash

```bash
cd .../server
git pull
docker compose build --no-cache && docker compose up -d
# HTTPS:
# docker compose -f docker-compose.https.yml build --no-cache && docker compose -f docker-compose.https.yml up -d
```
