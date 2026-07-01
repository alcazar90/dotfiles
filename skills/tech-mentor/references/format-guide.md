# Format Guide

Three views, one `plan.yaml`. All three are rendered by
`scripts/render_plan.py --format <name>` — none of them are hand-written
templates anymore. This file explains what each view does and when to pick
it; for the actual markdown output, just run the script.

> **Migration note:** earlier versions of this skill kept three separate
> example templates (`templates/dialogue-format.md`,
> `templates/annotated-format.md`, `templates/unified-format.md`) that had
> to be hand-maintained and could drift from each other. They're gone — the
> renderer is the single implementation of all three, driven by the same
> `contributions` array. See `references/plan-schema.md` for the data model.

## `annotated`

Groups by `component`, then orders contributions within each component by
`version`. Each contribution gets an explicit attribution tag:

```
**[Eric Zhang - v2.0, extension on prior work]**
```

**Use when** perspectives are complementary and independent — each mentor
looked at the same component from their own angle without much back-and-forth.
Best for "who said what" accountability.

## `dialogue`

Groups by `component` as a "Thread," then orders chronologically by
`version`, with each contribution's attribution line pointing at what it's
replying to via `in_reply_to`:

```
**Eric Zhang - v2.0, → Andrej Karpathy on [summary]:**
```

**Use when** there's a real back-and-forth — conflicting approaches, a
`challenge` that got a `response`, design debate where the reasoning process
itself is worth preserving. This is the view that makes fault lines visible:
run `scripts/query.sh plan.yaml type challenge` first to see which threads
have unresolved tension before rendering.

## `unified`

Groups by `component`, orders by `type` (`proposal` → `extension` →
`challenge` → `response`) rather than chronology, drops attribution tags in
favor of `*From [mentor's focus]:*`.

**Use when** producing final stakeholder-facing documentation — narrative
flow matters more than who-said-what. This view does not merge prose across
contributions; each contribution's `body` still appears as its own
paragraph block. True synthesis (rewriting multiple viewpoints into one
fused paragraph) is an inference task, not a rendering task — if you want
that, ask the current mentor persona to write a synthesis as a new
contribution rather than expecting the renderer to fabricate one silently.

## Filtering to one component

All three formats accept `--component <id>` to render just one section —
useful mid-refinement when you only care about the thread you're actively
working on:

```bash
python3 scripts/render_plan.py plan.yaml --format dialogue --component calibration_module
```
