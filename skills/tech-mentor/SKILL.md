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

!cmd(python3 scripts/discover_plans.py 2>/dev/null || echo "No plans found - starting fresh.")

---

## Arguments

```bash
/tech-mentor [--plan PATH] [--persona NAME] [--analyze PATH] [--refine FILE] [--format FORMAT] [--component ID] [--status] "description"
/tech-mentor --trial-persona "description" --component ID [--compare-role "description"] [--blend id1,id2]
/tech-mentor --promote-persona NAME
```

- `--plan PATH`: target file for a **new** plan when the default `plan.yaml` is already taken by a different topic — e.g. several plans side by side in a monorepo. Default: `plan.yaml`. Name new ones `<topic>.plan.yaml` so `discover_plans.py` finds them later. Not used together with `--refine`, which already carries its own path.
- `--persona NAME`: "Andrej Karpathy" (default), "Eric Zhang", "Jeff Dean", "Viégas & Wattenberg", "Judea Pearl" — or the reserved `"You"` / `"Assistant"` for a direct, non-persona contribution (your own opinion, or plain LLM background/context). See `kind: direct` in `references/plan-schema.md`.
- `--analyze PATH`: analyze codebase at path before planning
- `--refine FILE`: add a contribution to an existing plan at that path (enables multi-mentor) — this is how you keep working on the *same* plan
- `--format FORMAT`: which view to render — `annotated` (default), `dialogue`, `unified`
- `--component ID`: render or refine a single component only
- `--status`: show a compact summary of the plan at `--plan PATH` (default `plan.yaml`) — components, contribution counts, open challenges — then stop. No planning, no persona. Run `scripts/status.py PATH`.
- `--trial-persona "description"`: try an ungrounded, not-yet-registered persona against one component, disposably. See "Workflow: Trial a New Persona".
- `--compare-role "description"`: paired with `--trial-persona`, runs a generic-role variant of the same prompt for A/B comparison.
- `--blend id1,id2`: paired with `--trial-persona`, runs two already-registered mentors jointly instead of a new description.
- `--promote-persona NAME`: converts a passing trial from earlier in this conversation into a registered mentor. See "Workflow: Promote a Trial Persona".

Persona selection guidance and detailed voice/style: `references/personas/`.

---

## Workflow: Status Check

If the user passed `--status`, run `scripts/status.py plan.yaml`, present
the output, and stop. Do not enter a persona or start planning. Suggest
next actions based on what the status shows (e.g. "2 open challenges —
you could refine with `--component renderer`").

---

## Workflow: New Plan (single mentor)

0. **Check for existing plans** — if the auto-injected context above lists
   any plans and the user passed neither `--refine` nor `--plan`, ask which
   they mean: refine one of the listed plans (`--refine PATH`), or start a
   new, differently-scoped one (`--plan <topic>.plan.yaml`). Never silently
   write to the default `plan.yaml` when other plans already exist next to it.
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

## Workflow: Trial a New Persona

Triggered by `--trial-persona`. This is how a new mentor gets *evaluated*
before anyone commits to writing a reference file for them — see the
`mentor_onboarding` component of this skill's own `plan.yaml` for the full
reasoning behind why this is a separate mode and not a step inside New Plan
or Refine.

A named, real expert is not a costume — it's a retrieval key into whatever
the model actually learned from that person's real corpus (talks, code,
papers). A persona is only worth registering if it surfaces judgment a
generic role prompt structurally couldn't. That claim is falsifiable, so
test it rather than eyeballing the prose:

1. **Read real context first.** Run `scripts/query.sh plan.yaml component
   <ID>` to see what's already been said about this component. The trial
   reasons against that material, not a vacuum.
2. **Run variant A** — the described persona, in voice, against this one
   component only.
3. **If `--compare-role` was given, run variant B** — the same domain
   framing with the name stripped out ("an ML systems engineer focused on
   X" instead of "Andrej Karpathy"). Same question, same component, only the
   identity signal changes.
4. **If `--blend id1,id2` was given instead**, run both registered mentors
   jointly on the component and check whether the result is additive or
   just one voice dominating — this is the distinctiveness test applied to
   a pair instead of a novel persona.
5. **Verdict.** State plainly: did A surface something traceable to that
   real person's actual documented positions that B couldn't have produced
   from domain framing alone? If yes, PASS — worth promoting. If A and B
   read the same with different adjectives, FAIL — this persona (at least
   as described) isn't earning its cost; a role name would be equally
   informative and more honest about what's actually driving the output.

**This mode never writes to `plan.yaml` and never creates files.** Label
every trial output plainly: `[TRIAL — not saved to plan.yaml]`. There is no
mentor id, no contribution, nothing left behind if the trial fails or the
conversation just ends. That's the entire point — the cost of finding out
should be one prompt and one read, not a reference file.

## Workflow: Promote a Trial Persona

Triggered by `--promote-persona NAME`. Requires a trial for that persona
earlier in *this* conversation that reached a PASS verdict — if none exists,
say so and suggest `--trial-persona` first. This is a prose-checked gate,
not a harness-enforced one; take it seriously rather than treating it as a
formality.

1. **Write `references/personas/<name>.md`**, following the existing file
   convention (see any file in `references/personas/` for the shape: Style
   & Philosophy, Expertise Areas, Mentoring Approach, Communication Style,
   When Planning Projects, Example Patterns). Populate it from the trial's
   *actual output* — quote the specific claims that beat the generic-role
   variant in Example Patterns, since those are exactly what already proved
   groundedness. Do not re-derive the persona from the one-paragraph
   description; that paragraph was explicitly disposable and under-specified.
2. **Add the mentor** to `plan.yaml`'s `mentors:` array — `id`, `name`,
   `focus`.
3. **Convert the trial's reasoning into a first-class contribution** —
   `type: proposal`, `in_reply_to: null`, appended the same way any
   `--refine` contribution is. Bump `version`.
4. **Update this file** — add the new persona to the frontmatter
   `description` and to the `--persona NAME` line above. This is the one
   step where the workflow edits the skill's own definition; treat it with
   the same care as a change to shared infrastructure, not as "just docs."
5. **Validate, then render** as in the other workflows.

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
python3 scripts/discover_plans.py                        # list plans in this directory (plan.yaml + *.plan.yaml)
scripts/validate.sh plan.yaml                          # check referential integrity
scripts/query.sh plan.yaml type challenge                # all challenges (open + resolved)
scripts/query.sh plan.yaml unresolved                    # only unresolved challenges
scripts/query.sh plan.yaml mentor zhang                  # everything one mentor contributed
python3 scripts/render_plan.py plan.yaml --format X       # render a view
python3 scripts/status.py plan.yaml                      # compact plan summary (for context injection)
python3 scripts/report.py plan.yaml                      # terminal tree view: scan the DAG at a glance
python3 scripts/report.py plan.yaml --component ID        # zoom into one component's reply chain
```

`report.py` is the "scan not read" view — it prints each component's contributions
as a reply chain with ASCII connectors, ANSI color per mentor, and ⚠ OPEN on
unresolved challenges. Use it when you want to see where the disagreement lives
and how deep a thread got before deciding where to point the next mentor.

Run `validate` after every refinement. It's the cheapest possible check and
catches the most common mistake: an `in_reply_to` or `depends_on` pointing
at a renamed or nonexistent contribution id.

---

## Reference Files

- **Data model and schema**: `references/plan-schema.md` — read this first
- **Persona voice and what each mentor asks about**: `references/personas/` —
  also the target shape for `--promote-persona` output
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
