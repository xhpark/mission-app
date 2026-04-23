#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import shutil
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description="Build deployable content bundle.")
    parser.add_argument("draft_json", type=pathlib.Path, help="Draft json path")
    parser.add_argument("--out", type=pathlib.Path, default=pathlib.Path("dist/content_bundle.json"))
    args = parser.parse_args()

    if not args.draft_json.exists():
        print(f"[ERROR] draft not found: {args.draft_json}")
        return 1

    args.out.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.draft_json, args.out)
    print(f"[OK] bundle built: {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

