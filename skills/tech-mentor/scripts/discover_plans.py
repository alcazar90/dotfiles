#!/usr/bin/env python3
"""List plan files in the current directory, for auto-injected context.

Looks for the default `plan.yaml` plus any `*.plan.yaml` siblings — the
naming convention for a second, differently-scoped plan in the same
directory (e.g. a monorepo package discussing more than one topic).
"""
import glob
import sys

try:
    import yaml
except ImportError:
    sys.exit("Missing pyyaml. Install with: pip install pyyaml")

MAX_LISTED = 8


def summarize(path):
    try:
        with open(path) as f:
            p = yaml.safe_load(f) or {}
    except Exception:
        return None
    title = p.get("title", "untitled")
    version = p.get("version", "?")
    updated = p.get("last_updated", "?")
    n = len(p.get("contributions", []))
    return f'  - {path} — "{title}" v{version} ({n} contributions, updated {updated})'


def main():
    paths = sorted(set(glob.glob("plan.yaml") + glob.glob("*.plan.yaml")))
    if not paths:
        print("No plans found - starting fresh.")
        return

    print("=== PLANS IN THIS DIRECTORY ===")
    for path in paths[:MAX_LISTED]:
        line = summarize(path)
        if line:
            print(line)
    if len(paths) > MAX_LISTED:
        print(f"  ...and {len(paths) - MAX_LISTED} more")
    print("(Refine one with --refine PATH, or start a new one with --plan PATH)")
    print("=== END ===")


if __name__ == "__main__":
    main()
