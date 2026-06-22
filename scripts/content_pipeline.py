#!/usr/bin/env python3
"""Content update pipeline for Thai learning content.

Single entry point that runs the *mechanical* steps required after editing the
single source of truth
(`lib/features/learning_content/data/thai_learning_content.dart`):

  1. counts   - print current sentence/word counts per category (baseline check)
  2. manifest - regenerate the server manifest (functions/src/generated/...ts)
  3. audio    - TTS-generate any MISSING audio and copy it into the app's
                asset dirs (closes the dist/ -> assets/ path gap)
  4. test     - run the contract + drift tests
  5. all      - counts -> manifest -> audio -> test (default)

It deliberately does NOT edit the Dart content or the hardcoded test baselines:
those are human judgement calls (see docs_content_update_checklist_2026-06-22.md).

Usage:
  python scripts/content_pipeline.py            # all (dry audio: only reports missing)
  python scripts/content_pipeline.py --execute  # all, actually generate+copy audio
  python scripts/content_pipeline.py counts
  python scripts/content_pipeline.py manifest
  python scripts/content_pipeline.py audio --execute
  python scripts/content_pipeline.py test
"""
from __future__ import annotations

import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "lib/features/learning_content/data/thai_learning_content.dart"
MANIFEST_TOOL = "tool/build_content_manifest.dart"
DIST_AUDIO = ROOT / "dist/audio/audio"          # TTS writes here (audio/sentences, audio/words)
ASSET_SENTENCE = ROOT / "assets/audio/sentence"  # app reads here (singular)
ASSET_WORD = ROOT / "assets/audio/word"
CONTRACT_TEST = "test/learning_content_contract_test.dart"
DRIFT_TEST = "test/content_manifest_drift_test.dart"


def _run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    print(f"  $ {' '.join(cmd)}")
    # On Windows, dart/flutter/python launchers are .bat shims that the bare
    # CreateProcess cannot resolve; run through the shell so PATHEXT applies.
    return subprocess.run(cmd, cwd=ROOT, shell=(os.name == "nt"), **kw)


def _count_categories(region: str) -> dict[str, int]:
    """Count `category: '...'` literals in a list region (matches wordsByCategory)."""
    out: dict[str, int] = {}
    for cat in re.findall(r"category:\s*'(daily|mission)'", region):
        out[cat] = out.get(cat, 0) + 1
    return out


def cmd_counts() -> int:
    print("== content counts (source of truth) ==")
    text = SOURCE.read_text(encoding="utf-8")
    s_start = text.find("const thaiSentenceContents")
    w_start = text.find("const thaiWordContents")
    sentence_region = text[s_start:w_start]
    # word list ends at the first top-level helper after the const list
    w_end = text.find("\nList<ThaiSentenceContent> sentencesByCategory", w_start)
    word_region = text[w_start:(w_end if w_end != -1 else len(text))]
    for kind, region in (("sentence", sentence_region), ("word", word_region)):
        per = _count_categories(region)
        total = sum(per.values())
        detail = ", ".join(f"{c}={n}" for c, n in sorted(per.items()))
        print(f"  {kind:8s}: total={total}  ({detail})")
    print("  -> update test/learning_content_contract_test.dart baselines if these changed.")
    return 0


def cmd_manifest(check: bool = False) -> int:
    print("== regenerate server manifest ==")
    args = ["dart", "run", MANIFEST_TOOL] + (["--check"] if check else [])
    return _run(args).returncode


def _copy_generated(src_dir: pathlib.Path, dst_dir: pathlib.Path) -> int:
    if not src_dir.exists():
        return 0
    dst_dir.mkdir(parents=True, exist_ok=True)
    copied = 0
    for mp3 in src_dir.glob("*.mp3"):
        dst = dst_dir / mp3.name
        if not dst.exists():
            shutil.copy2(mp3, dst)
            copied += 1
    return copied


def cmd_audio(execute: bool) -> int:
    print("== audio (TTS generate missing + copy into assets) ==")
    # generate_tts_audio.py only rebuilds the audio manifest when it is missing,
    # so a stale dist manifest would hide newly added items. Force a rebuild.
    stale = ROOT / "dist/audio_manifest.json"
    if stale.exists():
        stale.unlink()
    gen = ["python", "scripts/generate_tts_audio.py"]
    if execute:
        gen.append("--execute")
    rc = _run(gen).returncode
    if rc != 0:
        print("  [ERROR] TTS step failed")
        return rc
    if not execute:
        print("  (dry-run: re-run with --execute to actually synthesize)")
        return 0
    s = _copy_generated(DIST_AUDIO / "sentences", ASSET_SENTENCE)
    w = _copy_generated(DIST_AUDIO / "words", ASSET_WORD)
    print(f"  copied {s} sentence + {w} word mp3 into assets/audio/")
    return 0


def cmd_test() -> int:
    print("== contract + drift tests ==")
    return _run(["flutter", "test", CONTRACT_TEST, DRIFT_TEST]).returncode


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("step", nargs="?", default="all",
                   choices=["all", "counts", "manifest", "audio", "test", "check"])
    p.add_argument("--execute", action="store_true", help="actually synthesize/copy audio")
    a = p.parse_args()

    if a.step == "counts":
        return cmd_counts()
    if a.step == "manifest":
        return cmd_manifest()
    if a.step == "check":
        return cmd_manifest(check=True)
    if a.step == "audio":
        return cmd_audio(a.execute)
    if a.step == "test":
        return cmd_test()

    # all
    cmd_counts()
    if cmd_manifest() != 0:
        return 1
    if cmd_audio(a.execute) != 0:
        return 1
    return cmd_test()


if __name__ == "__main__":
    sys.exit(main())
