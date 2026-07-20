#!/usr/bin/env python3
"""
Uploads store listing, screenshots, icon, and feature graphic to Google Play
using the Android Publisher API.

Usage:
    python3 tool/upload_store_assets.py /path/to/service-account.json

The script opens a new edit, replaces all store listing assets for en-US,
then commits the edit.  It does NOT touch the APK/AAB — only listing assets.
"""

import sys
import os
import json
import mimetypes

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
PACKAGE_NAME = "com.jcom.torah.learning_tracker"
LANGUAGE     = "en-US"
ASSETS_DIR   = os.path.join(os.path.dirname(__file__), "../store_assets")

SHORT_DESC_MAX = 80
FULL_DESC_MAX  = 4000

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

SCREENSHOT_NAMES = ["dashboard", "learning", "progress", "scheduler", "gamification"]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def load_store_text():
    path = os.path.join(ASSETS_DIR, "store_listing.txt")
    short, full, in_full = "", [], False
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("SHORT DESCRIPTION"):
                continue
            if line.startswith("FULL DESCRIPTION"):
                in_full = True
                continue
            if not in_full and line.strip() and not short:
                short = line.strip()
            elif in_full:
                full.append(line)
    full_text = "\n".join(full).strip()
    assert len(short) <= SHORT_DESC_MAX, f"Short desc too long: {len(short)}"
    assert len(full_text) <= FULL_DESC_MAX, f"Full desc too long: {len(full_text)}"
    return short, full_text


def upload_image(service, edit_id, image_type, file_path):
    """Upload a single image, returning the uploaded image resource."""
    mime = "image/png"
    media = MediaFileUpload(file_path, mimetype=mime, resumable=False)
    result = service.images().upload(
        packageName=PACKAGE_NAME,
        editId=edit_id,
        language=LANGUAGE,
        imageType=image_type,
        media_body=media,
    ).execute()
    return result


def clear_image_type(service, edit_id, image_type):
    service.images().deleteall(
        packageName=PACKAGE_NAME,
        editId=edit_id,
        language=LANGUAGE,
        imageType=image_type,
    ).execute()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    if len(sys.argv) < 2:
        print("Usage: python3 upload_store_assets.py /path/to/service-account.json")
        sys.exit(1)

    key_file = sys.argv[1]
    if not os.path.exists(key_file):
        print(f"Service account key not found: {key_file}")
        sys.exit(1)

    print(f"Authenticating with {key_file} ...")
    creds = service_account.Credentials.from_service_account_file(key_file, scopes=SCOPES)
    service = build("androidpublisher", "v3", credentials=creds)
    edits = service.edits()

    # Open edit
    print("Opening edit ...")
    edit = edits.insert(packageName=PACKAGE_NAME, body={}).execute()
    edit_id = edit["id"]
    print(f"  Edit ID: {edit_id}")

    try:
        # --- Store listing text ---
        print("\nUpdating store listing text ...")
        short_desc, full_desc = load_store_text()
        edits.listings().update(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            language=LANGUAGE,
            body={
                "language": LANGUAGE,
                "title": "Torah Learning Tracker",
                "shortDescription": short_desc,
                "fullDescription": full_desc,
            },
        ).execute()
        print(f"  Short: {short_desc[:60]}...")
        print(f"  Full: {len(full_desc)} chars")

        # --- App icon ---
        print("\nUploading app icon ...")
        icon_path = os.path.join(ASSETS_DIR, "app_icon_512.png")
        clear_image_type(service, edit_id, "icon")
        r = upload_image(service, edit_id, "icon", icon_path)
        print(f"  Uploaded: {r.get('image', {}).get('id', '?')}")

        # --- Feature graphic ---
        print("\nUploading feature graphic ...")
        fg_path = os.path.join(ASSETS_DIR, "feature_graphic_1024x500.png")
        clear_image_type(service, edit_id, "featureGraphic")
        r = upload_image(service, edit_id, "featureGraphic", fg_path)
        print(f"  Uploaded: {r.get('image', {}).get('id', '?')}")

        # --- Phone screenshots ---
        print("\nUploading phone screenshots ...")
        clear_image_type(service, edit_id, "phoneScreenshots")
        for i in range(1, 6):
            path = os.path.join(ASSETS_DIR, f"phone_{i}_{SCREENSHOT_NAMES[i-1]}.png")
            r = upload_image(service, edit_id, "phoneScreenshots", path)
            print(f"  [{i}/5] {os.path.basename(path)}")

        # --- 7-inch tablet screenshots ---
        print("\nUploading 7-inch tablet screenshots ...")
        clear_image_type(service, edit_id, "sevenInchScreenshots")
        for i in range(1, 6):
            path = os.path.join(ASSETS_DIR, f"tablet_7inch_phone_{i}_{SCREENSHOT_NAMES[i-1]}.png")
            r = upload_image(service, edit_id, "sevenInchScreenshots", path)
            print(f"  [{i}/5] {os.path.basename(path)}")

        # --- 10-inch tablet screenshots ---
        print("\nUploading 10-inch tablet screenshots ...")
        clear_image_type(service, edit_id, "tenInchScreenshots")
        for i in range(1, 6):
            path = os.path.join(ASSETS_DIR, f"tablet_10inch_phone_{i}_{SCREENSHOT_NAMES[i-1]}.png")
            r = upload_image(service, edit_id, "tenInchScreenshots", path)
            print(f"  [{i}/5] {os.path.basename(path)}")

        # --- Commit edit ---
        print("\nCommitting edit ...")
        result = edits.commit(packageName=PACKAGE_NAME, editId=edit_id).execute()
        print(f"  Done — edit {result.get('id')} committed.")

    except Exception as e:
        print(f"\nERROR: {e}")
        print("Deleting draft edit ...")
        try:
            edits.delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
        except Exception:
            pass
        sys.exit(1)


if __name__ == "__main__":
    main()
