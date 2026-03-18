#!/usr/bin/env node
// Upload content to Firebase Storage using Admin SDK.
//
// Prerequisites:
//   1. Run: dart run tool/seed_content.dart
//   2. Run: node tool/upload_to_firebase.js
//
// Uses Application Default Credentials (gcloud auth application-default login)
// or GOOGLE_APPLICATION_CREDENTIALS env var.

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const BUCKET_NAME = 'torah-study-tracker.firebasestorage.app';
const PREFIX = 'content/v1';
const SEEDED_DIR = 'build/seeded_content';
const BUILD_DIR = 'build/firebase_content';
const HIERARCHY_LANGUAGES = ['he', 'he_plain', 'en', 'fr', 'es', 'it'];
const CURRICULA = ['mishnayos', 'bavli', 'yerushalmi', 'mishna_berurah', 'chumash', 'nach', 'mussar'];

async function main() {
  // Initialize Firebase Admin
  admin.initializeApp({
    storageBucket: BUCKET_NAME,
  });

  const bucket = admin.storage().bucket();

  // Check prerequisites
  if (!fs.existsSync(SEEDED_DIR)) {
    console.error(`ERROR: ${SEEDED_DIR} not found. Run 'dart run tool/seed_content.dart' first.`);
    process.exit(1);
  }

  // Clean and create build dir
  if (fs.existsSync(BUILD_DIR)) {
    fs.rmSync(BUILD_DIR, { recursive: true });
  }
  fs.mkdirSync(BUILD_DIR, { recursive: true });

  console.log('=== Firebase Content Upload ===');
  console.log(`Bucket: ${BUCKET_NAME}`);
  console.log(`Prefix: ${PREFIX}`);
  console.log('');

  // --- Generate and upload hierarchy files ---
  console.log('--- Generating & uploading hierarchy files ---');

  const manifestCurricula = {};

  for (const curriculum of CURRICULA) {
    const srcPath = path.join(SEEDED_DIR, `${curriculum}.json`);
    if (!fs.existsSync(srcPath)) {
      console.log(`  WARNING: ${srcPath} not found, skipping`);
      continue;
    }

    const srcData = fs.readFileSync(srcPath);
    const srcJson = JSON.parse(srcData);
    const totalItems = srcJson.hierarchyConfig?.totalItems || 0;

    for (const lang of HIERARCHY_LANGUAGES) {
      let dataToCompress = srcData;

      if (lang === 'he_plain') {
        // Strip Hebrew nikud (U+0591 to U+05C7)
        const stripped = srcData.toString('utf-8').replace(/[\u0591-\u05C7]/g, '');
        dataToCompress = Buffer.from(stripped, 'utf-8');
      }

      const gzipped = zlib.gzipSync(dataToCompress, { level: 9 });
      const destPath = `${PREFIX}/${curriculum}/hierarchy/${lang}.json.gz`;

      console.log(`  Uploading ${destPath} (${gzipped.length} bytes)...`);
      await bucket.file(destPath).save(gzipped, {
        metadata: {
          contentType: 'application/json',
          contentEncoding: 'gzip',
        },
      });
    }

    const originalSize = srcData.length;
    const gzSize = zlib.gzipSync(srcData, { level: 9 }).length;
    console.log(`  ✓ ${curriculum}: ${originalSize}B → ${gzSize}B gzipped (${Math.round(gzSize * 100 / originalSize)}%)`);

    manifestCurricula[curriculum] = {
      hierarchy: {
        version: new Date().toISOString().split('T')[0].replace(/-/g, '.'),
        languages: HIERARCHY_LANGUAGES,
        totalItems: totalItems,
      },
      text: {
        version: '0',
        languages: [],
        chunks: {},
      },
    };
  }

  // --- Generate and upload manifest ---
  console.log('');
  console.log('--- Uploading manifest.json ---');

  const manifest = {
    schemaVersion: 1,
    updatedAt: new Date().toISOString(),
    curricula: manifestCurricula,
  };

  const manifestJson = JSON.stringify(manifest, null, 2);
  const manifestPath = `${PREFIX}/manifest.json`;

  console.log(`  Uploading ${manifestPath}...`);
  await bucket.file(manifestPath).save(Buffer.from(manifestJson, 'utf-8'), {
    metadata: {
      contentType: 'application/json',
    },
  });

  console.log('');
  console.log('=== Upload complete ===');
  console.log(`Uploaded ${Object.keys(manifestCurricula).length} curricula × ${HIERARCHY_LANGUAGES.length} languages + manifest`);

  process.exit(0);
}

main().catch((err) => {
  console.error('Upload failed:', err.message || err);
  process.exit(1);
});
