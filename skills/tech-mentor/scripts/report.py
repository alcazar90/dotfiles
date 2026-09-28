#!/usr/bin/env python3
"""
report.py — terminal-native tree view of plan.yaml contribution DAG

Walks components in declared order and prints each contribution as a reply
chain with ASCII connectors. Designed for scanning, not reading: see where
the disagreement lives and how deep a thread got before deciding where to
point the next mentor.

Usage:
    python3 scripts/report.py [plan.yaml]
    python3 scripts/report.py plan.yaml --component data_model
    python3 scripts/report.py plan.yaml --no-color
"""
import argparse
import os
import sys

try:
    import yaml
except ImportError:
    sys.exit("Missing pyyaml. Install with: pip install pyyaml")

# ---------------------------------------------------------------------------
# ANSI color helpers
# ---------------------------------------------------------------------------
RESET = "\033[0m"
BOLD  = "\033[1m"
DIM   = "\033[2m"

MENTOR_COLORS = {
    "karpathy":          "\033[96m",
    "zhang":             "\033[92m",
    "dean":              "\033[93m",
    "viegas_wattenberg": "\033[95m",
    "pearl":             "\033[94m",
}
_FALLBACK_COLORS = ["\033[36m", "\033[32m", "\033[33m", "\033[35m", "\033[34m"]
_fallback_color_cache: dict[str, str] = {}

USE_COLOR = False


def ansi(text, *codes: str) -> str:
    if not USE_COLOR or not codes:
        return text
    return "".join(codes) + text + RESET


def mentor_ansi(mentor_id: str) -> str:
    if mentor_id in MENTOR_COLORS:
        return MENTOR_COLORS[mentor_id]
    if mentor_id not in _fallback_color_cache:
        _fallback_color_cache[mentor_id] = _FALLBACK_COLORS[
            len(_fallback_color_cache) % len(_FALLBACK_COLORS)
        ]
    return _fallback_color_cache[mentor_id]


def trunc(s: str, n: int) -> str:
    s = s.strip()
    return s[:n].rstrip() + "…" if len(s) > n else s


# ---------------------------------------------------------------------------
# Print plan header
# ---------------------------------------------------------------------------
BASE = "  "


def print_header(plan: dict) -> None:
    contribs = plan.get("contributions", [])
    comps    = plan.get("components", [])
    resolved = {ct.get("resolves") for ct in contribs if ct.get("resolves")}
    n_open   = sum(1 for ct in contribs
                   if ct.get("type") == "challenge" and ct["id"] not in resolved)

    title   = plan.get("title", "Untitled")
    version = plan.get("version", "?")
    updated = plan.get("last_updated", "?")
    n_m     = len(plan.get("mentors", []))

    print()
    print(ansi(f"{BASE}{title}  v{version}", BOLD))
    print(ansi(
        f"{BASE}{updated}"
        f"  │  {n_m} mentor(s)"
        f"  │  {len(comps)} component(s)"
        f"  │  {len(contribs)} contribution(s)"
        f"  │  {n_open} open challenge(s)",
        DIM,
    ))
    print()


