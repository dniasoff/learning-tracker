// AUD-platform-03 — regression tests for tool/decode_release_keystore.sh.
//
// Run: node --test tool/decode_release_keystore.test.mjs
//
// Before this fix, .github/workflows/build.yml's "Decode keystore
// (Release only)" step only printed a warning and exited 0 when
// KEYSTORE_BASE64 was empty, then fell straight through into
// `flutter build apk --release` — which Gradle's release signingConfig
// would silently sign with the debug keystore (see
// android/app/build.gradle.kts). Confirmed directly against the
// pre-fix step body: KEYSTORE_BASE64="" produced "Warning: ..." on
// stdout and exit code 0.
//
// This suite spawns the real script (no mocking) and asserts it now
// aborts loudly instead.

import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('./decode_release_keystore.sh', import.meta.url));

function run(env, args) {
  return spawnSync('bash', [SCRIPT, ...args], {
    env: { ...process.env, ...env },
    encoding: 'utf8',
  });
}

test('aborts with a non-zero exit and an ::error:: annotation when KEYSTORE_BASE64 is unset', () => {
  const dir = mkdtempSync(join(tmpdir(), 'decode-keystore-'));
  const outPath = join(dir, 'keystore.jks');
  try {
    const env = { ...process.env };
    delete env.KEYSTORE_BASE64;
    const result = spawnSync('bash', [SCRIPT, outPath], { env, encoding: 'utf8' });

    assert.notEqual(result.status, 0, 'script must exit non-zero when the secret is missing');
    assert.match(result.stderr, /::error::/);
    assert.match(result.stderr, /KEYSTORE_BASE64/);
    assert.equal(existsSync(outPath), false, 'must not leave a partial/empty keystore file behind');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('aborts with a non-zero exit when KEYSTORE_BASE64 is set but empty', () => {
  const dir = mkdtempSync(join(tmpdir(), 'decode-keystore-'));
  const outPath = join(dir, 'keystore.jks');
  try {
    const result = run({ KEYSTORE_BASE64: '' }, [outPath]);
    assert.notEqual(result.status, 0);
    assert.equal(existsSync(outPath), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('decodes and writes the keystore file when KEYSTORE_BASE64 is set', () => {
  const dir = mkdtempSync(join(tmpdir(), 'decode-keystore-'));
  const outPath = join(dir, 'keystore.jks');
  try {
    const payload = Buffer.from('not-a-real-keystore-but-deterministic-bytes').toString('base64');
    const result = run({ KEYSTORE_BASE64: payload }, [outPath]);

    assert.equal(result.status, 0, `expected success, got stderr: ${result.stderr}`);
    assert.equal(existsSync(outPath), true);
    assert.equal(readFileSync(outPath, 'utf8'), 'not-a-real-keystore-but-deterministic-bytes');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('fails with usage error when no output path is given', () => {
  const result = spawnSync('bash', [SCRIPT], {
    env: { ...process.env, KEYSTORE_BASE64: 'irrelevant' },
    encoding: 'utf8',
  });
  assert.notEqual(result.status, 0);
});
