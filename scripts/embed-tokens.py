#!/usr/bin/env python3
"""Writes a token pool into Secrets.plist for fleet builds with embedded
credentials. Token values are never printed.

Usage: python3 scripts/embed-tokens.py [pool.json]
Pool format: {"tokens": [{"name": "primary", "token": "sk-ant-..."}]}
"""

import json
import plistlib
import sys
from pathlib import Path

DEFAULT_POOL = Path.home() / ".config" / "cutaway" / "token-pool.json"
TARGET = Path(__file__).resolve().parent.parent / "Sources" / "Cutaway" / "Secrets.plist"


def main() -> int:
    pool_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_POOL
    if not pool_path.exists():
        print(f"pool not found: {pool_path}", file=sys.stderr)
        return 1

    pool = json.loads(pool_path.read_text())
    entries = [
        {"name": entry.get("name", f"token{i}"), "token": entry["token"]}
        for i, entry in enumerate(pool.get("tokens", []))
        if entry.get("token")
    ]
    if not entries:
        print("no usable token in the pool", file=sys.stderr)
        return 1

    TARGET.write_bytes(plistlib.dumps({"TOKENS": entries}))
    TARGET.chmod(0o600)
    print("re-run xcodegen generate before building so the file joins the project")
    print(f"embedded {len(entries)} token(s) -> {TARGET.name}")
    for entry in entries:
        print(f"  {entry['name']}: {entry['token'][:12]}… ({len(entry['token'])} chars)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
