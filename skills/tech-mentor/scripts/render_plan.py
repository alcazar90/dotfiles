#!/usr/bin/env python3
"""
render_plan.py — deterministic renderer for tech-mentor plan.yaml

Takes the single structured plan (contributions array) and projects it into
one of three markdown views. This script NEVER writes or rewrites prose —
it only reorders, groups, and wraps existing `body` text in markdown
scaffolding (headers, attribution lines, separators). All reasoning content
comes from the YAML as written by the mentor persona.

Usage:
    python3 render_plan.py plan.yaml --format annotated
    python3 render_plan.py plan.yaml --format dialogue
    python3 render_plan.py plan.yaml --format unified
    python3 render_plan.py plan.yaml --format annotated --component calibration_module
"""
import argparse
import sys
from collections import defaultdict

try:
    import yaml
except ImportError:
    sys.exit("Missing pyyaml. Install with: pip install pyyaml")


def load_plan(path):
    with open(path) as f:
        return yaml.safe_load(f)


def mentor_name(plan, mentor_id):
    for m in plan["mentors"]:
        if m["id"] == mentor_id:
            return m["name"]
    return mentor_id


def component_title(plan, comp_id):
    for c in plan["components"]:
        if c["id"] == comp_id:
            return c["title"]
    return comp_id


def frontmatter(plan):
    lines = ["---"]
    lines.append(f'title: "{plan["title"]}"')
    lines.append("mentors:")
    for m in plan["mentors"]:
        lines.append(f'  - name: "{m["name"]}"')
        lines.append(f'    focus: "{m["focus"]}"')
    lines.append(f'version: {plan["version"]}')
    lines.append(f'last_updated: "{plan["last_updated"]}"')
    lines.append("---\n")
    return "\n".join(lines)


def header(plan):
    return f'# {plan["title"]}\n'


def filter_contributions(plan, component=None):
    cs = plan["contributions"]
    if component:
        cs = [c for c in cs if c["component"] == component]
    return cs


# ---------------------------------------------------------------------------
# ANNOTATED — group by component, sort by version within each group
# ---------------------------------------------------------------------------
def render_annotated(plan, component=None):
    out = [frontmatter(plan), header(plan)]
    by_component = defaultdict(list)
    for c in filter_contributions(plan, component):
        by_component[c["component"]].append(c)

    for comp_id, contributions in by_component.items():
        out.append(f'## {component_title(plan, comp_id)}\n')
        contributions.sort(key=lambda c: c["version"])
        for i, c in enumerate(contributions):
            name = mentor_name(plan, c["mentor"])
            tag = f"**[{name} - v{c['version']}]**" if i == 0 else \
                  f"**[{name} - v{c['version']}, {c['type']} on prior work]**"
            out.append(tag + "\n")
            out.append(c["body"].strip() + "\n")
            if i < len(contributions) - 1:
                out.append("---\n")
        out.append("")
    return "\n".join(out)


# ---------------------------------------------------------------------------
# DIALOGUE — chronological by version, threaded by in_reply_to
# ---------------------------------------------------------------------------
def render_dialogue(plan, component=None):
    out = [frontmatter(plan), header(plan)]
    by_component = defaultdict(list)
    for c in filter_contributions(plan, component):
        by_component[c["component"]].append(c)

    by_id = {c["id"]: c for c in plan["contributions"]}

    for comp_id, contributions in by_component.items():
        out.append(f'### Thread: {component_title(plan, comp_id)}\n')
        contributions.sort(key=lambda c: c["version"])
        for c in contributions:
            name = mentor_name(plan, c["mentor"])
            if c["in_reply_to"] and c["in_reply_to"] in by_id:
                target = mentor_name(plan, by_id[c["in_reply_to"]]["mentor"])
                tag = f"**{name} - v{c['version']}, → {target} on {c['summary']}:**"
            else:
                tag = f"**{name} - v{c['version']}:**"
            out.append(tag)
            out.append(c["body"].strip() + "\n")
        out.append("---\n")
    return "\n".join(out)


# ---------------------------------------------------------------------------
# UNIFIED — group by component, fuse by type (proposal first, then
# extension, then challenge), attribution dropped, prose ordered not merged
# (merging prose is an inference task, not a rendering task — left as TODO
# marker for a human/LLM pass, never silently fabricated)
# ---------------------------------------------------------------------------
TYPE_ORDER = {"proposal": 0, "extension": 1, "challenge": 2, "response": 3}


def render_unified(plan, component=None):
    out = [frontmatter(plan), header(plan)]
    by_component = defaultdict(list)
    for c in filter_contributions(plan, component):
        by_component[c["component"]].append(c)

    for comp_id, contributions in by_component.items():
        out.append(f'## {component_title(plan, comp_id)}\n')
        contributions.sort(key=lambda c: (TYPE_ORDER.get(c["type"], 9), c["version"]))
        for c in contributions:
            focus = next(m["focus"] for m in plan["mentors"] if m["id"] == c["mentor"])
            out.append(f"*From {focus}:*\n")
            out.append(c["body"].strip() + "\n")
        out.append("")
    return "\n".join(out)


RENDERERS = {
    "annotated": render_annotated,
    "dialogue": render_dialogue,
    "unified": render_unified,
}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("plan", help="path to plan.yaml")
    p.add_argument("--format", choices=RENDERERS.keys(), default="annotated")
    p.add_argument("--component", default=None, help="filter to a single component id")
    p.add_argument("-o", "--output", default=None, help="write to file instead of stdout")
    args = p.parse_args()

    plan = load_plan(args.plan)
    text = RENDERERS[args.format](plan, component=args.component)

    if args.output:
        with open(args.output, "w") as f:
            f.write(text)
        print(f"wrote {args.output}", file=sys.stderr)
    else:
        print(text)


if __name__ == "__main__":
    main()
