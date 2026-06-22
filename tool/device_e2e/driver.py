#!/usr/bin/env python3
"""Black-box on-device E2E driver for the Learning Tracker Android app.

This is REAL device end-to-end automation: it drives actual pixels on a real
phone over ADB (screencap + input tap + uiautomator), navigates real screens,
handles native dialogs, and verifies state both in the UI and in live Firestore.
It is intentionally NOT a `flutter test` — those run headless against fakes. This
walks the shipped app on hardware.

Design goals (learned the hard way driving this manually):
  * Find elements by TEXT / content-desc / resource-id and tap their CENTER
    (resolved from `uiautomator dump` bounds) instead of hardcoded pixels —
    pixels break the moment the keyboard opens or layout shifts.
  * Keyboard-safe text entry: focus field, type, dismiss IME, re-resolve coords.
  * Explicit waits that poll for an element to appear, not blind sleeps.
  * Screenshots saved per step for an auditable trail.
  * Firestore assertions via REST (gcloud token) so we verify the BACKEND, not
    just the UI — true end-to-end.

Local-only dev tool. Requires: a connected device (ADB over Tailscale), the
debug build installed with its App Check debug token registered, and a
`gcloud auth print-access-token` for Firestore reads. NOT a CI artifact.

Usage:
    from driver import Device
    d = Device("100.72.6.10:5555")
    d.launch()
    d.wait_text("Welcome Back!")
    d.tap_text("Register Here")
    d.type_into(hint="Scholar Name", text="CloudKid")
    d.tap_desc("Sign Up")
    assert d.firestore_count(f"users/{uid}/learner_profiles") == 1
"""

from __future__ import annotations

import re
import subprocess
import time
import xml.etree.ElementTree as ET

PKG = "com.jcom.torah.learning_tracker"
PROJECT = "torah-study-tracker"
ADB = "/home/daniel/Android/Sdk/platform-tools/adb"


