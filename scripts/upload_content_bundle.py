#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description="Upload content bundle to backend storage.")
    parser.add_argument("bundle", type=pathlib.Path, help="Bundle file path")
    parser.add_argument("--target", default="firebase-storage://content-bundles")
    args = parser.parse_args()

    if not args.bundle.exists():
        print(f"[ERROR] bundle not found: {args.bundle}")
        return 1

    print(f"[OK] upload hook ready: {args.bundle} -> {args.target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

