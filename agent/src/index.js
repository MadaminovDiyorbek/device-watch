require('dotenv').config();
const fs = require('fs');
const path = require('path');
const express = require('express');
const { collectMetrics } = require('./metrics');

const os = require('os');
const { exec } = require('child_process');

function normalizeUrl(u) {
  const t = String(u || '').trim();
  if (!t) return '';
  return t.endsWith('/') ? t.slice(0, -1) : t;
}

function getConfigDir() {
  if (process.env.DEVICEWATCH_DIR) return path.resolve(process.env.DEVICEWATCH_DIR);
  // Prefer next to exe (portable install) if writable.
  const exeDir = path.dirname(process.execPath);
  try {
    fs.accessSync(exeDir, fs.constants.W_OK);
    return exeDir;
  } catch {}
  const appData = process.env.APPDATA;
  if (appData) return path.join(appData, 'DeviceWatch');
  return path.join(os.homedir(), '.devicewatch');
}

const CONFIG_DIR = getConfigDir();
const CONFIG_PATH = path.join(CONFIG_DIR, 'agent-config.json');

function getPublicDir() {
  // Prefer external folder next to exe (works for packaged .exe).
  const exeDir = path.dirname(process.execPath);
  const ext = path.join(exeDir, 'public');
  if (fs.existsSync(ext)) return ext;
  // Fallback to repo layout (node run).
  return path.join(__dirname, '..', 'public');
}

const PUBLIC_DIR = getPublicDir();

function getServerUrlFromEnv() {
  return normalizeUrl(process.env.SERVER_URL || 'http://localhost:5050');
}

function getEnrollmentKeyFromEnv() {
  return String(process.env.ENROLLMENT_KEY || 'demo-enroll-secret');
}

let SERVER_URL = getServerUrlFromEnv();
let ENROLLMENT_KEY = getEnrollmentKeyFromEnv();
const DEVICE_NAME_ENV = process.env.DEVICE_NAME || '';
const DEVICE_TYPE = process.env.DEVICE_TYPE || 'pc';
const DEVICE_LOCATION = process.env.DEVICE_LOCATION || '';
const LOCAL_UI_PORT = Number(process.env.LOCAL_UI_PORT) || 47100;
const HEARTBEAT_SEC = Math.max(3, Number(process.env.HEARTBEAT_SEC) || 5);

let latest = null;
let sessionUpGb = 0;
let sessionDownGb = 0;
let lastPingMs = null;

const ENV_SERVER_URL = normalizeUrl(process.env.SERVER_URL || '');
const ENV_ENROLLMENT_KEY = String(process.env.ENROLLMENT_KEY || '');

function loadConfig() {
  if (!fs.existsSync(CONFIG_PATH)) return null;
  try {
    return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  } catch {
    return null;
  }
}

function saveConfig(cfg) {
  fs.mkdirSync(CONFIG_DIR, { recursive: true });
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 2), 'utf8');
}

function applyConfigOverrides() {
  const cfg = loadConfig();
  if (!cfg) return;
  // ENV (or .env) should override config when explicitly provided.
  // This avoids being "stuck" on an old localhost value after packaging.
  if (!ENV_SERVER_URL && cfg.serverUrl) SERVER_URL = normalizeUrl(cfg.serverUrl);
  if (!ENV_ENROLLMENT_KEY && cfg.enrollmentKey) ENROLLMENT_KEY = String(cfg.enrollmentKey);
}

async function pingMs() {
  const sw = Date.now();
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 4000);
  try {
    const r = await fetch(`${SERVER_URL}/`, { signal: ctrl.signal });
    if (!r.ok) return null;
    return Date.now() - sw;
  } catch {
    return null;
  } finally {
    clearTimeout(t);
  }
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
  saveConfig({
    deviceToken: data.deviceToken,
    deviceId: data.deviceId,
    serverUrl: SERVER_URL,
    enrollmentKey: ENROLLMENT_KEY,
  });
  console.log('[agent] Ro‘yxatdan o‘tdi. agent-config.json saqlandi.');
  return data.deviceToken;
}

async function ensureToken() {
  let cfg = loadConfig();
  if (cfg?.deviceToken) return cfg.deviceToken;
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
    res.json(
      latest || {
        ok: false,
        message: 'Metrikalar hali yoq',
        serverUrl: SERVER_URL,
        heartbeatSec: HEARTBEAT_SEC,
        pingMs: lastPingMs,
      },
    );
  });
  app.use(express.static(PUBLIC_DIR));
  app.listen(LOCAL_UI_PORT, '127.0.0.1', () => {
    console.log(`[agent] Mahalliy panel: http://127.0.0.1:${LOCAL_UI_PORT}/`);
  });
}

function openLocalUi() {
  const url = `http://127.0.0.1:${LOCAL_UI_PORT}/`;
  if (process.platform === 'win32') {
    // Open as a minimal "app window" (no tabs) via Edge.
    exec(`cmd /c start "" msedge --app="${url}"`);
  } else if (process.platform === 'darwin') {
    exec(`open "${url}"`);
  } else {
    exec(`xdg-open "${url}"`);
  }
}

async function loop() {
  const token = await ensureToken();
  async function tick() {
    try {
      lastPingMs = await pingMs();
      const m = await collectMetrics({ location: DEVICE_LOCATION, sessionUpGb, sessionDownGb });
      const upMb = (m.netUpMbps * HEARTBEAT_SEC) / 8;
      const downMb = (m.netDownMbps * HEARTBEAT_SEC) / 8;
      sessionUpGb += upMb / 1024;
      sessionDownGb += downMb / 1024;
      m.netTotalUpGb = Number(sessionUpGb.toFixed(3));
      m.netTotalDownGb = Number(sessionDownGb.toFixed(3));
      latest = {
        ...m,
        at: new Date().toISOString(),
        serverUrl: SERVER_URL,
        heartbeatSec: HEARTBEAT_SEC,
        pingMs: lastPingMs,
      };
      await sendHeartbeat(token, latest);
    } catch (e) {
      console.error('[agent]', e.message || e);
    }
  }
  await tick();
  setInterval(tick, HEARTBEAT_SEC * 1000);
}

(async () => {
  applyConfigOverrides();
  console.log('[agent] Cloud server:', SERVER_URL);
  startLocalUi();
  openLocalUi();
  try {
    await loop();
  } catch (e) {
    console.error('[agent]', e.message || e);
  }
})();