class Device:
    def __init__(self, serial: str, artifact_dir: str = "/tmp/device_e2e"):
        self.serial = serial
        self.artifact_dir = artifact_dir
        subprocess.run(["mkdir", "-p", artifact_dir], check=False)
        subprocess.run([ADB, "connect", serial], capture_output=True, check=False)

    # ── adb plumbing ─────────────────────────────────────────────────────────
    def _adb(self, *args: str, timeout: int = 60) -> str:
        r = subprocess.run(
            [ADB, "-s", self.serial, *args],
            capture_output=True, text=True, timeout=timeout,
        )
        return r.stdout

    def shell(self, cmd: str, timeout: int = 60) -> str:
        return self._adb("shell", cmd, timeout=timeout)

    # ── lifecycle ────────────────────────────────────────────────────────────
    def launch(self, clear: bool = False) -> None:
        if clear:
            self.shell(f"pm clear {PKG}")
        self.shell(f"monkey -p {PKG} -c android.intent.category.LAUNCHER 1")
        time.sleep(6)

    def force_stop(self) -> None:
        self.shell(f"am force-stop {PKG}")

    def screenshot(self, name: str) -> str:
        path = f"{self.artifact_dir}/{name}.png"
        with open(path, "wb") as f:
            f.write(
                subprocess.run(
                    [ADB, "-s", self.serial, "exec-out", "screencap", "-p"],
                    capture_output=True, check=False,
                ).stdout
            )
        return path

    # ── UI tree ──────────────────────────────────────────────────────────────
    def _dump(self) -> list[dict]:
        """Return a flat list of nodes: {text, desc, rid, hint, cls, pw, bounds, center}."""
        self.shell("uiautomator dump /sdcard/ui.xml")
        xml = self.shell("cat /sdcard/ui.xml")
        nodes: list[dict] = []
        try:
            root = ET.fromstring(xml.strip())
        except ET.ParseError:
            return nodes
        for n in root.iter("node"):
            b = n.get("bounds", "")
            m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", b)
            if not m:
                continue
            x1, y1, x2, y2 = map(int, m.groups())
            nodes.append({
                "text": n.get("text", ""),
                "desc": n.get("content-desc", ""),
                "rid": n.get("resource-id", ""),
                "hint": n.get("hint", ""),
                "cls": n.get("class", ""),
                "pw": n.get("password", "") == "true",
                "focused": n.get("focused", "") == "true",
                "bounds": (x1, y1, x2, y2),
                "center": ((x1 + x2) // 2, (y1 + y2) // 2),
            })
        return nodes

    def find(self, *, text=None, desc=None, hint=None, contains=None, cls=None):
        """Return the first matching node dict, or None."""
        for nd in self._dump():
            # Flutter exposes labels via content-desc (text=""); native Android
            # dialogs use text. Match `text=` against EITHER so the same helper
            # works for app labels and OS dialogs alike.
            if text is not None and text not in (nd["text"], nd["desc"]):
                continue
            if desc is not None and nd["desc"] != desc:
                continue
            if hint is not None and nd["hint"] != hint:
                continue
            if cls is not None and nd["cls"] != cls:
                continue
            if contains is not None and (
                contains not in nd["text"]
                and contains not in nd["desc"]
            ):
                continue
            if text is None and desc is None and hint is None and cls is None \
               and contains is None:
                continue
            return nd
        return None

    def wait(self, *, timeout: float = 12, **kw):
        """Poll until find(**kw) returns a node; return it or raise."""
        deadline = time.time() + timeout
        while time.time() < deadline:
            nd = self.find(**kw)
            if nd:
                return nd
            time.sleep(0.6)
        raise TimeoutError(f"element not found within {timeout}s: {kw}")

    def present(self, *, timeout: float = 6, **kw) -> bool:
        try:
            self.wait(timeout=timeout, **kw)
            return True
        except TimeoutError:
            return False

    # ── interactions ─────────────────────────────────────────────────────────
    def tap_xy(self, x: int, y: int) -> None:
        self.shell(f"input tap {x} {y}")
        time.sleep(0.8)

    def tap(self, *, timeout: float = 12, **kw) -> None:
        nd = self.wait(timeout=timeout, **kw)
        self.tap_xy(*nd["center"])

    # convenience aliases
    def tap_text(self, text: str, **kw):
        self.tap(text=text, **kw)

    def tap_desc(self, desc: str, **kw):
        self.tap(desc=desc, **kw)

    def tap_contains(self, contains: str, **kw):
        self.tap(contains=contains, **kw)

    def back(self) -> None:
        self.shell("input keyevent KEYCODE_BACK")
        time.sleep(0.6)

    def type_into(self, *, text: str, hint=None, rid=None, timeout: float = 12):
        """Focus a field (by hint/rid), type text, dismiss the IME.

        Dismissing the IME after typing keeps the layout stable so the NEXT
        field's coordinates (re-resolved by the caller) stay valid — the
        keyboard-shift bug that broke naive pixel scripts.
        """
        nd = self.wait(timeout=timeout, **({"hint": hint} if hint else {"rid": rid}))
        self.tap_xy(*nd["center"])
        time.sleep(0.6)
        # escape spaces for adb input text
        self.shell("input text " + text.replace(" ", "%s"))
        time.sleep(0.6)
        self.back()  # hide IME

    def clear_field(self, *, hint=None, rid=None, n: int = 50):
        nd = self.wait(**({"hint": hint} if hint else {"rid": rid}))
        self.tap_xy(*nd["center"])
        self.shell("input keyevent KEYCODE_MOVE_END")
        for _ in range(n):
            self.shell("input keyevent KEYCODE_DEL")
        time.sleep(0.4)

    # ── assertions ───────────────────────────────────────────────────────────
    def assert_text(self, text=None, contains=None, timeout: float = 10):
        if not self.present(timeout=timeout, **(
            {"text": text} if text else {"contains": contains}
        )):
            raise AssertionError(
                f"expected on screen: {text or contains!r}"
            )

    # ── Firestore (live backend verification) ────────────────────────────────
    def _gtoken(self) -> str:
        return subprocess.run(
            ["gcloud", "auth", "print-access-token"],
            capture_output=True, text=True, timeout=30,
        ).stdout.strip()

    def firestore_get(self, path: str) -> dict | None:
        import json
        import urllib.request
        url = (f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
               f"/databases/(default)/documents/{path}")
        req = urllib.request.Request(url, headers={
            "Authorization": f"Bearer {self._gtoken()}",
            "x-goog-user-project": PROJECT,
        })
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                return json.load(r)
        except Exception:
            return None

    def firestore_count(self, collection_path: str) -> int:
        d = self.firestore_get(f"{collection_path}?pageSize=100")
        return len(d.get("documents", [])) if d else 0
