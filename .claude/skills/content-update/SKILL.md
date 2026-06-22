---
name: content-update
description: Use when adding, removing, or changing Thai learning sentences or words in mission_app (edits to lib/features/learning_content/data/thai_learning_content.dart), or when the content manifest / contract tests / audio assets need to be kept in sync after a content change.
---

# Content Update (mission_app)

## Overview

All Thai learning content lives in ONE source of truth:
`lib/features/learning_content/data/thai_learning_content.dart`
(`thaiSentenceContents`, `thaiWordContents`). Editing it ripples into 6 learning
modes, the server manifest, audio assets, and hardcoded test baselines. This
skill runs the mechanical sync via `scripts/content_pipeline.py` and flags the
human-judgement steps.

Full rationale + per-change-type impact: `docs_content_update_checklist_2026-06-22.md`.

## When to use

- Adding/removing/changing a sentence (`THS_*`) or word (`THW_*`).
- Contract test failing on `*.length` baselines after a content edit.
- "Content manifest is out of date" drift error.
- Missing audio asset for a new item.

## Invariants the contract test enforces (do not skip)

1. **Count baselines are hardcoded** in `test/learning_content_contract_test.dart`
   (daily/mission sentence + word counts). Update them by hand after a change.
2. **orderNo contiguous 1..N per category** — add = max+1; remove = renumber the rest.
3. **Every sentence needs ≥1 word** whose `linkedSentenceIds` includes it
   (same category only — no cross-category links).
4. **Audio file must physically exist**: `assets/audio/sentence/<id>.mp3`,
   `assets/audio/word/<id>.mp3`. Leave `audioPath` empty in the Dart entry
   (it auto-resolves from the id).

## Workflow

```
1. Edit thai_learning_content.dart (content authoring — human)
2. python scripts/content_pipeline.py counts        # read new counts
3. Update the count baselines in the contract test   # human judgement
4. python scripts/content_pipeline.py manifest        # regen server manifest
5. python scripts/content_pipeline.py audio --execute # TTS + copy into assets/
6. python scripts/content_pipeline.py test            # contract + drift tests
7. flutter analyze
8. firebase deploy --only functions                   # manifest is bundled here
9. Rebuild release APK -> redistribute (testers need the new bundle)
10. git commit + push
```

`python scripts/content_pipeline.py` with no arg runs counts → manifest → audio(dry) → test.
Add `--execute` to actually synthesize+copy audio. Run `--help` for individual steps.

## What stays manual (do not automate away)

- **Thai text / pronunciation** authoring (native review recommended).
- **Count baseline edits** — an intentional tripwire; confirm then edit.
- **Native audio** — TTS voice is `th-TH-NiwatNeural` (synthetic). Swap in real
  recordings by overwriting the same `assets/audio/.../<id>.mp3` filename.
- **Redistribution** — content + audio are bundled into the app build.

## Common mistakes

- Forgetting to update the count baselines → contract test fails (expected;
  `counts` tells you the new numbers).
- Adding a sentence with no linked word → contract test fails.
- Relying on TTS output in `dist/` — it must be copied to `assets/audio/`
  (singular dirs); the pipeline's `audio` step does this.
- Skipping `firebase deploy --only functions` → server grades with the old
  manifest (wrong item counts / expectedText).
