#!/usr/bin/env python3
"""Upload a built release APK to Firebase Storage for learner distribution.

Learners install the app before they have any account, so the file must be
publicly readable (see app_releases/{allPaths=**} in storage.rules). This
script uploads to app_releases/<name> using the active `firebase login`
access token, same pattern as scripts/upload_asr_model.py.

Usage:
  python scripts/upload_app_release.py
  python scripts/upload_app_release.py --apk build\\app\\outputs\\flutter-apk\\app-release.apk --name mission_app.apk
"""
from __future__ import annotations

import argparse
import json
import pathlib
import urllib.parse
import urllib.request

DEFAULT_APK = pathlib.Path("build/app/outputs/flutter-apk/app-release.apk")
DEFAULT_NAME = "mission_app.apk"
DEFAULT_BUCKET = "mission-app-b29ed.firebasestorage.app"


def _firebase_access_token() -> str:
    import os
    home = pathlib.Path(os.environ.get("USERPROFILE") or os.environ.get("HOME") or "")
    config_path = home / ".config" / "configstore" / "firebase-tools.json"
    data = json.loads(config_path.read_text(encoding="utf-8"))
    return data["tokens"]["access_token"]


def _upload_object(token: str, bucket: str, object_name: str, data: bytes, content_type: str) -> None:
    encoded_name = urllib.parse.quote(object_name, safe="")
    url = (
        f"https://storage.googleapis.com/upload/storage/v1/b/{bucket}/o"
        f"?uploadType=media&name={encoded_name}"
    )
    req = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": content_type,
        },
    )
    with urllib.request.urlopen(req) as resp:
        resp.read()


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--apk", type=pathlib.Path, default=DEFAULT_APK)
    p.add_argument("--name", default=DEFAULT_NAME)
    p.add_argument("--bucket", default=DEFAULT_BUCKET)
    args = p.parse_args()

    if not args.apk.exists():
        print(f"[ERROR] APK not found: {args.apk}")
        return 2

    size = args.apk.stat().st_size
    print(f"Uploading {args.apk} ({size:,} bytes) -> gs://{args.bucket}/app_releases/{args.name}")

    token = _firebase_access_token()
    with args.apk.open("rb") as f:
        data = f.read()
    object_name = f"app_releases/{args.name}"
    _upload_object(token, args.bucket, object_name, data, "application/vnd.android.package-archive")

    encoded_path = urllib.parse.quote(object_name, safe="")
    public_url = (
        f"https://firebasestorage.googleapis.com/v0/b/{args.bucket}/o/{encoded_path}?alt=media"
    )
    print("\n[OK] Uploaded. Public download URL:")
    print(public_url)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
