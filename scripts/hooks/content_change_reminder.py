#!/usr/bin/env python3
"""PostToolUse hook: remind to run the content sync pipeline when the single
source of truth (thai_learning_content.dart) is edited.

Reads the hook payload JSON on stdin; if the edited file is the content source,
prints a JSON reminder that Claude Code surfaces to the user / model. Otherwise
prints nothing and exits 0 (no-op for every other edit).
"""
import json
import sys

TARGET = "thai_learning_content.dart"

REMINDER = (
    "Content source edited (thai_learning_content.dart). Sync required:\n"
    "  1) python scripts/content_pipeline.py counts   # new counts\n"
    "  2) update count baselines in test/learning_content_contract_test.dart\n"
    "  3) python scripts/content_pipeline.py manifest  # regen server manifest\n"
    "  4) python scripts/content_pipeline.py audio --execute  # TTS + copy to assets\n"
    "  5) python scripts/content_pipeline.py test\n"
    "  6) firebase deploy --only functions; rebuild + redistribute app\n"
    "Details: docs_content_update_checklist_2026-06-22.md / skill 'content-update'."
)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0
    fp = str(((payload or {}).get("tool_input") or {}).get("file_path") or "")
    if not fp.replace("\\", "/").endswith(TARGET):
        return 0
    print(json.dumps({
        "systemMessage": "📚 " + REMINDER,
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": REMINDER,
        },
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
