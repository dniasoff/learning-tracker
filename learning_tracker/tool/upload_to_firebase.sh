#!/bin/bash
# Upload curriculum content to Firebase Cloud Storage.
#
# Prerequisites:
#   1. Run: gcloud auth login
#   2. Run: dart run tool/seed_content.dart  (generates assets/content/*.json)
#   3. Run this script
#
# Usage:
#   ./tool/upload_to_firebase.sh [--dry-run] [--curriculum=mishnayos]
#
# Structure uploaded:
#   content/v1/manifest.json
#   content/v1/{curriculum}/hierarchy/he.json.gz
#   content/v1/{curriculum}/hierarchy/he_plain.json.gz
#   content/v1/{curriculum}/hierarchy/en.json.gz
#   ...

set -euo pipefail

BUCKET="gs://torah-study-tracker.firebasestorage.app"
PREFIX="content/v1"
BUILD_DIR="build/firebase_content"
ASSETS_DIR="build/seeded_content"
DRY_RUN=false
SPECIFIC_CURRICULUM=""

# Parse args
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --curriculum=*) SPECIFIC_CURRICULUM="${arg#*=}" ;;
  esac
done

# All curricula (matching CurriculumId enum storageKeys)
ALL_CURRICULA=(mishnayos bavli yerushalmi mishna_berurah chumash nach mussar)
# torah and tanach share content with chumash/nach respectively — skip for now

if [ -n "$SPECIFIC_CURRICULUM" ]; then
  CURRICULA=("$SPECIFIC_CURRICULUM")
else
  CURRICULA=("${ALL_CURRICULA[@]}")
fi

# Supported languages for hierarchy
HIERARCHY_LANGUAGES=(he he_plain en fr es it)

echo "=== Firebase Content Upload ==="
echo "Bucket: $BUCKET"
echo "Prefix: $PREFIX"
echo "Curricula: ${CURRICULA[*]}"
echo ""

# Check prerequisites
if [ ! -d "$ASSETS_DIR" ]; then
  echo "ERROR: $ASSETS_DIR not found. Run 'dart run tool/seed_content.dart' first to fetch from Sefaria."
  exit 1
fi

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- Generate hierarchy files per language ---
# For now, all languages share the same hierarchy structure (display names are
# in both Hebrew and English in the same file). The language code in the path
# allows future per-language display name translations.
#
# he = Hebrew display names (with nikud where present in source)
# he_plain = Hebrew display names with nikud stripped
# en/fr/es/it = same structure, ready for translated displayName fields

echo "--- Generating hierarchy files ---"

for curriculum in "${CURRICULA[@]}"; do
  src="$ASSETS_DIR/${curriculum}.json"
  if [ ! -f "$src" ]; then
    echo "WARNING: $src not found, skipping $curriculum"
    continue
  fi

  for lang in "${HIERARCHY_LANGUAGES[@]}"; do
    outdir="$BUILD_DIR/$curriculum/hierarchy"
    mkdir -p "$outdir"

    if [ "$lang" = "he_plain" ]; then
      # Strip Hebrew nikud (Unicode range U+0591-U+05C7)
      # Uses perl for reliable Unicode handling
      perl -CSD -pe 's/[\x{0591}-\x{05C7}]//g' "$src" | gzip -9 > "$outdir/${lang}.json.gz"
    else
      # All other languages use the same base file for now
      gzip -9 -c "$src" > "$outdir/${lang}.json.gz"
    fi
  done

  original_size=$(wc -c < "$src")
  gz_size=$(wc -c < "$BUILD_DIR/$curriculum/hierarchy/he.json.gz")
  echo "  $curriculum: ${original_size}B → ${gz_size}B gzipped ($(( gz_size * 100 / original_size ))%)"
done

# --- Generate manifest.json ---
echo ""
echo "--- Generating manifest.json ---"

MANIFEST="$BUILD_DIR/manifest.json"
UPDATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VERSION=$(date -u +"%Y.%m.%d")

