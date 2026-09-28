---
title: "Tech-Mentor Skill Interface Evaluation"
mentors:
  - name: "Andrej Karpathy"
    focus: "Data model design, system architecture, reasoning structure"
  - name: "Eric Zhang"
    focus: "Systems design, UX considerations, developer ergonomics"
version: 3.3
last_updated: "2026-07-23"
---

# Tech-Mentor Skill Interface Evaluation

## Plan Data Model (plan.yaml schema)

**[Andrej Karpathy - v1.0]**

The contributions array with type/in_reply_to/depends_on is essentially a
directed acyclic graph of reasoning. Each contribution is a node; edges are
dependency and reply relationships. This is the strongest part of the design
for two reasons:

First, it makes the structure of the argument explicit without
over-structuring the content of the argument. The body stays as free prose.
The decision not to decompose it into what/why/tradeoffs sub-fields avoids
structure-as-theater — empty boxes that get filled with noise just to pass
validation.

Second, the type vocabulary (proposal/extension/challenge/response) maps
cleanly to how real technical debates work. A proposal starts a thread.
Extensions build. Challenges are fault lines. Responses address them. This
is simplified argument mapping from epistemology, which is exactly right for
a planning tool.

The validate.sh script catches referential integrity — broken in_reply_to,
orphaned depends_on, unknown component. This is a type checker for the
reasoning graph. Cheap and catches the most common failure mode.

---

**[Eric Zhang - v2.0, extension on prior work]**

Karpathy's right that the contribution graph is a good abstraction. But
there's a UX question he skipped: who is the user of this schema?

The human user never writes plan.yaml by hand — the LLM does. The human
never reads plan.yaml directly — they read the rendered markdown. So the
schema's primary consumer is the LLM, and the primary UX surface is the
rendered output plus the CLI flags.

This means schema elegance matters less than schema predictability. The LLM
needs to produce valid YAML every time without hallucinating field names or
forgetting required fields. Two things would help:

1. A minimal valid example embedded in plan-schema.md — not the 80-line
propensity model, but a 15-line skeleton showing one mentor, one component,
one contribution. The LLM can clone-and-extend from a small example more
reliably than it can interpret a field specification.

2. The id generation convention (c1, c2, c3...) is implicit. If the LLM
generates a second plan in the same session, does it start at c1 again?
Does it continue from the last id? This should be explicit: "ids are
sequential within a plan file, starting at c1."


## CLI Interface and Flag Design

**[Andrej Karpathy - v1.0]**

The CLI interface works but has several friction points:

1. The --refine flag is the critical path for the most common workflow
(multi-mentor iteration), but it's explicit and easy to forget. If plan.yaml
already exists, the skill should detect it and ask whether to refine or start
fresh. The !cmd auto-injection already detects the file but the workflow
doesn't act on that detection.

2. Persona names are full strings ("Viégas & Wattenberg") with ampersands
and spaces — a shell quoting problem. The data model already uses short ids
(karpathy, zhang, dean). The CLI should accept those too: --persona zhang
should work alongside --persona "Eric Zhang".

3. No --status flag exists. Mid-refinement, you want to know what components
exist and which have open challenges. Currently requires remembering to run
scripts/query.sh manually. A --status flag that runs the equivalent inline
would reduce cognitive load.

4. The --format default is inconsistent: SKILL.md says annotated (line 34),
collaboration-guide.md says unified (line 49). This is exactly the kind of
drift the redesign was supposed to eliminate.

---

**[Eric Zhang - v2.0, extension on prior work]**

Karpathy identified the right friction points (--refine detection, persona
naming, --status). But there's a deeper issue: the CLI flags are a fiction.

This is a Claude Code skill. The user types "/tech-mentor ..." in a chat
interface. There's no actual shell parsing of --flags. The LLM reads the
entire invocation string and interprets it. So the "CLI interface" is really
a prompt protocol — a convention the LLM is trained to parse from the
SKILL.md instructions.

This changes the design priorities:

1. Short aliases (--persona zhang) don't save keystrokes because the user
is typing in natural language anyway. What they save is ambiguity — "zhang"
is unambiguous, "Eric Zhang" requires the LLM to fuzzy-match. So aliases
are worth adding, but for precision, not ergonomics.

