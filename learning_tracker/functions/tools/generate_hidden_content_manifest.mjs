#!/usr/bin/env node

// Generates the compact server-side hidden-content allowlist from the same
// hierarchy assets shipped to Flutter. The generated payload is gzip/base64 so
// the deployed function carries refs without a 5+ MB JavaScript array.

import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(here, '..', '..');
const hierarchyDir = path.join(projectRoot, 'assets', 'content', 'hierarchy');
const outputPath = path.join(here, '..', 'src', 'hidden_content_manifest.ts');

const refs = {};
for (const filename of fs.readdirSync(hierarchyDir).sort()) {
  if (!filename.endsWith('.json')) continue;
  const asset = JSON.parse(
    fs.readFileSync(path.join(hierarchyDir, filename), 'utf8'),
  );
  const curriculumId = asset.hierarchyConfig?.curriculumId;
  if (typeof curriculumId !== 'string' || !Array.isArray(asset.items)) {
    throw new Error(`Invalid hierarchy asset: ${filename}`);
  }
  refs[curriculumId] = asset.items
    .map((item) => item.sefariaRef)
    .filter((ref) => typeof ref === 'string' && ref.length > 0);
}

const payload = Buffer.from(JSON.stringify(refs), 'utf8');
const compressed = zlib.gzipSync(payload, { level: 9 }).toString('base64');
const output = `// GENERATED FILE. Run npm run build after changing hierarchy assets.\nimport zlib from "node:zlib";\n\nconst encoded = "${compressed}";\nconst refs = JSON.parse(\n  zlib.gunzipSync(Buffer.from(encoded, "base64")).toString("utf8"),\n);\n\nexport function isKnownHiddenContentRef(ref: string): boolean {\n  return Object.values(refs as Record<string, string[]>).some((items) =>\n    items.includes(ref),\n  );\n}\n`;

fs.writeFileSync(outputPath, output);
