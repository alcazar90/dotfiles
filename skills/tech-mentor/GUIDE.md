# tech-mentor User Guide

A structured mentorship skill that produces technical plans through expert
personas. Plans are stored as `plan.yaml` (structured data) and rendered into
markdown views on demand — switching formats is instant, never requires
re-conversation.

## Quick Start

```bash
# 1. Get a plan from Karpathy (default mentor)
/tech-mentor "Build a recommendation engine for flight ancillaries"

# 2. Add a systems perspective
/tech-mentor --persona "Eric Zhang" --refine plan.yaml "Review from systems and UX perspective"

# 3. Render a different view
python3 scripts/render_plan.py plan.yaml --format dialogue -o plan.md

# 4. Check what's unresolved
scripts/query.sh plan.yaml unresolved
```

## Core Concept

The skill separates **data** from **presentation**:

```
plan.yaml          →  the single source of truth (structured YAML)
render_plan.py     →  deterministic markdown views (annotated, dialogue, unified)
```

You never hand-write markdown plans. The mentor writes reasoning into
`plan.yaml` as contributions, then the renderer projects them into whichever
view you need. Changing your mind about the format costs one command, not a
new conversation.

## Available Personas

| Persona | Short id | Focus | Use when |
|---------|----------|-------|----------|
| Andrej Karpathy (default) | `karpathy` | ML/DL, model architecture, training | ML projects, model design, research |
| Eric Zhang | `zhang` | Systems, HCI, interaction design | Systems design, UX, operational complexity |
| Jeff Dean | `dean` | Scale, infrastructure, performance | Scale analysis, cost estimation, distributed systems |
| Viégas & Wattenberg | `viegas-wattenberg` | Interpretability, visualization | Understanding model internals, visual analytics |
| Judea Pearl | `pearl` | Causal inference, experimentation | A/B testing, causal reasoning, treatment effects |

Detailed voice guides live in `references/personas/`.

## CLI Flags

```bash
/tech-mentor [--plan PATH] [--persona NAME] [--analyze PATH] [--refine FILE] [--format FORMAT] [--component ID] "description"
```

| Flag | What it does |
|------|-------------|
| `--plan PATH` | File for a **new**, differently-scoped plan (default: `plan.yaml`) — use `<topic>.plan.yaml` to keep several plans side by side |
| `--persona NAME` | Choose which mentor (default: Karpathy) |
| `--analyze PATH` | Read codebase at path before planning |
| `--refine FILE` | Add contributions to an existing plan at that path (multi-mentor, same plan) |
| `--format FORMAT` | Render view: `annotated` (default), `dialogue`, `unified` |
| `--component ID` | Focus on a single component |

## Workflows

### New Plan (single mentor)

```bash
/tech-mentor "Build propensity model with uncertainty quantification"
```

The mentor will:
1. Ask clarifying questions about goals, constraints, baseline
2. Reason through the problem in their voice
3. Emit `plan.yaml` with structured contributions
4. Render the requested markdown view to `plan.md`

If a `plan.yaml` already exists, the skill will ask whether you want to
refine it or start fresh — it won't silently overwrite.

### Refine with Another Mentor

```bash
/tech-mentor --persona "Eric Zhang" --refine plan.yaml "Review from systems perspective"
```

The new mentor reads all existing contributions, identifies gaps from their
lens, and appends new contributions. Existing contributions are never edited
or deleted — only built upon.

Contribution types in refinement:
- **`extension`** — builds on prior work without disputing
- **`challenge`** — surfaces an unresolved risk or trade-off
- **`response`** — addresses a specific challenge (can set `resolves` to close it)

### Focused Refinement

```bash
/tech-mentor --persona "Jeff Dean" --refine plan.yaml --component batch_pipeline "Analyze at 100x scale"
```

The `--component` flag scopes the mentor to one area of the plan.

## Three Render Formats

All three are deterministic projections of the same `plan.yaml`. Pick by intent:

### `annotated` (default)
Groups by component, orders by version. Each contribution has an explicit
attribution tag. Best for "who said what" accountability.

```bash
python3 scripts/render_plan.py plan.yaml --format annotated -o plan.md
```

### `dialogue`
Groups by component as "Threads," shows reply chains via `in_reply_to`.
Best when there's real back-and-forth — conflicting approaches, challenges
that got responses.

```bash
python3 scripts/render_plan.py plan.yaml --format dialogue -o plan.md
```

### `unified`
Groups by component, orders by type (proposals first, then extensions, then
challenges). Drops personal attribution in favor of perspective labels.
Best for final stakeholder-facing documentation.

```bash
python3 scripts/render_plan.py plan.yaml --format unified -o plan.md
```

Switching formats later is free — one command, no re-conversation.

## Scripts Reference

### `scripts/status.py` — Plan summary

```bash
python3 scripts/status.py plan.yaml
```

