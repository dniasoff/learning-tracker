import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const functionsDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');

test('disabled translation is absent from discovery exports and secret params', () => {
  const env = { ...process.env };
  delete env.PHRASE_TRANSLATION_ENABLED;
  const script = `
    const path = require('node:path');
    const functions = require('./lib/index.js');
    const optionsPath = path.join(
      path.dirname(require.resolve('firebase-functions/v2')),
      'options.js',
    );
    const spec = require(optionsPath).__getSpec();
    process.stdout.write(JSON.stringify({
      hasTranslatePhrases: Object.hasOwn(functions, 'translatePhrases'),
      secrets: spec.params.filter((param) => param.type === 'secret').map((param) => param.name),
    }));
  `;
  const result = spawnSync(process.execPath, ['-e', script], {
    cwd: functionsDir,
    env,
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, result.stderr);
  const discovery = JSON.parse(result.stdout);
  assert.equal(discovery.hasTranslatePhrases, false);
  assert.deepEqual(discovery.secrets, []);
});
