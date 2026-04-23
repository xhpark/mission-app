#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys


def _run_validation(input_path: pathlib.Path) -> None:
    script = pathlib.Path(__file__).with_name("validate_sheet_data.py")
    result = subprocess.run(
        [sys.executable, str(script), str(input_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stdout.strip() or result.stderr.strip())


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate content draft json from sheet.")
    parser.add_argument("input", type=pathlib.Path, help="Input spreadsheet path")
    parser.add_argument("--out", type=pathlib.Path, default=pathlib.Path("content_draft.json"))
    args = parser.parse_args()

    if not args.input.exists():
        print(f"[ERROR] input not found: {args.input}")
        return 1

    try:
        _run_validation(args.input)
    except Exception as e:
        print(f"[ERROR] validation failed: {e}")
        return 1

    payload = {
        "source": str(args.input),
        "status": "draft",
        "sentences": [],
        "words": [],
        "meta": {
            "generatedBy": "generate_content_draft.py",
        },
    }
    args.out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[OK] draft generated: {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

