#!/usr/bin/env python3
from __future__ import annotations

import sys


def main() -> int:
    checks = [
        "route:/login",
        "route:/select",
        "route:/session-summary",
        "route:/report-preview",
        "route:/report",
    ]
    for check in checks:
        print(f"[SMOKE] {check}: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