Prints a compact overview: title, version, mentors, components with
contribution counts, and open challenges. Used automatically by the skill
for context injection (instead of dumping the full YAML).

### `scripts/validate.sh` — Referential integrity

```bash
scripts/validate.sh plan.yaml
```

Checks that all `in_reply_to`, `depends_on`, `component`, and `resolves`
references point to valid ids. Run after every refinement.

Requires: `jq` and `yq` (Go version — install with `brew install jq yq`).

### `scripts/query.sh` — Filter contributions

```bash
scripts/query.sh plan.yaml type challenge          # all challenges
scripts/query.sh plan.yaml unresolved              # only unresolved challenges
scripts/query.sh plan.yaml mentor zhang             # everything Zhang contributed
scripts/query.sh plan.yaml component batch_pipeline # contributions to one component
```

Requires: `jq` and `yq`.

### `scripts/render_plan.py` — Render views

```bash
python3 scripts/render_plan.py plan.yaml --format annotated
python3 scripts/render_plan.py plan.yaml --format dialogue --component calibration_module
python3 scripts/render_plan.py plan.yaml --format unified -o plan.md
```

Requires: `pyyaml` (`pip install pyyaml`).

## The plan.yaml Data Model

A plan is a graph of contributions. Each contribution is a node; `in_reply_to`
and `depends_on` are edges.

```yaml
title: "Project Name"
version: 2.0
last_updated: "2026-06-30"

mentors:
  - id: karpathy
    name: "Andrej Karpathy"
    focus: "ML architecture"

components:
  - id: calibration_module
    title: "Calibration Module"

contributions:
  - id: c1
    component: calibration_module    # must match components[].id
    mentor: karpathy                 # must match mentors[].id
    version: 1.0
    type: proposal                   # proposal | extension | challenge | response
    in_reply_to: null                # id of contribution being responded to
    depends_on: []                   # ids this reasoning relies on
    resolves: null                   # id of a challenge this response closes
    summary: "One-line description"
    body: |
      Full prose reasoning in the mentor's voice.
      Never decomposed into sub-fields — free-form is intentional.
```

Full schema details: `references/plan-schema.md`.

### Key rules

- **`body` stays free prose.** No `what`/`why`/`tradeoffs` sub-fields.
- **Contributions are append-only.** Never edit or delete existing entries.
- **`resolves` closes challenges.** A `response` can set `resolves: c5` to
  mark challenge `c5` as addressed. Omit if only partially addressing it.
- **Ids are sequential:** `c1`, `c2`, `c3`... within a plan file.

## Common Multi-Mentor Patterns

### ML → Systems → Scale
1. **Karpathy** (v1.0): Model architecture, training approach
2. **Zhang** (v2.0): Operational complexity, UX, deployment concerns
3. **Dean** (v2.5): Scale analysis, performance, cost estimation

### ML → Interpretability → Production
1. **Karpathy** (v1.0): Model architecture
2. **Viégas & Wattenberg** (v2.0): Interpretability, visualization strategy
3. **Zhang** (v2.5): How to surface insights to users, monitoring

### Causal → ML → Scale
1. **Pearl** (v1.0): Causal graph, identification strategy
2. **Karpathy** (v2.0): ML approach within causal constraints
3. **Dean** (v2.5): Scale requirements for experimentation platform

## End-to-End Workflow

The skill integrates with downstream tools to go from plan to execution:

```
/tech-mentor           → plan.yaml + plan.md
/md-to-issues plan.md  → structured JSON array of issues
/gitlab-issue-creator  → pushes issues to GitLab
```

## Dependencies

| Tool | Required by | Install |
|------|-------------|---------|
| `python3` + `pyyaml` | `render_plan.py`, `status.py` | `pip install pyyaml` |
| `jq` | `validate.sh`, `query.sh` | `brew install jq` |
| `yq` (Go version) | `validate.sh`, `query.sh` | `brew install yq` |

## Directory Structure

```
tech-mentor/
├── SKILL.md                        # Main skill entry point (workflow + flags)
├── GUIDE.md                        # This file
├── references/
│   ├── plan-schema.md              # plan.yaml data contract
│   ├── format-guide.md             # When to use each render format
│   ├── collaboration-guide.md      # Multi-mentor norms and patterns
│   └── personas/
│       ├── karpathy.md             # ML/DL voice and concerns
│       ├── zhang.md                # Systems/HCI voice and concerns
│       ├── dean.md                 # Scale/infrastructure voice and concerns
│       ├── viegas-wattenberg.md    # Interpretability/viz voice and concerns
│       └── pearl.md                # Causal inference voice and concerns
└── scripts/
    ├── render_plan.py              # Deterministic markdown renderer
    ├── validate.sh                 # Referential integrity checker
    ├── query.sh                    # Contribution filter/search
    ├── status.py                   # Compact summary of one plan
    └── discover_plans.py           # Lists plan.yaml + *.plan.yaml siblings
```