# ---------------------------------------------------------------------------
# Format a contribution as two lines: metadata + summary
# Returns a list of strings (lines), without the BASE prefix.
# The caller prepends prefix+connector to the first line and summary_indent
# to the second line.
# ---------------------------------------------------------------------------
def format_node(ct: dict, resolved: set, term_width: int,
                prefix: str, connector: str) -> list[str]:
    cid      = ct["id"]
    mentor   = ct.get("mentor", "")
    ctype    = ct.get("type", "proposal")
    summary  = ct.get("summary", "")
    in_reply = ct.get("in_reply_to")
    resolves = ct.get("resolves")

    is_open    = ctype == "challenge" and cid not in resolved
    is_settled = ctype == "challenge" and cid in resolved

    id_str  = f"[{cid}]"
    ref_str = (f" → {in_reply}" if in_reply
               else (f" ✓ {resolves}" if resolves
                     else ""))
    open_tag = "  ⚠ OPEN" if is_open else ""

    if USE_COLOR:
        id_part     = ansi(id_str, DIM)
        mentor_part = ansi(mentor, mentor_ansi(mentor))
        if is_open:
            type_part = ansi(ctype, "\033[31m", BOLD)
            open_part = ansi(open_tag, "\033[31m", BOLD)
        elif ctype == "response":
            type_part = ansi(ctype, "\033[32m")
            open_part = ""
        elif is_settled:
            type_part = ansi(ctype, DIM)
            open_part = ""
        else:
            type_part = ctype
            open_part = ""
        ref_part = ansi(ref_str, DIM) if ref_str else ""
    else:
        id_part     = id_str
        mentor_part = mentor
        type_part   = ctype
        ref_part    = ref_str
        open_part   = open_tag

    meta_line = f"{id_part} {mentor_part}  {type_part}{ref_part}{open_part}"

    # Summary indented under the metadata, wrapping at terminal width.
    # Indent = BASE + connector-equivalent spaces + 2 so it reads as a continuation.
    summary_indent = " " * (len(BASE) + len(connector) + 2)
    avail = max(40, term_width - len(summary_indent))
    summary = summary.strip()
    # wrap at word boundary
    words, line, wrapped = summary.split(), "", []
    for word in words:
        if line and len(line) + 1 + len(word) > avail:
            wrapped.append(summary_indent + line)
            line = word
        else:
            line = (line + " " + word).lstrip()
    if line:
        wrapped.append(summary_indent + line)

    return [meta_line] + wrapped


# ---------------------------------------------------------------------------
# Print one component as a reply-chain tree
# ---------------------------------------------------------------------------
def print_component(plan: dict, comp: dict, all_contribs: list,
                    resolved: set, term_width: int) -> None:
    cid   = comp["id"]
    title = comp["title"]
    ccs   = [ct for ct in all_contribs if ct["component"] == cid]
    if not ccs:
        return

    sep = ansi("─" * min(len(title) + 4, term_width - len(BASE) - 2), DIM)
    print(BASE + ansi(title.upper(), BOLD))
    print(BASE + sep)

    # Build in-component reply tree
    by_id:    dict[str, dict]  = {ct["id"]: ct for ct in ccs}
    children: dict[str, list]  = {ct["id"]: [] for ct in ccs}
    roots: list[dict]          = []

    for ct in ccs:
        parent = ct.get("in_reply_to")
        if parent and parent in by_id:
            children[parent].append(ct)
        else:
            roots.append(ct)

    def print_node(ct: dict, prefix: str = "", is_last: bool = True,
                   is_root: bool = True) -> None:
        connector = "" if is_root else ("└─ " if is_last else "├─ ")
        lines = format_node(ct, resolved, term_width, prefix, connector)
        print(BASE + prefix + connector + lines[0])
        for extra in lines[1:]:
            print(extra)

        kids         = children.get(ct["id"], [])
        child_prefix = "" if is_root else (prefix + ("   " if is_last else "│  "))
        for i, kid in enumerate(kids):
            print_node(kid, child_prefix, i == len(kids) - 1, False)

    for i, root in enumerate(roots):
        print_node(root, "", i == len(roots) - 1, True)

    print()


