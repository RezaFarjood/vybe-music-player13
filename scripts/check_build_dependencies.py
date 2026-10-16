#!/usr/bin/env python3
"""Fail early when the generated dependency resolution is incompatible."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = "6.3.3"
pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
requested = re.search(r"(?m)^\s*google_fonts:\s*['\"]?(\d+\.\d+\.\d+)", pubspec)
if not requested or requested.group(1) != EXPECTED:
    sys.exit(f"ERROR: pubspec.yaml must pin google_fonts exactly to {EXPECTED} (not 6.3.0)")
lockfile = ROOT / "pubspec.lock"
if not lockfile.exists():
    sys.exit("ERROR: pubspec.lock missing. Run flutter pub get before this check.")
lock = lockfile.read_text(encoding="utf-8")
entry = re.search(r"(?ms)^  google_fonts:\s*\n(.*?)(?=^  [a-zA-Z0-9_-]+:|\Z)", lock)
if not entry:
    sys.exit("ERROR: google_fonts missing from resolved pubspec.lock")
version = re.search(r'(?m)^    version:\s*["\']?(\d+\.\d+\.\d+)', entry.group(1))
if not version or version.group(1) != EXPECTED:
    sys.exit(f"ERROR: google_fonts resolved to {version.group(1) if version else 'UNKNOWN'}, expected {EXPECTED}")
print(f"OK: google_fonts {EXPECTED} resolved (Flutter/Dart FontWeight compatibility fix)")
