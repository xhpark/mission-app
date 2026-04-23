#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
import sys


def _load_manifest(path: pathlib.Path) -> dict:
    if not path.exists():
        raise RuntimeError(f"manifest not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def _default_bucket_from_firebase_options(project_root: pathlib.Path) -> str:
    options = project_root / "lib" / "firebase_options.dart"
    if not options.exists():
        return ""
    text = options.read_text(encoding="utf-8")
    marker = "storageBucket: '"
    idx = text.find(marker)
    if idx < 0:
        return ""
    start = idx + len(marker)
    end = text.find("'", start)
    if end < 0:
        return ""
    return text[start:end].strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Upload generated audio assets to Firebase Storage.")
    parser.add_argument(
        "--audio-root",
        type=pathlib.Path,
        default=pathlib.Path("dist/audio"),
        help="root directory containing generated files",
    )
    parser.add_argument(
        "--manifest",
        type=pathlib.Path,
        default=pathlib.Path("dist/audio_manifest.json"),
        help="manifest path",
    )
    parser.add_argument(
        "--bucket",
        default="",
        help="target bucket. empty means auto-detect from firebase_options.dart",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="perform actual upload. if omitted, dry-run only",
    )
    args = parser.parse_args()

    try:
        manifest = _load_manifest(args.manifest)
    except Exception as e:
        print(f"[ERROR] {e}")
        return 1

    items = manifest.get("items", [])
    if not isinstance(items, list) or not items:
        print("[ERROR] manifest items is empty")
        return 1

    project_root = pathlib.Path(".").resolve()
    bucket_name = args.bucket.strip() or _default_bucket_from_firebase_options(project_root)
    if not bucket_name:
        print("[ERROR] bucket is empty. use --bucket")
        return 1

    missing_local: list[str] = []
    for item in items:
        local_file = args.audio_root / item["audioPath"]
        if not local_file.exists():
            missing_local.append(str(local_file))

    if missing_local:
        print(f"[ERROR] local audio files missing: {len(missing_local)}")
        for path in missing_local[:20]:
            print(f" - {path}")
        if len(missing_local) > 20:
            print(" - ...")
        return 1

    if not args.execute:
        print(
            "[OK] dry-run complete: "
            f"bucket={bucket_name}, files={len(items)}, root={args.audio_root}"
        )
        print("[INFO] 실제 업로드 실행: --execute")
        return 0

    try:
        from google.cloud import storage  # type: ignore
    except Exception:
        print("[ERROR] google-cloud-storage 패키지가 필요합니다. pip install google-cloud-storage")
        return 1

    try:
        client = storage.Client()
        bucket = client.bucket(bucket_name)
    except Exception as e:
        print(f"[ERROR] failed to initialize storage client: {e}")
        print("[HINT] gcloud auth application-default login 또는 GOOGLE_APPLICATION_CREDENTIALS 설정 필요")
        return 1

    uploaded = 0
    skipped = 0
    for item in items:
        blob_path = item["audioPath"]
        local_file = args.audio_root / blob_path
        blob = bucket.blob(blob_path)
        try:
            if blob.exists(client=client):
                skipped += 1
                continue
            blob.upload_from_filename(str(local_file), content_type="audio/mpeg")
            uploaded += 1
        except Exception as e:
            print(f"[WARN] upload failed: {blob_path} ({e})")

    print(
        "[OK] upload complete: "
        f"uploaded={uploaded}, skipped={skipped}, total={len(items)}, bucket={bucket_name}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

