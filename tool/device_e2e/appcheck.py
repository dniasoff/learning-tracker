#!/usr/bin/env python3
"""Capture and self-verify the two App Check debug tokens for a device.

Run this *after* ``pm clear`` or an emulator/data wipe.  Those operations
regenerate both the default FirebaseApp token and the named per-account
FirebaseApp token, so a token captured before the reset is no longer valid.

The App Check management API intentionally never returns the secret ``token``
field from list/get responses.  Verification therefore uses the public
``exchangeDebugToken`` endpoint: a successful exchange is proof that the
captured secret is registered for this Firebase app.  Registry resource IDs
are opaque and are never decoded.

The module is usable from another harness, or standalone::

    python3 tool/device_e2e/appcheck.py --serial emulator-5560
"""

from __future__ import annotations

import argparse
import base64
import json
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable, Iterable

try:  # Supports both ``python tool/device_e2e/appcheck.py`` and package import.
    from .driver import ADB, PKG
except ImportError:  # pragma: no cover - exercised by the standalone entrypoint.
    from driver import ADB, PKG


APP_CHECK_API = "https://firebaseappcheck.googleapis.com/v1"
MAX_DEBUG_TOKENS = 20
DEFAULT_PRUNE_THRESHOLD = 18
DEBUG_STORE_PREFIX = "com.google.firebase.appcheck.debug.store"
DEBUG_SECRET_NAME = "com.google.firebase.appcheck.debug.DEBUG_SECRET"
GOOGLE_SERVICES = (
    Path(__file__).resolve().parents[2]
    / "learning_tracker"
    / "android"
    / "app"
    / "google-services.json"
)


class AppCheckError(RuntimeError):
    """A fatal App Check preflight error with operator-facing context."""


@dataclass(frozen=True)
class DebugToken:
    role: str
    secret: str
    preference_file: str

    @property
    def short_secret(self) -> str:
        return f"{self.secret[:8]}…"


@dataclass(frozen=True)
class AppConfig:
    project_id: str
    project_number: str
    app_id: str
    api_key: str

    @property
    def app_resource(self) -> str:
        return f"projects/{self.project_number}/apps/{self.app_id}"


def load_app_config(path: Path = GOOGLE_SERVICES, package: str = PKG) -> AppConfig:
    """Load the project/app identifiers and API key for [package]."""
    try:
        data = json.loads(path.read_text())
        project = data["project_info"]
        client = next(
            c for c in data["client"]
            if c["client_info"]["android_client_info"]["package_name"] == package
        )
        app_info = client["client_info"]
        api_key = client["api_key"][0]["current_key"]
        return AppConfig(
            project_id=project["project_id"],
            project_number=project["project_number"],
            app_id=app_info["mobilesdk_app_id"],
            api_key=api_key,
        )
    except (OSError, KeyError, IndexError, StopIteration, json.JSONDecodeError) as exc:
        raise AppCheckError(
            f"cannot load Firebase Android config for {package} from {path}: {exc}"
        ) from exc


