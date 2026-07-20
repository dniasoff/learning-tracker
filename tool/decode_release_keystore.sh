#!/usr/bin/env bash
# AUD-platform-03 — decode the base64-encoded release keystore secret
# (KEYSTORE_BASE64) into a keystore.jks file for a release Android build.
#
# Previously this logic lived inline in .github/workflows/build.yml's
# "Decode keystore (Release only)" step and only printed a warning when
# KEYSTORE_BASE64 was empty, then let the job continue straight into
# `flutter build apk --release`. Because android/key.properties was never
# written in that case, Gradle's release signingConfig silently fell back to
# the debug keystore and the job uploaded the result as a GitHub Actions
# artifact literally named learning-tracker-release-apk — indistinguishable
# from a genuine release build to anyone who installs it.
#
# This script instead ABORTS (exit 1) when KEYSTORE_BASE64 is unset/empty,
# so the calling workflow step fails loudly instead of soft-skipping. See
# also android/app/build.gradle.kts's REQUIRE_RELEASE_SIGNING check, a
# second independent gate on the same failure mode.
#
# Usage: decode_release_keystore.sh <output-path>
# Reads: $KEYSTORE_BASE64 from the environment.
set -euo pipefail

OUT_PATH="${1:?usage: decode_release_keystore.sh <output-path>}"

if [ -n "${KEYSTORE_BASE64:-}" ]; then
  echo "$KEYSTORE_BASE64" | base64 -d > "$OUT_PATH"
else
  echo "::error::KEYSTORE_BASE64 secret is not set — refusing to continue a release build that would silently fall back to debug signing (AUD-platform-03). Set the KEYSTORE_BASE64 repository secret before dispatching build_type=release, or dispatch build_type=debug instead." >&2
  exit 1
fi
