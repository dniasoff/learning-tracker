#!/usr/bin/env bash
# Live Digital Asset Links smoke check (AUD-platform-01, acceptance
# criterion 1: "curl -f https://torah-study-tracker.firebaseapp.com/
# .well-known/assetlinks.json returns 200 with correct package_name/
# sha256_cert_fingerprints, wired into a deploy or CI check that fails the
# pipeline on regression").
#
# Android only honors the `android:autoVerify="true"` intent-filters in
# android/app/src/main/AndroidManifest.xml (the /sign-in and /invite deep
# links) after this file resolves with HTTP 200 and the expected shape.
# Run this AFTER `firebase deploy --only hosting` in CI — see
# .github/workflows/deploy-firebase-hosting.yml — so a regression (hosting
# config removed, appAssociation disabled, wrong package registered) fails
# the deploy pipeline instead of silently dead-ending real sign-in/invite
# links in production.
#
# Usage:
#   tool/check_assetlinks_live.sh
#   tool/check_assetlinks_live.sh --url <url> --expected-package <id>
#     # test-only overrides so the regression test
#     # (test/tool/check_assetlinks_live_test.dart) can point this at a
#     # disposable local HTTP server instead of the real production host.
#
# Exit codes:
#   0 — HTTP 200, valid JSON, contains an entry for --expected-package with
#       a non-empty sha256_cert_fingerprints array
#   1 — any of the above fails (prints a one-line reason)
#   2 — usage error, or `curl`/`jq` missing from PATH
set -euo pipefail

URL="https://torah-study-tracker.firebaseapp.com/.well-known/assetlinks.json"
EXPECTED_PACKAGE="com.jcom.torah.learning_tracker"

while [ $# -gt 0 ]; do
  case "$1" in
    --url)
      URL="$2"
      shift 2
      ;;
    --expected-package)
      EXPECTED_PACKAGE="$2"
      shift 2
      ;;
    *)
      echo "check_assetlinks_live: unknown argument '$1'" >&2
      exit 2
      ;;
  esac
done

for bin in curl jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "check_assetlinks_live: required tool '$bin' not found in PATH" >&2
    exit 2
  fi
done

BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT

HTTP_CODE="$(curl -s -o "$BODY_FILE" -w '%{http_code}' "$URL" || echo "000")"

if [ "$HTTP_CODE" != "200" ]; then
  echo "check_assetlinks_live FAILED: GET $URL returned HTTP $HTTP_CODE (expected 200)." >&2
  echo "Android will never mark this app the verified handler for the /sign-in and" >&2
  echo "/invite autoVerify intent-filters (AndroidManifest.xml) while this 404s/errors." >&2
  exit 1
fi

if ! jq empty "$BODY_FILE" >/dev/null 2>&1; then
  echo "check_assetlinks_live FAILED: response from $URL is not valid JSON." >&2
  head -c 200 "$BODY_FILE" >&2 || true
  exit 1
fi

MATCH_COUNT="$(jq --arg pkg "$EXPECTED_PACKAGE" '
  [ .[]? | select(.target.package_name == $pkg
      and (.target.sha256_cert_fingerprints | type == "array")
      and ((.target.sha256_cert_fingerprints | length) > 0)) ] | length
' "$BODY_FILE")"

if [ "$MATCH_COUNT" -lt 1 ]; then
  echo "check_assetlinks_live FAILED: $URL returned 200 but no entry has" >&2
  echo "target.package_name == \"$EXPECTED_PACKAGE\" with a non-empty" >&2
  echo "sha256_cert_fingerprints array. Body was:" >&2
  cat "$BODY_FILE" >&2
  exit 1
fi

echo "check_assetlinks_live PASSED: $URL returns 200 with a valid" \
  "$EXPECTED_PACKAGE entry ($MATCH_COUNT match(es))."
