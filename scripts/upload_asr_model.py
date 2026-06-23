#!/usr/bin/env python3
"""Upload the on-device Sherpa ONNX ASR model bundle to Firebase Storage.

The model (~150MB, dominated by encoder.int8.onnx) is never bundled into the
app build (see docs_content_update_checklist_2026-06-22.md's sibling decision
record for why: it would roughly double APK size for a feature most learners
never use). Instead it lives in Firebase Storage under asr_models/<version>/
and the app downloads it on demand, gated to Wi-Fi, only when a learner opts
into "폰 전용 인식" (on-device-only ASR).

This script:
  1. Computes sha256 + size for each required model file.
  2. Writes a manifest.json (consumed by the client to verify the download
     and to size the progress bar without a HEAD request per file).
  3. Uploads all 5 objects (4 model files + manifest.json) to
     asr_models/<model-version>/ in the project's default Storage bucket,
     authenticated with the active `firebase login` access token (same
     pattern already used elsewhere in this repo — no extra Python deps).

Usage:
  python scripts/upload_asr_model.py
  python scripts/upload_asr_model.py --source D:\\AI\\sherpa-onnx\\sherpa-th\\active-int8 \
      --version sherpa-onnx-zipformer-thai-2024-06-20-int8
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import sys
import urllib.parse
import urllib.request

DEFAULT_SOURCE = pathlib.Path(r"D:\AI\sherpa-onnx\sherpa-th\active-int8")
DEFAULT_VERSION = "sherpa-onnx-zipformer-thai-2024-06-20-int8"
DEFAULT_BUCKET = "mission-app-b29ed.firebasestorage.app"
REQUIRED_FILES = ["tokens.txt", "encoder.int8.onnx", "decoder.int8.onnx", "joiner.int8.onnx"]


def _firebase_access_token() -> str:
    import os
    home = pathlib.Path(os.environ.get("USERPROFILE") or os.environ.get("HOME") or "")
    config_path = home / ".config" / "configstore" / "firebase-tools.json"
    data = json.loads(config_path.read_text(encoding="utf-8"))
    return data["tokens"]["access_token"]


def _sha256_and_size(path: pathlib.Path) -> tuple[str, int]:
    h = hashlib.sha256()
    size = 0
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
            size += len(chunk)
    return h.hexdigest(), size


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


def _upload_file(token: str, bucket: str, object_name: str, path: pathlib.Path) -> None:
    print(f"  uploading {path.name} -> gs://{bucket}/{object_name} ({path.stat().st_size:,} bytes)")
    with path.open("rb") as f:
        data = f.read()
    _upload_object(token, bucket, object_name, data, "application/octet-stream")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--source", type=pathlib.Path, default=DEFAULT_SOURCE)
    p.add_argument("--version", default=DEFAULT_VERSION)
    p.add_argument("--bucket", default=DEFAULT_BUCKET)
    args = p.parse_args()

    for name in REQUIRED_FILES:
        if not (args.source / name).exists():
            print(f"[ERROR] required model file missing: {args.source / name}")
            return 2

    print(f"== computing checksums (source: {args.source}) ==")
    files_meta = []
    total_bytes = 0
    for name in REQUIRED_FILES:
        path = args.source / name
        digest, size = _sha256_and_size(path)
        files_meta.append({"name": name, "size": size, "sha256": digest})
        total_bytes += size
        print(f"  {name}: {size:,} bytes  sha256={digest}")

    manifest = {
        "modelVersion": args.version,
        "files": files_meta,
        "totalBytes": total_bytes,
    }

    token = _firebase_access_token()
    prefix = f"asr_models/{args.version}"

    print(f"\n== uploading to gs://{args.bucket}/{prefix}/ ==")
    for name in REQUIRED_FILES:
        _upload_file(token, args.bucket, f"{prefix}/{name}", args.source / name)

    print("  uploading manifest.json")
    _upload_object(
        token, args.bucket, f"{prefix}/manifest.json",
        json.dumps(manifest, indent=2).encode("utf-8"),
        "application/json",
    )

    print(f"\n[OK] uploaded {len(REQUIRED_FILES)} model files + manifest.json")
    print(f"     total size: {total_bytes:,} bytes (~{total_bytes / 1024 / 1024:.1f} MB)")
    print(f"     storage path: asr_models/{args.version}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