2. The --refine auto-detection Karpathy suggested is more important than he
made it sound. The !cmd already injects "=== PREVIOUS PLAN EXISTS ===" into
context. The SKILL.md workflow should explicitly say: "If the auto-injected
context shows a previous plan exists AND the user didn't pass --refine, ask
whether to refine or start fresh." This is a one-line addition to the
workflow that eliminates the most common user error.

3. A --status flag should not just exist — it should be the DEFAULT first
action when plan.yaml exists. Before asking any questions, show the user:
"Current plan has 5 contributions across 2 components, 1 open challenge
(c5: staleness handling)." Orientation before action.


## Deterministic Renderer (render_plan.py)

**[Andrej Karpathy - v1.0]**

The render_plan.py script is well-designed as a pure function: data in,
markdown out, no side effects. Three issues:

1. Component ordering bug: by_component is a defaultdict(list) populated by
iterating contributions. Components render in the order their first
contribution appeared, not the order defined in the components array. If a
multi-mentor refinement interleaves contributions across components, the
rendered order diverges from the schema's declared order. The fix is to
iterate plan["components"] and pull contributions per component, rather than
building component groups from contributions.

2. No summary/stats header in rendered output. Adding a brief block at the
top — number of contributions, mentors involved, open challenges — gives
readers immediate orientation before diving into content.

3. The "unified" view doesn't actually unify — it reorders contributions by
type but each body still appears as a separate block. The format guide
correctly notes that true synthesis is an inference task, not a rendering
task. But the name "unified" sets expectations it doesn't meet. "grouped" or
"structured" would be more honest.

---

**[Eric Zhang - v2.0, challenge on prior work]**

Karpathy's component ordering bug is genuine and should be fixed. The
renderer should iterate plan["components"] to preserve declared order.
Agreed.

But I challenge the stats header idea. Adding "3 mentors, 5 contributions,
1 open challenge" at the top of every render sounds useful in isolation, but
in practice it's noise that the user scrolls past after the second time.
The rendered markdown is a document meant to be read by humans or consumed
by downstream tools (/md-to-issues). Stats headers break the document flow
and confuse markdown parsers that expect the first H1 to be the title.

Better alternative: make --status a separate operation that prints stats
to stderr, not a section embedded in the rendered output. Keep the renderer
pure: data in, document out, nothing extra.

On the "unified" naming: I actually disagree with renaming it. "Unified"
communicates the intent (one coherent view), even if the implementation is
"ordered by type." Users pick formats by intent, not by implementation
detail. "Grouped" is technically more accurate but tells you nothing about
when to use it.


## Multi-Mentor Collaboration Workflow

**[Andrej Karpathy - v1.0]**

The collaboration-guide.md captures the right norms: append contributions,
reference existing ones by id, don't rewrite what others wrote. The
cross-mentor patterns (ML to Systems to Scale, etc.) and the good/bad
examples are valuable.

But at 281 lines, the guide is over-documented for what amounts to three
rules: (1) append, don't replace, (2) reference by id, (3) acknowledge
previous work. The LLM learns more from one concrete good/bad example pair
than from five paragraphs of rules. The cross-mentor transition table
(lines 129-141) could be a simple lookup rather than prose.

Also, the collaboration guide still uses the old metadata format (iterations
field, base_version field) that doesn't match the current plan.yaml schema
(which uses version, type, in_reply_to). This is stale documentation that
could confuse the LLM into generating the wrong metadata structure.

---

**[Eric Zhang - v2.0, challenge on prior work]**

Karpathy flagged the collaboration guide as "over-documented." That's a
style judgment I partly agree with — yes, it could be shorter. But he
buried the real bug: the metadata format in collaboration-guide.md (lines
80-95) uses iterations, base_version, and date fields that DON'T EXIST in
the current plan.yaml schema.

This isn't over-documentation. It's wrong documentation. If the LLM reads
the collaboration guide during a --refine workflow, it might generate YAML
with an iterations field that validate.sh can't check and render_plan.py
ignores silently. The plan would "work" but carry ghost fields that create
the illusion of structure.

Fix: update collaboration-guide.md metadata example to match plan-schema.md
exactly. Remove iterations, base_version, date from the example. Add
in_reply_to, depends_on, type. This is a 10-line change that prevents a
class of silent failures.

The cross-mentor transition table (lines 129-141) is actually fine as prose.
It's read by the LLM to understand WHAT each persona transition adds. A
lookup table would be more compact but less informative — the LLM needs
"ML design to systems/UX implications" spelled out, not just "karpathy →
zhang."