def _adb(serial: str, *args: str, timeout: int = 60) -> str:
    result = subprocess.run(
        [ADB, "-s", serial, *args],
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    if result.returncode:
        detail = (result.stderr or result.stdout).strip()
        raise AppCheckError(
            f"adb failed for {serial}: {' '.join(args)}"
            + (f" ({detail})" if detail else "")
        )
    return result.stdout


def _decode_store_role(filename: str) -> str:
    """Decode only the local preference key for labeling, never a registry ID."""
    encoded = filename[len(DEBUG_STORE_PREFIX):].lstrip(".").removesuffix(".xml")
    encoded = encoded.rsplit("+", 1)[0]
    try:
        decoded = base64.b64decode(encoded + "=" * (-len(encoded) % 4)).decode()
    except (ValueError, UnicodeDecodeError):
        decoded = ""
    return "default" if decoded == "[DEFAULT]" else "named"


def capture_debug_tokens(serial: str, package: str = PKG) -> list[DebugToken]:
    """Read the default and named-app debug secrets from a live device.

    This must be called after any app-data clear/wipe because each reset mints
    new secrets.  The debug build must be debuggable so ``run-as`` can read its
    SharedPreferences.
    """
    listing = _adb(serial, "shell", "run-as", package, "ls", "-1", "shared_prefs")
    files = sorted(
        line.strip()
        for line in listing.splitlines()
        if line.strip().startswith(DEBUG_STORE_PREFIX)
        and line.strip().endswith(".xml")
    )
    if not files:
        raise AppCheckError(
            f"no {DEBUG_STORE_PREFIX}*.xml files found for {package} on {serial}; "
            "launch the debug app after the reset so both providers mint tokens"
        )

    found: list[DebugToken] = []
    for filename in files:
        xml = _adb(
            serial,
            "shell",
            "run-as",
            package,
            "cat",
            f"shared_prefs/{filename}",
        )
        try:
            root = ET.fromstring(xml)
        except ET.ParseError as exc:
            raise AppCheckError(f"cannot parse {filename} on {serial}: {exc}") from exc
        secret = next(
            (
                node.text.strip()
                for node in root.findall("string")
                if node.get("name") == DEBUG_SECRET_NAME and node.text
            ),
            "",
        )
        if not secret:
            raise AppCheckError(
                f"{filename} on {serial} has no {DEBUG_SECRET_NAME} value"
            )
        found.append(DebugToken(_decode_store_role(filename), secret, filename))

    defaults = [token for token in found if token.role == "default"]
    named = [token for token in found if token.role == "named"]
    if len(defaults) != 1 or len(named) != 1:
        roles = ", ".join(f"{x.role}:{x.preference_file}" for x in found)
        raise AppCheckError(
            "expected exactly one default and one named-app debug token, found "
            f"{roles}; refusing to guess which token to register"
        )
    return [defaults[0], named[0]]


def _oauth_token() -> str:
    result = subprocess.run(
        ["gcloud", "auth", "print-access-token"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    token = result.stdout.strip()
    if result.returncode or not token:
        detail = (result.stderr or result.stdout).strip()
        raise AppCheckError(
            "gcloud auth print-access-token failed"
            + (f": {detail}" if detail else "")
        )
    return token


def _http_json(
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    payload: dict | None = None,
) -> dict:
    body = json.dumps(payload).encode() if payload is not None else None
    request_headers = {"Accept": "application/json", **(headers or {})}
    if payload is not None:
        request_headers["Content-Type"] = "application/json"
    request = urllib.request.Request(
        url, data=body, headers=request_headers, method=method
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace").strip()
        raise AppCheckError(f"{method} {url} failed ({exc.code}): {detail}") from exc
    except urllib.error.URLError as exc:
        raise AppCheckError(f"{method} {url} failed: {exc.reason}") from exc
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise AppCheckError(f"{method} {url} returned invalid JSON") from exc


def _management_headers(config: AppConfig) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {_oauth_token()}",
        "x-goog-user-project": config.project_id,
    }


def list_registry(config: AppConfig) -> list[dict]:
    """Return the complete registry; raw token values are intentionally absent."""
    parent = urllib.parse.quote(config.app_resource, safe="/")
    page_token = ""
    entries: list[dict] = []
    while True:
        query = "?pageSize=100" + (
            f"&pageToken={urllib.parse.quote(page_token)}" if page_token else ""
        )
        response = _http_json(
            "GET",
            f"{APP_CHECK_API}/{parent}/debugTokens{query}",
            headers=_management_headers(config),
        )
        entries.extend(response.get("debugTokens", []))
        page_token = response.get("nextPageToken", "")
        if not page_token:
            return entries


def _exchange_debug_token(config: AppConfig, secret: str) -> None:
    """Ask Firebase to exchange the secret; success proves registry membership."""
    app = urllib.parse.quote(config.app_resource, safe="/")
    url = f"{APP_CHECK_API}/{app}:exchangeDebugToken?key={urllib.parse.quote(config.api_key)}"
    response = _http_json("POST", url, payload={"debugToken": secret})
    if not response.get("token"):
        raise AppCheckError("exchange returned no App Check token")


def _delete_entry(config: AppConfig, entry: dict) -> None:
    resource = entry.get("name", "")
    if not resource.startswith("projects/"):
        raise AppCheckError(f"registry entry has no valid resource name: {entry!r}")
    url = f"{APP_CHECK_API}/{urllib.parse.quote(resource, safe='/')}"
    _http_json("DELETE", url, headers=_management_headers(config))


def _entry_time(entry: dict) -> datetime:
    value = entry.get("updateTime", "")
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return datetime.min


def _prune_for_capacity(
    config: AppConfig,
    entries: list[dict],
    required_slots: int,
    log: Callable[[str], None],
) -> list[dict]:
    """Delete the oldest registry entries needed to make room for new tokens."""
    if required_slots <= 0:
        return entries
    candidates = sorted(entries, key=_entry_time)
    if len(candidates) < required_slots:
        raise AppCheckError(
            f"registry has {len(entries)} entries but needs {required_slots} "
            "prune slots; refusing to continue"
        )
    for entry in candidates[:required_slots]:
        display = entry.get("displayName", "(unnamed)")
        log(f"prune stale registry entry: {display} ({entry.get('updateTime', 'unknown time')})")
        _delete_entry(config, entry)
    return list_registry(config)


def ensure_debug_tokens(
    serial: str,
    package: str = PKG,
    *,
    config: AppConfig | None = None,
    prune_threshold: int = DEFAULT_PRUNE_THRESHOLD,
    log: Callable[[str], None] = print,
) -> list[DebugToken]:
    """Capture, register, and independently verify both device debug tokens.

    Call this after every app-data reset.  If a token is missing and the
    registry is at/near its 20-token cap, the oldest entries are pruned before
    registration.  The current secrets are never printed in full.  A missing
    or unverified default/named token raises [AppCheckError] naming its role.
    """
    tokens = capture_debug_tokens(serial, package)
    config = config or load_app_config(package=package)
    log(
        f"captured default={tokens[0].short_secret} and "
        f"named={tokens[1].short_secret} from {serial}"
    )

    entries = list_registry(config)
    log(f"registry refreshed: {len(entries)}/{MAX_DEBUG_TOKENS} tokens")
    missing: list[DebugToken] = []
    for token in tokens:
        try:
            _exchange_debug_token(config, token.secret)
        except AppCheckError as exc:
            missing.append(token)
    if missing and len(entries) >= prune_threshold:
        required_slots = max(0, len(entries) + len(missing) - MAX_DEBUG_TOKENS)
        if required_slots:
            entries = _prune_for_capacity(config, entries, required_slots, log)
            log(f"registry after prune: {len(entries)}/{MAX_DEBUG_TOKENS} tokens")

    for token in missing:
        display_name = f"device-e2e-{serial}-{token.role}"
        log(f"register {token.role} token as {display_name}")
        parent = urllib.parse.quote(config.app_resource, safe="/")
        _http_json(
            "POST",
            f"{APP_CHECK_API}/{parent}/debugTokens",
            headers=_management_headers(config),
            payload={"displayName": display_name, "token": token.secret},
        )

    # Re-read after every possible mutation.  The response cannot contain the
    # secret by API contract, so use exchangeDebugToken as the membership proof
    # instead of guessing from an opaque resource id.
    final_entries = list_registry(config)
    log(f"registry verification read: {len(final_entries)}/{MAX_DEBUG_TOKENS} tokens")
    for token in tokens:
        try:
            _exchange_debug_token(config, token.secret)
        except AppCheckError as exc:
            raise AppCheckError(
                f"{token.role} token {token.short_secret} is NOT registered or "
                f"cannot be exchanged: {exc}"
            ) from exc
        log(f"verified {token.role} token {token.short_secret} via registry exchange")
    return tokens


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True, help="ADB serial, e.g. emulator-5560")
    parser.add_argument("--package", default=PKG, help=f"Android package (default: {PKG})")
    parser.add_argument(
        "--prune-threshold",
        type=int,
        default=DEFAULT_PRUNE_THRESHOLD,
        help=f"check for pruning at this count (default: {DEFAULT_PRUNE_THRESHOLD})",
    )
    args = parser.parse_args(list(argv) if argv is not None else None)
    try:
        ensure_debug_tokens(
            args.serial,
            args.package,
            prune_threshold=args.prune_threshold,
        )
    except AppCheckError as exc:
        print(f"APP CHECK PREFLIGHT FAILED: {exc}", file=sys.stderr)
        return 1
    print("APP CHECK PREFLIGHT PASS: default and named tokens are registered")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
