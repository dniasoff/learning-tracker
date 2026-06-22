#!/usr/bin/env python3
"""Device E2E Journey 01 — first-run signup → create profile → verify in cloud.

Real device, real pixels, real Firestore. Drives:
  intro → (skip) → permission prompt (native dialogs) → sign-in → register →
  fill signup form → submit → admin-verify email → sign in → onboarding
  profile creation → verify the profile landed in live Firestore.

Run:  python3 journey_01_signup_profile.py
Prereqs: debug build installed, its App Check debug token registered, device
reachable, gcloud token available. Starts from a CLEARED app (first run).
"""
import json
import subprocess
import sys
import time
import urllib.request

from driver import Device, PROJECT

SERIAL = "100.72.6.10:5555"
EMAIL = f"e2e{int(time.time())}@example.com"
PASSWORD = "TestPass1234"
DISPLAY = "E2EParent"
PROFILE = "E2EKid"


def gtoken() -> str:
    return subprocess.run(["gcloud", "auth", "print-access-token"],
                          capture_output=True, text=True, timeout=30).stdout.strip()


def admin_verify_email(email: str) -> str:
    """Look up uid + force emailVerified=true (we don't control the inbox)."""
    tok = gtoken()
    base = f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}"
    hdr = {"Authorization": f"Bearer {tok}",
           "x-goog-user-project": PROJECT, "Content-Type": "application/json"}
    req = urllib.request.Request(f"{base}/accounts:lookup",
                                 data=json.dumps({"email": [email]}).encode(), headers=hdr)
    uid = json.load(urllib.request.urlopen(req, timeout=20))["users"][0]["localId"]
    req2 = urllib.request.Request(
        f"{base}/accounts:update",
        data=json.dumps({"localId": uid, "emailVerified": True}).encode(), headers=hdr)
    urllib.request.urlopen(req2, timeout=20)
    return uid


def step(msg: str):
    print(f"  • {msg}", flush=True)


def main() -> int:
    d = Device(SERIAL)
    step(f"launch (account: {EMAIL})")
    d.launch()
    d.screenshot("01_launch")

    # ── intro carousel ──────────────────────────────────────────────────────
    if d.present(text="Skip", timeout=8):
        step("intro: Skip")
        d.tap_text("Skip")
        time.sleep(2)

    # ── native permission prompt (notifications/location) ─────────────────────
    # The in-app prompt then triggers OS dialogs; dismiss/allow whatever shows.
    for _ in range(4):
        if d.present(contains="Skip for now", timeout=3):
            step("permission prompt: Skip for now")
            d.tap_contains("Skip for now")
            time.sleep(1.5)
            break
        # OS dialog buttons
        for label in ("Allow", "While using the app", "Don’t allow", "Deny"):
            if d.present(text=label, timeout=2):
                step(f"OS dialog: {label}")
                d.tap_text(label)
                time.sleep(1)

    # ── sign-in screen → Register ─────────────────────────────────────────────
    d.wait(contains="Welcome Back", timeout=15)
    d.screenshot("02_signin")
    step("tap Register Here")
    d.tap_contains("Register Here")
    d.wait(desc="Create Account", timeout=10)
    d.screenshot("03_signup")

    # ── fill signup form (keyboard-safe, re-resolve each field) ───────────────
    step("fill display name")
    d.type_into(hint="Scholar Name", text=DISPLAY)
    step("fill email")
    d.type_into(hint="you@quest.com", text=EMAIL)
    step("fill password")
    d.type_into(hint="Create a secure password", text=PASSWORD)
    d.screenshot("04_signup_filled")
    step("submit signup")
    d.tap_desc("Sign Up")
    d.wait(contains="Verification email sent", timeout=20)
    d.screenshot("05_verify_sent")

    # ── admin-verify email, then sign in ──────────────────────────────────────
    step("admin-verify email via Identity Toolkit")
    uid = admin_verify_email(EMAIL)
    step(f"uid = {uid}")
    d.wait(contains="Welcome Back", timeout=10)
    step("fill sign-in")
    d.type_into(hint="yourname@quest.com", text=EMAIL)
    d.type_into(hint="Enter your secret key", text=PASSWORD)
    d.screenshot("06_signin_filled")
    step("Sign In")
    d.tap_desc("Sign In")

    # ── onboarding: create profile ────────────────────────────────────────────
    d.wait(contains="call you", timeout=20)
    d.screenshot("07_profile_step")
    step("enter profile name")
    d.type_into(hint="Enter name", text=PROFILE)
    d.screenshot("08_profile_named")
    step("Create Profile")
    d.tap_desc("Create Profile")
    time.sleep(8)
    d.screenshot("09_post_create")

    # ── verify in LIVE Firestore ──────────────────────────────────────────────
    step("verify profile synced to Firestore")
    time.sleep(4)
    coll = f"users/{uid}/learner_profiles"
    docs = d.firestore_get(f"{coll}?pageSize=10")
    names = []
    if docs:
        for x in docs.get("documents", []):
            f = x.get("fields", {})
            nm = (f.get("display_name") or f.get("displayName") or {}).get("stringValue", "")
            names.append(nm)
    print(f"\n  Firestore {coll}: {names}", flush=True)
    ok = PROFILE in names
    print(f"\n{'PASS' if ok else 'FAIL'}: profile '{PROFILE}' "
          f"{'synced to cloud' if ok else 'NOT in cloud'}", flush=True)
    print(f"TEST_UID={uid}", flush=True)  # for cleanup
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