# ---------------------------------------------------------------------------
# Open challenges action queue — the "what to do next" section.
# Each open challenge gets full context: what was challenged, what the
# challenge says, and the exact command to summon a mentor to resolve it.
# ---------------------------------------------------------------------------
def print_challenges_footer(plan: dict, resolved: set, plan_path: str,
                             term_width: int) -> None:
    contribs = plan.get("contributions", [])
    open_ch  = [ct for ct in contribs
                if ct.get("type") == "challenge" and ct["id"] not in resolved]
    if not open_ch:
        print(ansi(f"{BASE}✓ No open challenges.", "\033[32m"))
        print()
        return

    by_id = {ct["id"]: ct for ct in contribs}
    sep   = "━" * min(term_width - len(BASE) * 2, 60)

    print(BASE + ansi(sep, "\033[31m"))
    label = f"OPEN CHALLENGES — {len(open_ch)} thread{'s' if len(open_ch) != 1 else ''} waiting"
    print(BASE + ansi(label, "\033[31m", BOLD))
    print(BASE + ansi(sep, "\033[31m"))
    print()

    comp_titles = {c["id"]: c["title"] for c in plan.get("components", [])}
    mentor_names = {m["id"]: m["name"] for m in plan.get("mentors", [])}

    for ch in open_ch:
        comp_id    = ch.get("component", "?")
        comp_title = comp_titles.get(comp_id, comp_id)
        challenger = mentor_names.get(ch.get("mentor", ""), ch.get("mentor", "?"))
        target_id  = ch.get("in_reply_to")
        target     = by_id.get(target_id) if target_id else None
        target_name = mentor_names.get(target.get("mentor", ""), "") if target else ""

        # Header line: who challenged whom, in which component
        who = f"{challenger} challenges {target_name}" if target_name else challenger
        print(BASE + ansi(f"⚠  [{ch['id']}]  {comp_title}", "\033[31m", BOLD)
              + "  " + ansi(who, DIM))

        # The challenge itself — full text, word-wrapped
        challenge_indent = BASE + "   "
        avail = term_width - len(challenge_indent)
        words, line, lines = ch["summary"].strip().split(), "", []
        for w in words:
            if line and len(line) + 1 + len(w) > avail:
                lines.append(line); line = w
            else:
                line = (line + " " + w).lstrip()
        if line:
            lines.append(line)
        for l in lines:
            print(challenge_indent + ansi(l, "\033[31m"))

        # What it was responding to — gives the reader the other side
        if target:
            print()
            responding_to = f"Responding to [{target_id}] {target_name}: {target['summary'].strip()}"
            words, line, lines = responding_to.split(), "", []
            for w in words:
                if line and len(line) + 1 + len(w) > avail:
                    lines.append(line); line = w
                else:
                    line = (line + " " + w).lstrip()
            if line:
                lines.append(line)
            for l in lines:
                print(challenge_indent + ansi(l, DIM))

        # Suggested next action — copy-pasteable
        print()
        cmd = f"/tech-mentor --refine {plan_path} --component {comp_id}"
        print(challenge_indent + ansi("Next:", BOLD)
              + "  " + ansi(cmd, "\033[96m"))
        print()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main() -> None:
    global USE_COLOR

    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("plan", nargs="?", default="plan.yaml",
                    help="path to plan.yaml (default: plan.yaml)")
    ap.add_argument("--component", default=None,
                    help="show only this component id")
    ap.add_argument("--no-color", action="store_true",
                    help="disable ANSI colors")
    ap.add_argument("--color", action="store_true",
                    help="force ANSI colors even when stdout is not a TTY "
                         "(useful for Claude Code expanded view via Ctrl+O)")
    args = ap.parse_args()

    # Default: colors only when stdout is a real TTY (real terminal).
    # Claude Code pipes stdout, so collapsed view gets clean plain text.
    # Pass --color to force colors when you intend to expand with Ctrl+O.
    USE_COLOR = (
        not args.no_color
        and os.environ.get("NO_COLOR") is None
        and (args.color or sys.stdout.isatty())
    )

    try:
        with open(args.plan) as f:
            plan = yaml.safe_load(f)
    except FileNotFoundError:
        sys.exit(f"No plan found at {args.plan}")

    try:
        cols = os.get_terminal_size().columns
    except OSError:
        cols = 100
    term_width = min(cols, 120)

    contribs = plan.get("contributions", [])
    resolved = {ct.get("resolves") for ct in contribs if ct.get("resolves")}

    print_header(plan)

    components = plan.get("components", [])
    if args.component:
        components = [comp for comp in components if comp["id"] == args.component]

    for comp in components:
        print_component(plan, comp, contribs, resolved, term_width)

    if not args.component:
        print_challenges_footer(plan, resolved, args.plan, term_width)


if __name__ == "__main__":
    main()
