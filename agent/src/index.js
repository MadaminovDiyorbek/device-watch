require('dotenv').config();
const fs = require('fs');
const path = require('path');
const express = require('express');
const { collectMetrics } = require('./metrics');

const SERVER_URL = (process.env.SERVER_URL || 'http://localhost:5050').replace(/\/$/, '');
const ENROLLMENT_KEY = process.env.ENROLLMENT_KEY || 'demo-enroll-secret';
const DEVICE_NAME_ENV = process.env.DEVICE_NAME || '';
const DEVICE_TYPE = process.env.DEVICE_TYPE || 'pc';
const DEVICE_LOCATION = process.env.DEVICE_LOCATION || '';
const LOCAL_UI_PORT = Number(process.env.LOCAL_UI_PORT) || 47100;
const HEARTBEAT_SEC = Math.max(3, Number(process.env.HEARTBEAT_SEC) || 5);

const CONFIG_PATH = path.join(__dirname, '..', 'agent-config.json');
const PUBLIC_DIR = path.join(__dirname, '..', 'public');

let latest = null;
let sessionUpGb = 0;
let sessionDownGb = 0;

function loadConfig() {
  if (!fs.existsSync(CONFIG_PATH)) return null;
  try {
    return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  } catch {
    return null;
  }
}

function saveConfig(cfg) {
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 2), 'utf8');
}

async function enroll(name) {
  const body = {
    enrollmentKey: ENROLLMENT_KEY,
    name,
    type: DEVICE_TYPE,
    hostname: name,
  };
  const r = await fetch(`${SERVER_URL}/api/devices/enroll`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!r.ok) {
    const t = await r.text();
    throw new Error(`Enroll xato ${r.status}: ${t}`);
  }
  const data = await r.json();
  saveConfig({ deviceToken: data.deviceToken, deviceId: data.deviceId, serverUrl: SERVER_URL });
  console.log('[agent] Ro‘yxatdan o‘tdi. agent-config.json saqlandi.');
  return data.deviceToken;
}

async function ensureToken() {
  let cfg = loadConfig();
  if (cfg?.deviceToken) return cfg.deviceToken;
  const os = require('os');
  const name = DEVICE_NAME_ENV || os.hostname() || 'Qurilma';
  return enroll(name);
}

async function sendHeartbeat(token, payload) {
  const r = await fetch(`${SERVER_URL}/api/devices/heartbeat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer ' + token,
    },
    body: JSON.stringify(payload),
  });
  if (!r.ok) {
    const t = await r.text();
    console.error('[agent] Heartbeat xato:', r.status, t);
  }
}

function startLocalUi() {
  const app = express();
  app.get('/api/local/stats', (_req, res) => {
    res.json(latest || { ok: false, message: 'Metrikalar hali yoq' });
  });
  app.use(express.static(PUBLIC_DIR));
  app.listen(LOCAL_UI_PORT, '127.0.0.1', () => {
    console.log(`[agent] Mahalliy panel: http://127.0.0.1:${LOCAL_UI_PORT}/`);
  });
}

async function loop() {
  const token = await ensureToken();
  async function tick() {
    try {
      const m = await collectMetrics({ location: DEVICE_LOCATION, sessionUpGb, sessionDownGb });
      const upMb = (m.netUpMbps * HEARTBEAT_SEC) / 8;
      const downMb = (m.netDownMbps * HEARTBEAT_SEC) / 8;
      sessionUpGb += upMb / 1024;
      sessionDownGb += downMb / 1024;
      m.netTotalUpGb = Number(sessionUpGb.toFixed(3));
      m.netTotalDownGb = Number(sessionDownGb.toFixed(3));
      latest = { ...m, at: new Date().toISOString() };
      await sendHeartbeat(token, latest);
    } catch (e) {
      console.error('[agent]', e.message || e);
    }
  }
  await tick();
  setInterval(tick, HEARTBEAT_SEC * 1000);
}

(async () => {
  console.log('[agent] Cloud server:', SERVER_URL);
  startLocalUi();
  try {
    await loop();
  } catch (e) {
    console.error('[agent]', e.message || e);
  }
})();
