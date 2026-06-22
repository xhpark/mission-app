#!/usr/bin/env python3
"""Generate a single sentence audio file that plays the male pronunciation
followed by the female pronunciation, for sentences whose Thai text mixes
both genders' wording (e.g. "ผม/ดิฉันชื่อ ... (ครับ/ค่ะ)").

Why this exists: feeding the literal slash/parenthesis text straight into TTS
produces a single garbled clip that reads the punctuation aloud (confirmed:
~2.8s vs ~1.8s for a clean phrase) instead of two understandable phrases.
This generates the two phrases separately (male voice, female voice) and
concatenates them with a short pause into ONE file, so the sentence stays a
single catalog item but is actually learnable by ear.

Usage:
  python scripts/generate_gendered_sentence_audio.py \
    --id THS_D016 --male "ผมชื่อ ... ครับ" --female "ดิฉันชื่อ ... ค่ะ" \
    --kind sentence
"""
from __future__ import annotations

import argparse
import asyncio
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MALE_VOICE = "th-TH-NiwatNeural"
FEMALE_VOICE = "th-TH-PremwadeeNeural"
GAP_MS = 400


async def _synth(text: str, voice: str, out_path: pathlib.Path) -> None:
    import edge_tts
    await edge_tts.Communicate(text=text, voice=voice).save(str(out_path))


def _concat(male_mp3: pathlib.Path, female_mp3: pathlib.Path, out_path: pathlib.Path) -> None:
    silence = ROOT / "tmp_gendered_audio_silence.mp3"
    subprocess.run([
        "ffmpeg", "-y", "-f", "lavfi", "-i",
        f"anullsrc=r=24000:cl=mono:d={GAP_MS / 1000}",
        "-q:a", "9", str(silence),
    ], check=True, capture_output=True)

    list_file = ROOT / "tmp_gendered_audio_concat.txt"
    list_file.write_text(
        "\n".join(f"file '{p.resolve().as_posix()}'" for p in (male_mp3, silence, female_mp3)),
        encoding="utf-8",
    )
    subprocess.run([
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(list_file),
        "-c", "copy", str(out_path),
    ], check=True, capture_output=True)
    list_file.unlink(missing_ok=True)
    silence.unlink(missing_ok=True)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--id", required=True, help="item id, e.g. THS_D016")
    p.add_argument("--male", required=True, help="male-voiced Thai phrase")
    p.add_argument("--female", required=True, help="female-voiced Thai phrase")
    p.add_argument("--kind", choices=["sentence", "word"], default="sentence")
    a = p.parse_args()

    out_dir = ROOT / f"assets/audio/{a.kind}"
    out_dir.mkdir(parents=True, exist_ok=True)
    male_tmp = ROOT / f"tmp_gendered_audio_male_{a.id}.mp3"
    female_tmp = ROOT / f"tmp_gendered_audio_female_{a.id}.mp3"
    out_path = out_dir / f"{a.id}.mp3"

    asyncio.run(_synth(a.male, MALE_VOICE, male_tmp))
    asyncio.run(_synth(a.female, FEMALE_VOICE, female_tmp))
    _concat(male_tmp, female_tmp, out_path)
    male_tmp.unlink(missing_ok=True)
    female_tmp.unlink(missing_ok=True)

    print(f"[OK] wrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