---

**[Eric Zhang - v3.0, response on prior work]**

The metadata example block (lines 77-100) was already corrected — it now
matches plan-schema.md. That was the highest-risk part of c9: wrong example
leads to wrong YAML generation, silent ghost fields.

But the fix was incomplete. Three stale references remain:

1. Step 6 (lines 164-168) says "Add new mentor to mentors list with
iteration number" and "Keep base_version pointing to original." Neither
iterations nor base_version exist in the plan.yaml schema. Fix: rewrite to
"Bump version at the top level, add new mentor to mentors array with id,
name, focus. Update last_updated."

2. Cross-reference syntax (lines 104-109) documents hand-written markdown
attribution tags that belong to the old template era. With plan.yaml,
cross-references happen through in_reply_to and depends_on fields — the
renderer handles attribution automatically. Fix: reframe this section to
explain the structural fields, note that rendered output handles the display
format.

3. Pearl is completely absent from the cross-mentor transition table (lines
134-145). Every other persona has bidirectional mappings. Fix: add Pearl
transitions — Pearl to Karpathy (causal constraints on model design), Pearl
to Zhang (experiment UX and operational complexity of randomization), Pearl
to Dean (scale of experimentation platforms), and the reverse directions.

The deeper pattern: every piece of duplicated documentation is a future drift
point. The metadata section was fixed by replacing the example with a pointer
to plan-schema.md. Apply the same pattern to Step 6 — point to the SKILL.md
workflow instead of re-explaining version bumping.


## Missing Operations and Lifecycle Gaps

**[Andrej Karpathy - v1.0]**

Three gaps in the current system:

1. No merge/resolve operation. When a challenge gets a response, the
challenge is still "open" — query.sh type challenge returns it forever. You
need either a status field on contributions (open/resolved) or a resolves
field on responses that explicitly closes a challenge. Without this,
challenge queries become noisy as the plan grows.

2. No priority or ordering signal beyond version numbers. Some components
are more critical than others; some contributions are the core proposal
while others are minor extensions. There's no way to signal "this is the
load-bearing decision" versus "nice to have."

3. The auto-inject !cmd dumps the entire plan.yaml into context. For 5
contributions that's fine. For 30 contributions across 8 components, you're
burning tokens on a wall of YAML the LLM has to parse. The --component
filter should apply to the injection too, not just the render.

---

**[Eric Zhang - v2.0, extension on prior work]**

On Karpathy's three gaps:

1. Challenge resolution: agree this is needed. The simplest fix is a
resolves field on response-type contributions: resolves: c5 explicitly
closes that challenge. Then query.sh can filter for unresolved challenges:
challenges whose id doesn't appear in any contribution's resolves field.
This is better than a status field on the challenge itself because it
preserves immutability — you never edit an existing contribution, you just
add a response that references it.

2. Priority signal: I'd push back on this. Priority is context-dependent —
what's critical for the ML team is secondary for the UX team. Adding a
priority field invites bikeshedding over whether something is "high" or
"medium." The current system already has an implicit priority signal: the
number of contributions touching a component. If calibration_module has 3
contributions and batch_pipeline has 2, the plan is telling you where the
complexity lives. Let that emerge rather than declaring it.

3. Context injection scaling: this is the most impactful fix. Instead of
dumping raw YAML, the !cmd should run a summarizer — something like
query.sh but outputting a compact status:

  Plan: "Propensity Model" v2.5 (3 mentors, 5 contributions)
  Components: calibration_module (3 contributions), batch_pipeline (2)
  Open challenges: c5 (staleness handling)
  Last updated: 2026-03-13

Twenty lines instead of 100. The LLM can then request the full YAML for
specific components via --component if it needs detail. This is progressive
disclosure applied to context injection.


## Co-Planning Interaction: Enforcement Hooks, Context Anchoring, and Inspection Tooling

**[Andrej Karpathy - v3.1]**

The user raised three related observations from actually living inside the
co-planning loop, not from reading the schema. All three point at the same
root cause: this skill currently asks the LLM to *remember* to do things —
validate after writing, read the full plan before refining — via prose in
SKILL.md. Zhang already named this failure mode in c7: the CLI is "a prompt
protocol," a convention the LLM is trained to parse, not an enforced
contract. Prose conventions degrade under pressure — a long refinement
session that crosses a context-compaction boundary can silently drop an
instruction that isn't anchored to anything the harness actually checks.
There's a real fix available for two of these: stop asking, start
enforcing.

