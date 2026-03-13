---
name: md-to-issues
description: Decompose a free-form markdown action plan, design doc, or planning document into a structured JSON array of atomic GitLab issues. Use this skill whenever the user has a .md file with a plan, discussion, technical spec, or progression notes and wants to convert it into actionable GitLab issues. Also trigger when the user mentions "break this into issues", "create issues from this plan", "turn this into a backlog", or asks to decompose any markdown document into ticketable work items.
---

# md-to-issues

Transform a free-form markdown document (action plan, design doc, mentor session notes, code review, etc.) into a structured JSON array of atomic GitLab issues.

## Core Philosophy

The input is conversational and free-form. Do NOT parse structure — read intent.

For each chunk of work, ask: **"What is this trying to achieve?"** That question determines issue boundaries — not bullet points, not headings, not how the text is organized.

---

## Atomicity Rule

> An issue is atomic when it can be **implemented, reviewed, and merged independently**.  
> If you can't describe the resulting PR in one sentence → split it.

Examples of non-atomic → atomic splits:
- "Set up auth" → `Create User model + migration`, `Implement JWT middleware`, `Add login/logout endpoints`, `Auth guard decorator for protected routes`
- "Improve performance" → `Add database index on orders.user_id`, `Cache product listing query`, `Lazy-load product images on listing page`

---

## Decomposition Process

**Step 1 — Read the whole document first.** Understand the full scope before creating a single issue.

**Step 2 — Identify themes.** Group related intent. A theme is not an issue — it's a parent concept that will spawn N issues.

**Step 3 — Decompose each theme into atomic issues.** Each issue must be independently shippable.

**Step 4 — Write each issue using the template below.**

---

## Issue Template

```json
{
  "title": "Verb + noun, imperative tone. E.g: 'Add JWT middleware to Express app'",
  "description": "## Context\n{Why this issue exists. What problem it solves or what it enables. 2-4 sentences max. Reference the broader feature/goal.}\n\n## Tasks\n\n* [ ] {Concrete subtask}\n* [ ] {Concrete subtask}\n\n## Success Criteria\n\n{How do we know this is done? Observable, testable outcome. Not 'it works' — be specific.}",
  "labels": ["{inferred label}"]
}
```

---

## Title Guidelines

- Imperative verb: Add, Create, Implement, Refactor, Fix, Extract, Connect, Remove, Configure
- Specific: `Add rate limiting to /api/auth endpoints` not `Improve security`
- No jargon unless it's in the original doc

---

## Label Vocabulary

Infer from context. Use one or two max per issue:

| Label | When to use |
|---|---|
| `feature` | New user-facing functionality |
| `refactor` | Restructuring without behavior change |
| `bug` | Something broken that needs fixing |
| `dx` | Developer experience, tooling, scripts |
| `infra` | CI/CD, deployment, cloud config |
| `spike` | Research or proof-of-concept with unknown scope |
| `docs` | Documentation only |
| `test` | Testing only |
| `chore` | Dependency updates, cleanup, maintenance |

---

## Tasks Section

- Each task is a concrete, single action. Not "implement feature" — `Add POST /login handler that validates credentials and returns JWT`
- 2–6 tasks per issue. If you need more, the issue isn't atomic.
- Tasks should be ordered logically (dependency order when relevant)

---

## Success Criteria

Be specific and testable. Examples:

❌ "Auth works correctly"  
✅ "Authenticated requests return 200. Unauthenticated requests return 401. Token expires after 24h."

❌ "Code is cleaner"  
✅ "Module has single responsibility. No function exceeds 30 lines. All exports are named."

---

## Output Format

Return **only** a valid JSON array. No preamble, no explanation, no markdown fences.

```json
[
  {
    "title": "...",
    "description": "...",
    "labels": ["..."]
  }
]
```

If the document is ambiguous about scope or intent, make a reasonable judgment call and note it in the issue's Context section. Do not ask for clarification — decompose and annotate.

---

## Edge Cases

**Vague tasks** (e.g., "improve the onboarding flow") → Create a `spike` issue: "Audit current onboarding flow and define improvement scope"

**Already-atomic tasks** → One issue, keep it tight.

**Deeply nested work** → Flatten. GitLab issues are flat. If there's a parent concept, reference it in Context.

**Technical debt mentioned** → Make it a `refactor` or `chore` issue. Do not skip it.
