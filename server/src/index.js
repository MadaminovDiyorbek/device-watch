require('dotenv').config();
const path = require('path');
const http = require('http');
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { Server } = require('socket.io');
const { loadState, saveState } = require('./store');

const PORT = Number(process.env.PORT) || 5050;
const JWT_SECRET = process.env.JWT_SECRET || 'dev-insecure-change-me';
const ENROLLMENT_KEY = process.env.ENROLLMENT_KEY || 'demo-enroll-secret';
const ADMIN_USERNAME = process.env.ADMIN_USERNAME || 'admin';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';

const app = express();
if (process.env.TRUST_PROXY === '1') {
  app.set('trust proxy', 1);
}
app.use(cors({ origin: true, credentials: true }));
app.use(express.json({ limit: '512kb' }));

app.get('/', (_req, res) => {
  res.redirect('/admin/');
});

function ensureAdminUser(state) {
  const exists = state.users.some((u) => u.username === ADMIN_USERNAME);
  if (!exists) {
    state.users.push({
      id: uuidv4(),
      username: ADMIN_USERNAME,
      passwordHash: bcrypt.hashSync(ADMIN_PASSWORD, 10),
      role: 'superadmin',
    });
    saveState(state);
    console.log(`[seed] Superadmin yaratildi: ${ADMIN_USERNAME} / (ADMIN_PASSWORD .env yoki default)`);
  }
}

function getState() {
  const state = loadState();
  ensureAdminUser(state);
  return state;
}

function authAdmin(req, res, next) {
  const h = req.headers.authorization || '';
  const m = h.match(/^Bearer\s+(.+)$/i);
  if (!m) return res.status(401).json({ error: 'Token kerak' });
  try {
    const payload = jwt.verify(m[1], JWT_SECRET);
    if (payload.role !== 'superadmin') return res.status(403).json({ error: 'Ruxsat yoq' });
    req.admin = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Token yaroqsiz' });
  }
}

function findDeviceByToken(state, token) {
  return state.devices.find((d) => d.token === token);
}

function recentEvent(state, deviceId, kind, winMs) {
  const events = state.events || [];
  const since = Date.now() - winMs;
  return events.some(
    (e) => e.deviceId === deviceId && e.kind === kind && new Date(e.at).getTime() > since,
  );
}

function appendEvent(state, part) {
  if (!state.events) state.events = [];
  const row = { id: uuidv4(), at: new Date().toISOString(), ...part };
  state.events.unshift(row);
  if (state.events.length > 200) state.events = state.events.slice(0, 200);
  saveState(state);
  return row;
}

function recordHeartbeatAlerts(state, device, body, io) {
  const cpu = Number(body.cpuUsage);
  const ram = Number(body.ramPercent);
  if (!Number.isFinite(cpu) || !Number.isFinite(ram)) return;
  if (cpu >= 85 && !recentEvent(state, device.id, 'cpu_high', 120000)) {
    const row = appendEvent(state, {
      kind: 'cpu_high',
      deviceId: device.id,
      deviceName: device.name,
      msg: `${device.name}: CPU ${Math.round(cpu)}%`,
    });
    if (io) io.to('admin').emit('activity:push', row);
  }
  if (ram >= 85 && !recentEvent(state, device.id, 'ram_high', 120000)) {
    const row = appendEvent(state, {
      kind: 'ram_high',
      deviceId: device.id,
      deviceName: device.name,
      msg: `${device.name}: RAM ${Math.round(ram)}%`,
    });
    if (io) io.to('admin').emit('activity:push', row);
  }
}

function devicePublicView(d) {
  const lastSeen = d.lastSeen || null;
  const offlineMs = 45000;
  const online = lastSeen && Date.now() - new Date(lastSeen).getTime() < offlineMs;
  const m = d.lastMetrics || {};
  return {
    id: d.id,
    name: d.name,
    hostname: d.hostname || d.name,
    type: d.type || 'pc',
    model: m.osString || d.model || '',
    status: online ? (m.cpuUsage > 90 || m.ramPercent > 90 ? 'warning' : 'online') : 'offline',
    specs: m.specs || {},
    cpu: online ? Math.round(m.cpuUsage || 0) : 0,
    ram: online ? Math.round(m.ramPercent || 0) : 0,
    ramUsed: m.ramUsedGb ?? 0,
    ramTotal: m.ramTotalGb ?? 0,
    disk: online ? Math.round(m.diskPercent || 0) : 0,
    diskUsed: m.diskUsedGb ?? 0,
    diskTotal: m.diskTotalGb ?? 0,
    netUp: online ? Number((m.netUpMbps || 0).toFixed(1)) : 0,
    netDown: online ? Number((m.netDownMbps || 0).toFixed(1)) : 0,
    netTotalUp: m.netTotalUpGb ?? 0,
    netTotalDown: m.netTotalDownGb ?? 0,
    lastSeen,
  };
}

/** ---------- HTTP ---------- */
app.post('/api/auth/login', (req, res) => {
  const { username, password } = req.body || {};
  const state = getState();
  const user = state.users.find((u) => u.username === username);
  if (!user || !bcrypt.compareSync(String(password || ''), user.passwordHash)) {
    return res.status(401).json({ error: 'Login yoki parol noto‘g‘ri' });
  }
  const token = jwt.sign({ sub: user.id, role: user.role, username: user.username }, JWT_SECRET, {
    expiresIn: '12h',
  });
  return res.json({ token, username: user.username, role: user.role });
});

app.get('/api/admin/devices', authAdmin, (req, res) => {
  const state = loadState();
  res.json({ devices: state.devices.map(devicePublicView) });
});