1. Validation as a hook, not a reminder. Step 5 of the New Plan workflow
says "run scripts/validate.sh — confirm references are clean." That only
happens if the agent remembers. Claude Code's PostToolUse hooks fire on
every Write/Edit regardless of what's in the model's working context —
configure one (via the update-config skill, since hooks live in
settings.json, not in this skill) that matches Write|Edit on plan.yaml and
shells out to scripts/validate.sh. This turns "please remember" into "the
harness guarantees it, every time." It's the same value a type checker
gives you over a code review comment that says "please check your types."

2. Anchoring plan.yaml — but not by brute-forcing the full file into every
turn. My first instinct was to recommend hard-anchoring plan.yaml the way
the user attaches @SKILL.md by hand. I want to push back on my own
instinct here: c10 already made the right call that full-YAML injection
doesn't scale past a handful of contributions, and a blanket @-anchor
would silently re-introduce that cost on every single turn, not just at
refine-time. The actual failure mode the user is pointing at is narrower:
step 1 of the Refining workflow ("Read the existing plan — all
contributions, including superseded ones") is a prose instruction with no
teeth, and it's easy for an agent to treat the injected status.py summary
as good enough and skip the real Read. That produces shallow "extensions"
that restate a summary line instead of engaging with a prior mentor's
actual argument. The fix belongs in wording, not in a new
auto-inclusion mechanism: make step 1 explicit that the injected summary
is for orientation only (refine-or-fresh, which component has heat) and is
never a substitute for reading the target contribution's full body before
writing in_reply_to against it.

3. A terminal-native inspection report. Right now there are only two
views: status.py (machine-oriented, counts and open challenges, meant for
context injection) and render_plan.py (human-oriented, full markdown,
meant for reading start to finish). There's a gap in between — a quick
glance at the shape and evolution of the plan without opening a rendered
doc. Concretely: extend status.py with a --tree mode (or a small new
scripts/report.py) that walks components in declared order and prints
each component's contributions as a reply chain, e.g.:

  data_model
    [c1] karpathy  proposal            "Contribution graph is the..."
    └─ [c6] zhang  extension → c1      "Schema is sound but the..."
  renderer
    [c3] karpathy  proposal            "Renderer is clean but has..."
    └─ [c8] zhang  challenge → c3  ⚠ OPEN

This is a loss-curve, not a logbook — you're not reading it, you're
scanning it for where the disagreement is and how deep a thread got
before you decide where to point the next mentor. It also gives
--component real teeth as a human-facing filter, not just a render/refine
scope.


## Evaluating and Incorporating New Mentor Personas

**[Andrej Karpathy - v3.2]**

The question underneath "what do I gain from a persona description file
versus just asking the model directly" is really a question about
inductive bias. Prompting the model with "be Andrej Karpathy" for one
turn gets you style transfer — vocabulary, tone, maybe a few
characteristic phrases pulled from training data. What it does not get
you is a stable set of questions the persona reliably asks, and that's
the part the collaboration model in this skill actually depends on.

Look at what makes c6 through c11 work as a sequence: Zhang doesn't just
sound different from me, he interrogates a different axis every single
time — who's the actual user, what breaks operationally, is this a UX
fiction. That consistency is what makes a challenge contribution
meaningful signal instead of noise. If the persona is regenerated from
scratch each session with no written anchor, nothing guarantees the
model's "Zhang" asks the same kind of question in session 10 that it
asked in session 1. The contribution graph's whole value proposition —
that disagreement across ids is real disagreement, not roleplay flavor
— collapses the moment the personas aren't grounded in something
durable.

So the file earns its cost only if it captures three things, not
adjectives:

1. A short list of characteristic questions — the specific things this
mentor reliably interrogates a proposal with. Not "is rigorous and
direct" but "always asks what the actual training signal is" / "always
asks who breaks when this ships."

2. An explicit boundary — what this mentor does NOT cover, so two
personas don't converge on the same question from slightly different
words and produce redundant contributions.

3. Worked examples grounded in the real person's actual writing or
talks. A persona imitated from a one-line description regresses to
caricature within a few paragraphs; a persona anchored to real
exemplars holds its distinct reasoning style much longer.

Given that, here's a rubric for whether a candidate mentor is worth
incorporating at all — three tests, in order:

- Gap test: is there a planning question that none of the existing
mentors' characteristic-question sets would surface? If Zhang already
asks "who's the user" and Dean already asks "what's the scale," a new
persona asking "who's the user at scale" fails this test before it
starts.

- Distinctiveness test: run the same component through the candidate
and the nearest existing mentor. If the resulting contributions would
be near-identical in substance, the new persona isn't adding a lens,
it's adding a name.

- Groundedness test: is there enough real material — writing, talks,
code, decisions — from this person or role to actually populate
characteristic questions and voice examples? If not, either use a role
name (e.g. "security reviewer") instead of a named individual, or don't
add it. A named persona with no real grounding is worse than no persona
— it invites the model to fabricate a voice with false confidence.

---

**[Eric Zhang - v3.2, challenge on prior work]**

Karpathy's rubric is the right shape but it assumes the cost of finding
out is the reference file itself, and that's backwards. Writing
characteristic questions, a boundary, and worked examples for a
candidate persona is real work — probably 30-60 minutes of careful
writing, the same order of magnitude we just spent fixing stale
metadata in the collaboration guide (c9, c11). If you write that file
before running the gap and distinctiveness tests, you've committed the
cost before you know the answer.

This is exactly the question the user started with: what do you gain
from the file versus asking the model directly? My answer is: it
depends which phase you're in, and the rubric skips the phase
distinction.

For evaluating whether a persona is worth having, direct prompting is
the correct tool, not a shortcut around a better one. Write one
paragraph — "you are a security reviewer whose only concern is trust
boundaries and blast radius, ask about that and nothing else" — and run
it against one real component the same way you'd trial a proposal. It's
cheap, disposable, and reversible. If the gap and distinctiveness tests
fail, you've spent five minutes, not fifty.

The file's value only shows up in the second phase: once a persona is
validated and expected to persist across many future sessions and
possibly other users, the durability problem Karpathy describes — drift,
inconsistent characteristic questions across sessions — actually kicks
in. A single trial run inside one conversation doesn't have a drift
problem, because there's no "next session" for it to drift from yet.

Concretely: the trial-phase contribution shouldn't go into the shared
plan.yaml at all. plan.yaml is the durable, multi-session source of
truth (I made this point in c6) — mixing a disposable one-off persona's
contribution into it means either it gets cleaned up later (manual,
easy to forget) or it lingers as a mentor nobody promoted, cluttering
the mentors array the way stale fields cluttered the collaboration
guide. Trial runs belong in the conversation, not the file.

---

**[Andrej Karpathy - v3.2, response on prior work]**

Agreed, and I'll go further: my rubric conflated "how do we decide" with
"how do we commit," which is the same mistake as writing training code
before you've validated the data pipeline on a small sample. Two-phase
is correct.

Phase 1 — trial: prompt the model directly with a one-paragraph persona
description, no file, run it against exactly one real component. Score
it against the gap and distinctiveness tests from c13. This happens
inside the working conversation and never touches plan.yaml — no new
mentor id, no new contributions committed to the shared file. If it
fails either test, the cost was one prompt and one read.

Phase 2 — promotion: only after a trial passes both tests does it earn
a reference file — characteristic questions, boundary, and worked
examples per the groundedness test — and only then does it get a mentor
id added to plan.yaml's mentors array and a line in SKILL.md's persona
list.

One addition worth making explicit in the workflow docs: the promotion
step should re-run the distinctiveness test one more time using the
actual trial contribution instead of a hypothetical, since a persona
description that sounds distinctive in the abstract sometimes produces
prose indistinguishable from an existing mentor once it's actually
written down. Cheap to check, expensive to discover three sessions
later that two mentors are the same lens wearing different names.

---

**[Andrej Karpathy - v3.3, extension on prior work]**

One more thing worth sharpening in my own c13 argument, because it
changes what "groundedness" actually buys you. I framed the choice
between a named persona and "just asking the model" as roughly style
transfer versus a stable set of questions. That undersells why the name
matters at all.

When you write "as Andrej Karpathy" instead of "as an ML systems
engineer," you're not asking for a costume — you're pointing at
whatever the model actually learned from ingesting a specific person's
real corpus: their talks, their code (minGPT, nanoGPT), their papers,
their public writing about training runs that went wrong. If that
corpus is large and consistent enough, the name is a compressed
retrieval key into a genuinely different distribution of judgment than
a generic role prompt gets you — not because the model "knows" the
person, but because their actual documented positions are
disproportionately represented in whatever the name activates. A
generic "ML systems engineer" persona has no such anchor; it's
synthesized from the average of everyone who's ever held that job
title, which regresses toward generic competence.

This is exactly why the groundedness test in c13 isn't a nice-to-have,
it's the mechanism. A named persona with no real public corpus behind
it (obscure person, or a fictional "security engineer" role) gets you
nothing beyond the domain framing already in the prompt — there's no
disproportionate signal to retrieve. In that case, naming it after a
real person is actively worse than a role name, because it borrows
false specificity: the model still averages toward
generic-competent-role behavior but presents it with the confidence of
a named individual, and a reader has no way to tell the difference from
the output alone.

---

**[Eric Zhang - v3.3, extension on prior work]**

If that's true — and I think it is — then it's testable, and we
shouldn't be satisfied with a rubric that only gets checked by reading
the prose and going "yeah, sounds like Karpathy." Here's the actual
test: run the same component through three variants of the same
underlying question, holding everything constant except the identity
framing:

(A) Named: "As Andrej Karpathy, reasoning about calibration_module..."

(B) Generic role, same domain framing, no name: "As an ML systems
engineer focused on training data quality, reasoning about
calibration_module..."

(C) Blended, if collaboration is the goal: "As Karpathy and Zhang
jointly, reasoning about calibration_module..."

Compare A against B first. If A surfaces something a generic role
prompt structurally couldn't — a specific stance traceable to that
person's actual public record (e.g. Karpathy's documented bias toward
hand-rolled minimal implementations before reaching for a framework, or
his specific way of debugging via loss curves) — that's evidence for
the retrieval-key theory: real signal, not mood. If A and B produce the
same reasoning with different adjectives sprinkled in, the persona is
failing the groundedness test regardless of how famous the name is, and
it should be demoted to a role name per Karpathy's own fallback in c13.

