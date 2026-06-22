#!/usr/bin/env python3
from __future__ import annotations

import argparse
import codecs
import json
import pathlib
import re
import sys


def _decode_dart_string(value: str) -> str:
    # Entries may be written either as raw UTF-8 (e.g. 'สวัสดี') or as \uXXXX
    # escapes. Raw non-ASCII is already correct; only ASCII-with-escapes needs
    # decoding (and unicode_escape on raw UTF-8 would corrupt it).
    if not value.isascii():
        return value
    try:
        return codecs.decode(value, "unicode_escape")
    except Exception:
        return value


def _field(block: str, name: str) -> str:
    pattern = rf"{name}\s*:\s*'((?:\\'|[^'])*)'"
    match = re.search(pattern, block, re.DOTALL)
    return _decode_dart_string(match.group(1)) if match else ""


def _parse_blocks(text: str, ctor: str) -> list[str]:
    pattern = rf"{ctor}\((.*?)\),"
    return re.findall(pattern, text, re.DOTALL)


def build_manifest(source: pathlib.Path) -> dict:
    text = source.read_text(encoding="utf-8")
    manifest_items: list[dict] = []

    sentence_blocks = _parse_blocks(text, "ThaiSentenceContent")
    for block in sentence_blocks:
        item_id = _field(block, "id")
        if not item_id or not item_id.startswith("THS_"):
            continue
        manifest_items.append(
            {
                "id": item_id,
                "kind": "sentence",
                "category": _field(block, "category"),
                "text": _field(block, "thaiText"),
                "fallbackText": _field(block, "koreanText"),
                "audioPath": f"audio/sentences/{item_id}.mp3",
                "audioUrl": f"https://storage.googleapis.com/mission-app-audio/sentences/{item_id}.mp3",
                "voice": "th-TH-NiwatNeural",
            }
        )

    word_blocks = _parse_blocks(text, "ThaiWordContent")
    for block in word_blocks:
        item_id = _field(block, "id")
        if not item_id or not item_id.startswith("THW_"):
            continue
        manifest_items.append(
            {
                "id": item_id,
                "kind": "word",
                "category": _field(block, "category"),
                "text": _field(block, "thaiWord"),
                "fallbackText": _field(block, "koreanMeaning"),
                "audioPath": f"audio/words/{item_id}.mp3",
                "audioUrl": f"https://storage.googleapis.com/mission-app-audio/words/{item_id}.mp3",
                "voice": "th-TH-NiwatNeural",
            }
        )

    sentence_count = sum(1 for x in manifest_items if x["kind"] == "sentence")
    word_count = sum(1 for x in manifest_items if x["kind"] == "word")
    return {
        "version": 1,
        "source": str(source),
        "summary": {
            "total": len(manifest_items),
            "sentences": sentence_count,
            "words": word_count,
        },
        "items": manifest_items,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build audio manifest from thai_learning_content.dart")
    parser.add_argument(
        "--source",
        type=pathlib.Path,
        default=pathlib.Path("lib/features/learning_content/data/thai_learning_content.dart"),
    )
    parser.add_argument(
        "--out",
        type=pathlib.Path,
        default=pathlib.Path("dist/audio_manifest.json"),
    )
    args = parser.parse_args()

    if not args.source.exists():
        print(f"[ERROR] source not found: {args.source}")
        return 1

    manifest = build_manifest(args.source)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    summary = manifest["summary"]
    print(
        "[OK] manifest generated: "
        f"{args.out} (total={summary['total']}, sentences={summary['sentences']}, words={summary['words']})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
