/**
 * CI / release build: writes `src/cloud-defaults.json` so `pkg` can embed it into the .exe.
 * Set AGENT_SERVER_URL and AGENT_ENROLLMENT_KEY (GitHub Actions repository secrets).
 */
const fs = require('fs');
const path = require('path');

const out = path.join(__dirname, '..', 'src', 'cloud-defaults.json');

const serverUrl = String(
  process.env.AGENT_SERVER_URL || process.env.DW_SERVER_URL || '',
).trim();
const enrollmentKey = String(
  process.env.AGENT_ENROLLMENT_KEY || process.env.DW_ENROLLMENT_KEY || '',
).trim();

if (!serverUrl || !enrollmentKey) {
  console.error(
    '[write-cloud-defaults] AGENT_SERVER_URL va AGENT_ENROLLMENT_KEY majburiy.\n' +
      '  GitHub: Settings → Secrets and variables → Actions → repository secrets.\n' +
      '  Mahalliy pkg build: PowerShellda ikkalasini export qiling, keyin `npm run build:win`.',
  );
  process.exit(1);
}

fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(
  out,
  JSON.stringify({ serverUrl, enrollmentKey }, null, 2),
  'utf8',
);
console.log('[write-cloud-defaults] Yozildi:', out);
