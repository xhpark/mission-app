#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import json
import pathlib
import subprocess
import sys
import time


def _load_manifest(path: pathlib.Path) -> dict:
    if not path.exists():
        raise RuntimeError(f"manifest not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def _build_manifest_if_needed(manifest_path: pathlib.Path, source_path: pathlib.Path) -> None:
    if manifest_path.exists():
        return
    script = pathlib.Path(__file__).with_name("build_audio_manifest.py")
    result = subprocess.run(
        [sys.executable, str(script), "--source", str(source_path), "--out", str(manifest_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stdout.strip() or result.stderr.strip())


async def _synthesize_edge_tts(items: list[dict], out_dir: pathlib.Path) -> tuple[int, int, int]:
    try:
        import edge_tts  # type: ignore
    except Exception as e:
        raise RuntimeError("edge-tts 패키지가 필요합니다. pip install edge-tts") from e

    generated = 0
    skipped = 0
    failed = 0
    for item in items:
        target = out_dir / item["audioPath"]
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            skipped += 1
            continue
        text = (item.get("text") or "").strip() or (item.get("fallbackText") or "").strip()
        if not text:
            skipped += 1
            continue
        voice = item.get("voice") or "th-TH-NiwatNeural"
        success = False
        for attempt in range(1, 4):
            try:
                communicate = edge_tts.Communicate(text=text, voice=voice)
                await communicate.save(str(target))
                success = True
                break
            except Exception:
                if attempt < 3:
                    time.sleep(attempt * 0.8)
        if success:
            generated += 1
        else:
            failed += 1
            print(f"[WARN] failed: {item.get('id')} ({voice})")
    return generated, skipped, failed


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate TTS audio assets from manifest.")
    parser.add_argument(
        "--manifest",
        type=pathlib.Path,
        default=pathlib.Path("dist/audio_manifest.json"),
    )
    parser.add_argument(
        "--source",
        type=pathlib.Path,
        default=pathlib.Path("lib/features/learning_content/data/thai_learning_content.dart"),
    )
    parser.add_argument(
        "--out-dir",
        type=pathlib.Path,
        default=pathlib.Path("dist/audio"),
    )
    parser.add_argument(
        "--engine",
        choices=["edge-tts"],
        default="edge-tts",
        help="TTS engine",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="실제 오디오 파일 생성 실행. 생략 시 dry-run",
    )
    args = parser.parse_args()

    try:
        _build_manifest_if_needed(args.manifest, args.source)
        manifest = _load_manifest(args.manifest)
    except Exception as e:
        print(f"[ERROR] {e}")
        return 1

    items = manifest.get("items", [])
    if not isinstance(items, list) or not items:
        print("[ERROR] manifest items is empty")
        return 1

    args.out_dir.mkdir(parents=True, exist_ok=True)
    existing = 0
    missing = 0
    for item in items:
        target = args.out_dir / item["audioPath"]
        if target.exists():
            existing += 1
        else:
            missing += 1

    if not args.execute:
        print(
            "[OK] dry-run complete: "
            f"total={len(items)}, existing={existing}, missing={missing}, "
            f"manifest={args.manifest}, out={args.out_dir}"
        )
        print("[INFO] 실제 생성 실행: --execute")
        return 0

    try:
        generated, skipped, failed = asyncio.run(_synthesize_edge_tts(items, args.out_dir))
    except Exception as e:
        print(f"[ERROR] synthesis failed: {e}")
        return 1

    print(
        "[OK] synthesis complete: "
        f"generated={generated}, skipped={skipped}, failed={failed}, total={len(items)}, out={args.out_dir}"
    )
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
