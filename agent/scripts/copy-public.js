const fs = require('fs');
const path = require('path');

function copyDir(src, dst) {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dst, { recursive: true });
  for (const ent of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, ent.name);
    const d = path.join(dst, ent.name);
    if (ent.isDirectory()) copyDir(s, d);
    else if (ent.isFile()) fs.copyFileSync(s, d);
  }
}

const root = path.join(__dirname, '..');
const src = path.join(root, 'public');
const dst = path.join(root, 'dist', 'public');

fs.mkdirSync(path.join(root, 'dist'), { recursive: true });
copyDir(src, dst);
console.log(`[build] Copied public -> ${path.relative(process.cwd(), dst)}`);