This gives the gap and distinctiveness tests from c13 an actual
falsification condition instead of a vibe check. And it directly
answers the plan-versus-direct-prompting question this whole thread
started from: you test this by using the plan mechanism as the test
harness — run all three variants as disposable trial contributions
against one real component, read them side by side, and only promote
if A beats B on that specific criterion. The plan isn't just the
output of the mentor process here, it's the instrument you run the
ablation through.

---

**[Andrej Karpathy - v3.3, extension on prior work]**

Zhang's ablation is the right falsification test, and it tells us
exactly what the trial mode needs to support — not just "try one
persona," but "try the controlled comparison." Concretely, two flags:

--trial-persona "<description>" --component ID [--compare-role
"<generic role framing>"] [--blend id1,id2]

Runs the described persona against exactly one existing component,
reading its current contributions via query.sh for real context. If
--compare-role is given, it also runs the generic-role variant (B) in
the same pass, so the A/B comparison happens in one trial rather than
two separate invocations that could drift in unrelated ways between
runs. --blend takes two already-registered mentor ids and runs them
jointly on the same component — useful for testing whether a blended
lens is actually additive or just one mentor's voice dominating, which
is its own version of the distinctiveness test. All output is clearly
labeled "[TRIAL — not saved to plan.yaml]" and none of it is written to
disk — this is a structural guarantee, not a step someone has to
remember, the same harness-over-prose argument I made in c12.

--promote-persona NAME — only valid after a passing trial (A beat B on
Zhang's criterion) exists earlier in the same conversation. It: (1)
writes references/personas/<name>.md following the existing file
convention — Style & Philosophy, Expertise Areas, Mentoring Approach,
Communication Style, When Planning Projects, Example Patterns —
populated from the trial's actual output, quoting the specific claims
that beat the generic-role variant, since those are exactly the claims
worth anchoring as worked examples; (2) adds the mentor to plan.yaml's
mentors array; (3) converts the trial's reasoning into a first-class
type: proposal contribution; (4) updates SKILL.md's description and
--persona argument line. Step 4 is the one place this workflow edits
the skill's own definition, which deserves the same care as any change
to shared infrastructure, not a rubber stamp because it's "just docs."

