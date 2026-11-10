#!/usr/bin/env python3
"""Write corpus inventory rows into results/measurements.csv.

These rows are file facts, not device performance. Runtime benchmark rows
are appended only by a person who ran scripts/device_benchmark.md.
"""

from __future__ import annotations

import csv
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "test_books" / "corpus_manifest.json"
OUT = ROOT / "results" / "measurements.csv"
STAMP = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

HEADER = [
    "engine",
    "device",
    "epub",
    "scenario",
    "run_id",
    "measurement",
    "value",
    "unit",
    "timestamp",
    "method",
    "notes",
]


def main() -> None:
    books = json.loads(MANIFEST.read_text(encoding="utf-8"))["books"]
    rows = []
    for book in books:
        common = {
            "engine": "corpus",
            "device": "none",
            "epub": book["id"],
            "scenario": "corpus-inventory",
            "run_id": "generated",
            "timestamp": STAMP,
            "method": "experiments/reader_lab/scripts/generate_corpus.py",
            "notes": "fixture fact, not a runtime benchmark",
        }
        rows.append({**common, "measurement": "size", "value": book["sizeBytes"], "unit": "byte"})
        rows.append(
            {
                **common,
                "measurement": "spine_item_count",
                "value": book["spineItemCount"],
                "unit": "count",
            }
        )
        rows.append(
            {
                **common,
                "measurement": "sha256",
                "value": book["sha256"],
                "unit": "hex",
            }
        )
    apk_notes = "debug APK byte size on the build host; not installed and not a device memory sample"
    for engine, relative in (
        (
            "reader_lab",
            ROOT / "build" / "app" / "outputs" / "flutter-apk" / "app-debug.apk",
        ),
        (
            "readium_lab",
            ROOT
            / "engines"
            / "flutter_readium_app"
            / "build"
            / "app"
            / "outputs"
            / "flutter-apk"
            / "app-debug.apk",
        ),
    ):
        if relative.exists():
            rows.append(
                {
                    "engine": engine,
                    "device": "build-host",
                    "epub": "none",
                    "scenario": "android-debug-compile",
                    "run_id": "1",
                    "measurement": "debug_apk_size",
                    "value": relative.stat().st_size,
                    "unit": "byte",
                    "timestamp": STAMP,
                    "method": "flutter build apk --debug",
                    "notes": apk_notes,
                }
            )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=HEADER)
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {len(rows)} rows to {OUT}")


if __name__ == "__main__":
    main()
