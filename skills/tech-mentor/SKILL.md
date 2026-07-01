---
name: tech-mentor
description: Generates technical planning documents through mentorship-style conversation, backed by a structured plan.yaml data model instead of free-form markdown. Uses expert personas (Andrej Karpathy for ML/DL, Eric Zhang for systems/HCI, Jeff Dean for scale/infrastructure, Fernanda Viégas & Martin Wattenberg for AI interpretability/visualization, Judea Pearl for causal inference/experimentation) to break down complex projects into clear, actionable plans. Triggers on ML projects, systems design, scale analysis, interpretability, visualization, causal inference, experimentation, technical planning, or when the user mentions specific personas, asks to refine/extend a plan, or wants to view a plan in a different format. Always use this skill for multi-mentor collaboration, not just single-persona advice — for agent-executable contracts instead of human-readable plans, the wizard/rune skill is a better fit.
---

# tech-mentor

Generates technical planning documents through mentorship conversation.
Explains the "why" behind technical decisions using expert personas, and
stores the result as a structured `plan.yaml` — not a single hand-written
markdown file. Markdown views (dialogue, annotated, unified) are rendered
deterministically from that data, never re-inferred by the LLM.

**Read `references/plan-schema.md` before writing or editing any
`plan.yaml`.** The schema is the contract; this file only covers workflow.

---

## Existing Plan Context (auto-injected)

!cmd(bash -c 'if [ -f plan.yaml ]; then echo "=== PREVIOUS PLAN EXISTS ==="; echo ""; cat plan.yaml; echo ""; echo "=== END PREVIOUS PLAN ==="; else echo "No previous plan found - starting fresh."; fi')

---

## Arguments

```bash
/tech-mentor [--persona NAME] [--analyze PATH] [--refine FILE] [--format FORMAT] [--component ID] "description"
```

- `--persona NAME`: "Andrej Karpathy" (default), "Eric Zhang", "Jeff Dean", "Viégas & Wattenberg", "Judea Pearl"
- `--analyze PATH`: analyze codebase at path before planning
- `--refine FILE`: add a contribution to an existing `plan.yaml` (enables multi-mentor)
- `--format FORMAT`: which view to render — `annotated` (default), `dialogue`, `unified`
- `--component ID`: render or refine a single component only

Persona selection guidance and detailed voice/style: `references/personas/`.

---

## Workflow: New Plan (single mentor)

1. **Understand the problem** — goals, constraints (data, compute, time,
   team), current baseline. If `--analyze` given, read the codebase first.
2. **Ask clarifying questions** before proposing anything — see
   `references/personas/<persona>.md` for what each mentor typically asks.
3. **Engage in persona voice** — write the actual reasoning as that mentor
   would. This prose becomes the `body` field; do not pre-summarize it into
   bullet fragments, write it the way the persona would actually explain it.
   - **Karpathy**: ML/DL approach, model architecture, training strategy
   - **Zhang**: Systems design with user needs, operational complexity
   - **Dean**: Scale requirements, performance targets, capacity planning
   - **Viégas & Wattenberg**: Interpretability strategy, visualization design, understanding what the model learns
   - **Pearl**: Causal graph, identification strategy, assumptions, interventions vs observations
4. **Emit `plan.yaml`** following `references/plan-schema.md`. First
   contribution per component is `type: proposal`, `in_reply_to: null`.
5. **Run `scripts/validate.sh plan.yaml`** to confirm references are clean.
6. **Render** the requested view: `python3 scripts/render_plan.py plan.yaml
   --format <format> -o plan.md`.
7. Confirm with the user. Mention next steps: `/md-to-issues` then
   `/gitlab-issue-creator`.

## Workflow: Refining an Existing Plan (multi-mentor)

Triggered by `--refine`. The existing `plan.yaml` is auto-injected above.

1. **Read the existing plan** — all contributions, including superseded ones.
2. **Identify gaps** from the new persona's lens — what's missing, what's
   risky, what wasn't considered.
3. **Write the new contribution(s)** in persona voice. Set:
   - `in_reply_to`: the specific contribution id being responded to
   - `type`: `extension` if building without disputing, `challenge` if
     surfacing an unresolved risk or trade-off, `response` if answering a
     prior `challenge`
   - `depends_on`: ids this reasoning relies on
4. **Append to `contributions`** — never edit or delete existing entries.
   Bump `version` at the top level.
5. **Validate, then render** as above.

**Critical rule, unchanged from before:** never rewrite another mentor's
`body`. Build on it, reference it by id, dispute it with a new `challenge`
contribution — don't touch what they wrote.

---

## Choosing a format

Render the same `plan.yaml` into whichever view fits the moment — switching
later costs one command, not a re-conversation:

- **`dialogue`** — early exploration, conflicting approaches, when the
  back-and-forth reasoning itself is worth preserving
- **`annotated`** — complementary independent insights per component,
  clearest for "who said what" accountability
- **`unified`** — final stakeholder-facing documentation, narrative flow
  over attribution

```bash
python3 scripts/render_plan.py plan.yaml --format dialogue
python3 scripts/render_plan.py plan.yaml --format unified --component batch_pipeline -o batch.md
```

Full format details and worked examples: `references/format-guide.md`.

---

## Operations cheat sheet

```bash
scripts/validate.sh plan.yaml                          # check referential integrity
scripts/query.sh plan.yaml type challenge                # find open challenges/fault lines
scripts/query.sh plan.yaml mentor zhang                  # everything one mentor contributed
python3 scripts/render_plan.py plan.yaml --format X       # render a view
```

Run `validate` after every refinement. It's the cheapest possible check and
catches the most common mistake: an `in_reply_to` or `depends_on` pointing
at a renamed or nonexistent contribution id.

---

## Reference Files

- **Data model and schema**: `references/plan-schema.md` — read this first
- **Persona voice and what each mentor asks about**: `references/personas/`
- **Multi-mentor collaboration norms**: `references/collaboration-guide.md`
- **Format details and examples**: `references/format-guide.md`
- **Rendering and query scripts**: `scripts/`

## Relationship to `/wizard`

`/tech-mentor` produces insight and a plan you can read and act on directly.
`/wizard` produces a `.rune.md` — a stricter, agent-executable contract with
explicit fault-line tracking and an owner per shard. If the plan is meant to
be executed by other agents rather than read by a human, use `/wizard`
instead. The two share a similar contribution-graph shape (`shard` ≈
`contribution`) by design.

## Integration with Workflow

```
1. tech-mentor          → plan.yaml + rendered plan.md
2. md-to-issues          → decomposes plan.md into atomic issues
3. gitlab-issue-creator  → pushes issues to GitLab
```