# Build manifest using jq if available, otherwise use dart
if command -v jq &> /dev/null; then
  # Start building JSON
  CURRICULA_JSON="{}"
  for curriculum in "${CURRICULA[@]}"; do
    src="$ASSETS_DIR/${curriculum}.json"
    if [ ! -f "$src" ]; then continue; fi

    # Extract totalItems from hierarchy config
    TOTAL_ITEMS=$(python3 -c "
import json, sys
with open('$src') as f:
    data = json.load(f)
print(data['hierarchyConfig']['totalItems'])
" 2>/dev/null || echo "0")

    LANG_ARRAY=$(printf '"%s",' "${HIERARCHY_LANGUAGES[@]}")
    LANG_ARRAY="[${LANG_ARRAY%,}]"

    CURRICULA_JSON=$(echo "$CURRICULA_JSON" | jq \
      --arg curr "$curriculum" \
      --arg ver "$VERSION" \
      --argjson total "$TOTAL_ITEMS" \
      --argjson langs "$LANG_ARRAY" \
      '. + {($curr): {hierarchy: {version: $ver, languages: $langs, totalItems: $total}, text: {version: "0", languages: [], chunks: {}}}}')
  done

  jq -n \
    --argjson schema 1 \
    --arg updated "$UPDATED_AT" \
    --argjson curricula "$CURRICULA_JSON" \
    '{schemaVersion: $schema, updatedAt: $updated, curricula: $curricula}' \
    > "$MANIFEST"
else
  # Fallback: generate with Python
  python3 -c "
import json, os, sys
from datetime import datetime

manifest = {
    'schemaVersion': 1,
    'updatedAt': '$UPDATED_AT',
    'curricula': {}
}

languages = $( printf "'%s'," "${HIERARCHY_LANGUAGES[@]}" | sed 's/,$//' | sed "s/'/\"/g" | xargs -I{} echo "[{}]" )

for curriculum in '${CURRICULA[*]}'.split():
    src = f'$ASSETS_DIR/{curriculum}.json'
    if not os.path.exists(src):
        continue
    with open(src) as f:
        data = json.load(f)
    total = data['hierarchyConfig']['totalItems']
    manifest['curricula'][curriculum] = {
        'hierarchy': {
            'version': '$VERSION',
            'languages': languages,
            'totalItems': total
        },
        'text': {
            'version': '0',
            'languages': [],
            'chunks': {}
        }
    }

with open('$MANIFEST', 'w') as f:
    json.dump(manifest, f, indent=2)
" 2>/dev/null
fi

echo "  Manifest written to $MANIFEST"
cat "$MANIFEST" | python3 -m json.tool 2>/dev/null | head -5
echo "  ..."

# --- Upload to Firebase Storage ---
echo ""
echo "--- Uploading to Firebase Storage ---"

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would upload:"
  find "$BUILD_DIR" -type f | while read -r file; do
    rel="${file#$BUILD_DIR/}"
    echo "  $file → $BUCKET/$PREFIX/$rel"
  done
  echo ""
  echo "Dry run complete. Remove --dry-run to upload."
  exit 0
fi

# Upload manifest (uncompressed)
echo "  Uploading manifest.json..."
gcloud storage cp "$MANIFEST" "$BUCKET/$PREFIX/manifest.json" \
  --content-type="application/json" 2>&1 | tail -1

# Upload hierarchy files
for curriculum in "${CURRICULA[@]}"; do
  hierarchy_dir="$BUILD_DIR/$curriculum/hierarchy"
  if [ ! -d "$hierarchy_dir" ]; then continue; fi

  for gz_file in "$hierarchy_dir"/*.json.gz; do
    lang=$(basename "$gz_file" .json.gz)
    dest="$BUCKET/$PREFIX/$curriculum/hierarchy/${lang}.json.gz"
    echo "  Uploading $curriculum/hierarchy/${lang}.json.gz..."
    gcloud storage cp "$gz_file" "$dest" \
      --content-type="application/json" \
      --content-encoding="gzip" 2>&1 | tail -1
  done
done

echo ""
echo "=== Upload complete ==="
echo "Verify: gcloud storage ls $BUCKET/$PREFIX/"
