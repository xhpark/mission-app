#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description="Export admin review report.")
    parser.add_argument("--out", type=pathlib.Path, default=pathlib.Path("dist/admin_report.csv"))
    args = parser.parse_args()

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("report_id,user_id,session_id,submitted_at\n", encoding="utf-8")
    print(f"[OK] admin report exported: {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

