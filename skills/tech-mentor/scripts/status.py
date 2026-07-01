#!/usr/bin/env python3
"""Print a compact summary of plan.yaml for context injection."""
import sys

try:
    import yaml
except ImportError:
    sys.exit("Missing pyyaml. Install with: pip install pyyaml")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "plan.yaml"
    try:
        with open(path) as f:
            p = yaml.safe_load(f)
    except FileNotFoundError:
        print("No previous plan found - starting fresh.")
        return

    cs = p.get("contributions", [])
    mentors = {m["id"]: m["name"] for m in p.get("mentors", [])}
    comps = {c["id"]: c["title"] for c in p.get("components", [])}
    resolved = {c.get("resolves") for c in cs if c.get("resolves")}
    challenges = [c for c in cs if c["type"] == "challenge" and c["id"] not in resolved]

    comp_counts = {}
    for c in cs:
        comp_counts[c["component"]] = comp_counts.get(c["component"], 0) + 1

    print("=== PREVIOUS PLAN EXISTS ===")
    print(f"Title: {p['title']}")
    print(f"Version: {p['version']} | Updated: {p['last_updated']}")
    print(f"Mentors: {', '.join(mentors.values())}")
    print(f"Components ({len(comps)}):")
    for cid, title in comps.items():
        print(f"  - {title} [{cid}] ({comp_counts.get(cid, 0)} contributions)")
    print(f"Contributions: {len(cs)} total, {len(challenges)} open challenge(s)")
    for ch in challenges:
        print(f"  - [{ch['id']}] {ch['summary']}")
    print()
    print("(Full plan.yaml on disk — read it or use --component ID to focus)")
    print("=== END PLAN SUMMARY ===")


if __name__ == "__main__":
    main()
