const fs = require('fs');
const path = require('path');

const DATA_DIR = process.env.DATA_DIR
  ? path.resolve(process.env.DATA_DIR)
  : path.join(__dirname, '..', 'data');
const DATA_FILE = path.join(DATA_DIR, 'state.json');

const defaultState = () => ({
  users: [],
  devices: [],
  events: [],
});

function ensureDir() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
}

function loadState() {
  ensureDir();
  if (!fs.existsSync(DATA_FILE)) {
    const s = defaultState();
    fs.writeFileSync(DATA_FILE, JSON.stringify(s, null, 2), 'utf8');
    return s;
  }
  try {
    const raw = fs.readFileSync(DATA_FILE, 'utf8');
    const parsed = JSON.parse(raw);
    if (!parsed.users) parsed.users = [];
    if (!parsed.devices) parsed.devices = [];
    if (!parsed.events) parsed.events = [];
    return parsed;
  } catch {
    return defaultState();
  }
}

function saveState(state) {
  ensureDir();
  fs.writeFileSync(DATA_FILE, JSON.stringify(state, null, 2), 'utf8');
}

module.exports = { loadState, saveState, DATA_FILE };
