// Turns the shared TypeScript core (core-ts/src) into plain ES modules GJS can load: types are
// erased by Node's own TypeScript support (no dependencies), and `.ts` imports become `.js`.
// Usage: node tools/core-to-js.mjs <output directory>
import { stripTypeScriptTypes } from 'node:module';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const source = join(here, '..', '..', '..', 'core-ts', 'src');
const out = process.argv[2];
if (!out) {
  console.error('usage: node tools/core-to-js.mjs <output directory>');
  process.exit(2);
}
if (typeof stripTypeScriptTypes !== 'function') {
  console.error('This needs Node 22.13 or later (module.stripTypeScriptTypes).');
  process.exit(2);
}

// What the extension uses, and what those files import.
const files = ['geometry.ts', 'arrangement.ts', 'split-tree.ts', 'strip.ts', 'layout.ts', 'generated/actions.ts'];

for (const file of files) {
  const ts = readFileSync(join(source, file), 'utf8');
  let js = stripTypeScriptTypes(ts, { mode: 'strip' });
  js = js.replace(/(from\s+['"]\.{1,2}\/[^'"]+)\.ts(['"])/g, '$1.js$2');
  if (/from\s+['"](?!\.)/.test(js)) throw new Error(`${file} imports a package; the extension can only load the core's own files`);
  const target = join(out, file.replace(/\.ts$/, '.js'));
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, `// Built from core-ts/src/${file} by linux/gnome/tools/core-to-js.mjs. Don't edit.\n${js}`);
  console.log(`core: ${file} -> ${target}`);
}
