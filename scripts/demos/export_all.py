"""Exports every demonstration into the app's JSON, and prints any problem left."""
import json
import sys
from pathlib import Path

import build
import demos

OUT = Path(__file__).resolve().parents[2] / "App" / "Resources" / "ExerciseDemos.json"

results, problems = build.build()
missing = [k for k in demos.LIBRARY if k not in results]
if missing:
    print("MISSING", missing)
for ident, probs in problems.items():
    if probs:
        print(ident, "|", "; ".join(probs))
payload = {"version": 1, "demos": results}
OUT.parent.mkdir(parents=True, exist_ok=True)
text = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
OUT.write_text(text, encoding="utf-8")
print("exported", len(results), "size", len(text) // 1024, "KB")
