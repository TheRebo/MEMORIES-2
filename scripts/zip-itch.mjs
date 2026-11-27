// Packs dist/ into release/memories-web.zip with index.html at the zip root, as itch.io expects.
import { readdirSync, readFileSync, statSync, mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { zipSync } from 'fflate';

const dist = 'dist';
if (!existsSync(join(dist, 'index.html'))) {
  console.error('dist/index.html not found. Run "pnpm build" first.');
  process.exit(1);
}

const files = {};
const walk = (dir) => {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) walk(full);
    else files[relative(dist, full).split(sep).join('/')] = readFileSync(full);
  }
};
walk(dist);

mkdirSync('release', { recursive: true });
const zip = zipSync(files, { level: 9 });
writeFileSync('release/memories-web.zip', zip);
console.log(`release/memories-web.zip: ${Object.keys(files).length} files, ${(zip.length / 1024 / 1024).toFixed(1)} MB`);
