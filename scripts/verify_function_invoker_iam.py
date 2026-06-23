#!/usr/bin/env python3
"""Verify every callable Cloud Function still has public invoker IAM.

Why this exists (2026-06-23 incident): this project's Cloud Functions are all
declared `onCall(...)` with `setGlobalOptions({ invoker: "public" })` in
functions/src/index.ts, so any authenticated app user can call them; Firebase
Auth (not Cloud Run IAM) is the real authorization boundary, checked in code.

Cloud Functions v2 only applies that `invoker: "public"` setting to the
underlying Cloud Run service's IAM policy when a function is first CREATED.
A later `firebase deploy` that only UPDATES an existing function's code does
not reapply it. Two functions (bootstrapUserSession,
submitOnDeviceSpeakingFallback) silently lost their `roles/run.invoker:
allUsers` binding this way — likely from an earlier deploy of an unrelated
function that, for unknown reasons, also touched their Cloud Run revision —
and started rejecting every request with a Cloud Run-level 401 ("access
token could not be verified"), before the request ever reached our
Firebase-Auth check. There is no error logged by our own code for this
failure mode, only the Cloud Run platform's own log line.

Run after every `firebase deploy --only functions...`:
  python scripts/verify_function_invoker_iam.py            # report only
  python scripts/verify_function_invoker_iam.py --fix      # also repair

Auth: reuses the active `firebase login` access token (same pattern as the
other scripts/ in this repo — no extra Python deps, no service account key).
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request

PROJECT_ID = "mission-app-b29ed"
REGION = "asia-northeast3"
INDEX_TS = pathlib.Path(__file__).resolve().parents[1] / "functions/src/index.ts"


def _access_token() -> str:
    home = pathlib.Path(os.environ.get("USERPROFILE") or os.environ.get("HOME") or "")
    data = json.loads((home / ".config/configstore/firebase-tools.json").read_text(encoding="utf-8"))
    return data["tokens"]["access_token"]


def _list_callable_function_names() -> list[str]:
    text = INDEX_TS.read_text(encoding="utf-8")
    return re.findall(r"export const (\w+) = onCall", text)


def _request(token: str, method: str, url: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return {"_error": e.code, "_body": e.read().decode("utf-8", "replace")}


def _has_public_invoker(policy: dict) -> bool:
    return any(
        b.get("role") == "roles/run.invoker" and "allUsers" in b.get("members", [])
        for b in policy.get("bindings", [])
    )


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--fix", action="store_true", help="grant roles/run.invoker:allUsers to any function missing it")
    args = p.parse_args()

    token = _access_token()
    names = _list_callable_function_names()
    print(f"== checking {len(names)} callable functions in {PROJECT_ID}/{REGION} ==")

    missing = []
    for name in names:
        service = name.lower()
        url = f"https://run.googleapis.com/v2/projects/{PROJECT_ID}/locations/{REGION}/services/{service}:getIamPolicy"
        policy = _request(token, "GET", url)
        if "_error" in policy:
            print(f"  [WARN] {name}: could not read IAM policy ({policy['_error']})")
            continue
        ok = _has_public_invoker(policy)
        print(f"  {name}: {'OK' if ok else 'MISSING public invoker'}")
        if not ok:
            missing.append(name)

    if not missing:
        print("\n[OK] all callable functions have public invoker IAM.")
        return 0

    print(f"\n[ALERT] {len(missing)} function(s) missing public invoker IAM: {', '.join(missing)}")
    if not args.fix:
        print("Re-run with --fix to grant roles/run.invoker:allUsers (matches every other function here).")
        return 1

    for name in missing:
        service = name.lower()
        url = f"https://run.googleapis.com/v2/projects/{PROJECT_ID}/locations/{REGION}/services/{service}:setIamPolicy"
        result = _request(token, "POST", url, {
            "policy": {"bindings": [{"role": "roles/run.invoker", "members": ["allUsers"]}]},
        })
        if "_error" in result:
            print(f"  [FAILED] {name}: {result['_body']}")
        else:
            print(f"  [FIXED] {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