app.get('/api/admin/activity', authAdmin, (req, res) => {
  const state = loadState();
  if (!state.events) state.events = [];
  const limit = Math.min(100, Math.max(1, parseInt(String(req.query.limit || '40'), 10) || 40));
  res.json({ events: state.events.slice(0, limit) });
});

app.patch('/api/admin/devices/:id', authAdmin, (req, res) => {
  const state = loadState();
  const d = state.devices.find((x) => x.id === req.params.id);
  if (!d) return res.status(404).json({ error: 'Qurilma topilmadi' });
  const { name, type } = req.body || {};
  if (name != null && String(name).trim().length >= 2) d.name = String(name).trim();
  if (type != null && ['pc', 'phone', 'tablet'].includes(type)) d.type = type;
  saveState(state);
  const io = req.app.get('io');
  if (io) io.to('admin').emit('devices:patch', { device: devicePublicView(d), at: new Date().toISOString() });
  res.json({ device: devicePublicView(d) });
});

app.delete('/api/admin/devices/:id', authAdmin, (req, res) => {
  const state = loadState();
  const idx = state.devices.findIndex((x) => x.id === req.params.id);
  if (idx < 0) return res.status(404).json({ error: 'Qurilma topilmadi' });
  const removed = state.devices[idx];
  state.devices.splice(idx, 1);
  const row = appendEvent(state, {
    kind: 'device_deleted',
    deviceId: req.params.id,
    deviceName: removed.name,
    msg: `Qurilma o‘chirildi: ${removed.name}`,
  });
  const io = req.app.get('io');
  if (io) {
    io.to('admin').emit('devices:snapshot', { devices: state.devices.map(devicePublicView), at: new Date().toISOString() });
    io.to('admin').emit('activity:push', row);
  }
  res.json({ ok: true });
});

app.post('/api/devices/enroll', (req, res) => {
  const { enrollmentKey, name, type, hostname, model } = req.body || {};
  if (enrollmentKey !== ENROLLMENT_KEY) return res.status(403).json({ error: 'Enrollment kalit noto‘g‘ri' });
  if (!name || String(name).trim().length < 2) return res.status(400).json({ error: 'name majburiy' });
  const state = loadState();
  const token = uuidv4() + uuidv4().replace(/-/g, '');
  const device = {
    id: uuidv4(),
    name: String(name).trim(),
    hostname: hostname ? String(hostname) : '',
    type: ['pc', 'phone', 'tablet'].includes(type) ? type : 'pc',
    model: model ? String(model) : '',
    token,
    createdAt: new Date().toISOString(),
    lastSeen: null,
    lastMetrics: null,
  };
  state.devices.push(device);
  const row = appendEvent(state, {
    kind: 'device_enrolled',
    deviceId: device.id,
    deviceName: device.name,
    msg: `Yangi qurilma ulandi: ${device.name}`,
  });
  console.log(`[enroll] Yangi qurilma: ${device.name} (${device.id})`);
  const io = req.app.get('io');
  if (io) {
    io.to('admin').emit('devices:snapshot', { devices: state.devices.map(devicePublicView), at: new Date().toISOString() });
    io.to('admin').emit('activity:push', row);
  }
  return res.json({ deviceId: device.id, deviceToken: token, message: 'tokenni agent-config.json ga saqlang' });
});

app.post('/api/devices/heartbeat', (req, res) => {
  const h = req.headers.authorization || '';
  const m = h.match(/^Bearer\s+(.+)$/i);
  if (!m) return res.status(401).json({ error: 'Device token kerak' });
  const state = loadState();
  const d = findDeviceByToken(state, m[1].trim());
  if (!d) return res.status(401).json({ error: 'Qurilma topilmadi' });
  const body = req.body && typeof req.body === 'object' ? req.body : {};
  d.lastSeen = new Date().toISOString();
  d.lastMetrics = body;
  if (body.hostname) d.hostname = String(body.hostname);
  saveState(state);
  const io = req.app.get('io');
  if (io) io.to('admin').emit('devices:patch', { device: devicePublicView(d), at: d.lastSeen });
  recordHeartbeatAlerts(state, d, body, io);
  return res.json({ ok: true });
});

app.use(express.static(path.join(__dirname, '..', 'public')));

/** ---------- Socket.io (superadmin jonli) ---------- */
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: true, credentials: true },
});

app.set('io', io);

io.use((socket, next) => {
  const token = socket.handshake.auth?.token || socket.handshake.query?.token;
  if (!token) return next(new Error('auth_required'));
  try {
    const payload = jwt.verify(String(token), JWT_SECRET);
    if (payload.role !== 'superadmin') return next(new Error('forbidden'));
    socket.admin = payload;
    next();
  } catch {
    next(new Error('invalid_token'));
  }
});

io.on('connection', (socket) => {
  socket.join('admin');
  const state = loadState();
  if (!state.events) state.events = [];
  socket.emit('devices:snapshot', { devices: state.devices.map(devicePublicView), at: new Date().toISOString() });
  socket.emit('activity:snapshot', { events: state.events.slice(0, 40) });
  console.log(`[socket] Admin ulandi: ${socket.admin?.username}`);
  socket.on('disconnect', () => {});
});

server.listen(PORT, () => {
  getState();
  console.log(`DeviceWatch server: http://localhost:${PORT}`);
  console.log(`Superadmin panel: http://localhost:${PORT}/admin/`);
  console.log(`Enrollment key: ${ENROLLMENT_KEY}`);
});
