# Multi-Mentor Collaboration Guide

When multiple mentors contribute to a plan, use this guide to structure their perspectives effectively.

## Three Collaboration Formats

### 1. Dialogue Format

**When to use:** Early exploration, conflicting approaches, educational contexts where reasoning process matters.

**Structure:** Conversation threads between mentors with clear attribution and cross-references.

**See:** [templates/dialogue-format.md](templates/dialogue-format.md) for complete example.

**Key pattern:**
```markdown
**[Mentor Name - v1.0 - Date]:**
[Initial perspective and reasoning]

**[Another Mentor - v2.0 - Date, → FirstMentor on Topic]:**
Building on [FirstMentor]'s approach, I see...

**[First Mentor - v2.0 - Date, → SecondMentor on concern]:**
Good point. Here's how we address it...
```

### 2. Annotated Format

**When to use:** Multiple mentors contributing independent insights, perspectives are complementary, need clear attribution.

**Structure:** Component-based with inline mentor sections.

**See:** [templates/annotated-format.md](templates/annotated-format.md) for complete example.

**Key pattern:**
```markdown
## Component Name

**[Mentor Name - v1.0]**
[Original component description and rationale]

---

**[Another Mentor - v2.0, building on MentorName's approach]**
From a [perspective] lens, this component also needs:
[Commentary with specific concerns or extensions]
```

### 3. Unified Format (Default)

**When to use:** Synthesizing perspectives into coherent whole, final production documentation, simpler reading experience.

**Structure:** Integrated narrative with grouped perspectives.

**See:** [templates/unified-format.md](templates/unified-format.md) for complete example.

**Key pattern:**
```markdown
## Component Name

[Unified description incorporating multiple viewpoints]

**Implementation Considerations:**

*From ML perspective:*
- Consideration specific to that domain

*From systems perspective:*
- Consideration specific to that domain

*At scale:*
- Consideration specific to scale
```

## Document Metadata Structure

All multi-mentor documents should include this metadata header:

```markdown
---
title: Project Name
mentors:
  - name: First Mentor
    iterations: [1.0]
    focus: their perspective
    date: YYYY-MM-DD
  - name: Second Mentor
    iterations: [2.0]
    focus: their perspective
    date: YYYY-MM-DD
version: 2.0
last_updated: YYYY-MM-DD
base_version: 1.0
---
```

## Cross-Reference Syntax

Use clear attribution when mentors respond to each other:

- `[Mentor - vX.X]` - Original contribution
- `[Mentor - vX.X, → Other on Topic]` - Responding to another mentor
- `[Mentor - vX.X, building on Other's approach]` - Extending another's idea
- `[Mentor - vX.X, alternative to Other's suggestion]` - Proposing alternative

## Refinement Process Workflow

When refining an existing plan with a different mentor:

```
Refinement Checklist:
- [ ] Step 1: Read existing plan thoroughly
- [ ] Step 2: Identify your perspective's unique value
- [ ] Step 3: Find gaps or implications not yet addressed
- [ ] Step 4: Acknowledge previous mentor's work explicitly
- [ ] Step 5: Add commentary that BUILDS UPON, doesn't replace
- [ ] Step 6: Update metadata with new mentor and version
- [ ] Step 7: Ensure chosen format is consistent throughout
```

### Step-by-Step

**Step 1: Read existing plan thoroughly**
- Parse metadata to identify previous mentors and versions
- Understand technical approach proposed
- Note focus areas already covered

**Step 2: Identify your perspective's unique value**
- **Karpathy → Zhang**: ML design to systems/UX implications
- **Karpathy → Dean**: Model approach to scale/performance
- **Karpathy → Viégas & Wattenberg**: Model architecture to interpretability/visualization
- **Zhang → Karpathy**: User needs to ML feature requirements
- **Zhang → Dean**: UX design to operational/scale constraints
- **Zhang → Viégas & Wattenberg**: UX needs to visualization/explainability design
- **Dean → Karpathy**: Scale requirements to model architecture
- **Dean → Zhang**: Performance constraints to UX trade-offs
- **Dean → Viégas & Wattenberg**: Scale constraints to visualization scalability
- **Viégas & Wattenberg → Karpathy**: Add interpretability to ML design
- **Viégas & Wattenberg → Zhang**: Visual analytics for better UX
- **Viégas & Wattenberg → Dean**: Visualization challenges at scale

**Step 3: Find gaps or implications**
- What has been overlooked from your domain?
- What are the downstream implications of proposed approaches?
- What risks or considerations haven't been addressed?

**Step 4: Acknowledge previous work**
- Reference specific points from the existing plan
- Use phrases like "Building on X's approach..." or "X's suggestion for Y is sound, but..."
- Never just rewrite without referencing what came before

**Step 5: Add commentary**
Critical rules:
- NEVER completely rewrite the existing plan
- BUILD UPON, don't replace
- REFERENCE specific sections/points from the original
- ADD new perspective, don't duplicate existing information

**Step 6: Update metadata**
- Increment version number (1.0 → 2.0)
- Add new mentor to mentors list with iteration number
- Update `last_updated` date
- Keep `base_version` pointing to original

**Step 7: Ensure format consistency**
- If previous plan used dialogue, continue dialogue (or explicitly switch)
- If using unified, maintain the grouped perspective pattern
- If using annotated, add new sections with proper headers

## Quality Checks Before Finalizing

- [ ] Does this ADD value or just restate existing content?
- [ ] Is the new perspective clearly distinct from existing ones?
- [ ] Are previous contributions acknowledged and respected?
- [ ] Is attribution clear (who said what)?
- [ ] Does format match requested style?
- [ ] Is metadata updated correctly?
- [ ] Are cross-references accurate?

## Common Multi-Mentor Patterns

### Pattern: ML → Systems → Scale

1. **Karpathy (v1.0)**: Proposes model architecture, training approach, data pipeline
2. **Zhang (v2.0)**: Adds operational complexity analysis, UX considerations, deployment concerns
3. **Dean (v2.5)**: Provides scale analysis, performance optimization, cost estimation

### Pattern: ML → Interpretability → Production

1. **Karpathy (v1.0)**: Proposes model architecture and training approach
2. **Viégas & Wattenberg (v2.0)**: Adds interpretability analysis, visualization strategy, understanding model behavior
3. **Zhang (v2.5)**: Evaluates how to surface insights to users, operational monitoring

### Pattern: Scale → ML/Systems

1. **Dean (v1.0)**: Defines scale requirements, constraints, performance targets
2. **Karpathy (v2.0)**: Proposes ML approach within those constraints
3. **Zhang (v2.5)**: Evaluates if solution actually meets usability requirements at scale

### Pattern: Systems → ML → Systems

1. **Zhang (v1.0)**: Defines user needs, workflow design, UX requirements
2. **Karpathy (v2.0)**: Proposes ML approaches to meet those needs
3. **Zhang (v2.5)**: Evaluates if ML solution actually meets original UX constraints

### Pattern: Interpretability → ML → Scale

1. **Viégas & Wattenberg (v1.0)**: Defines what needs to be understood, visualization goals
2. **Karpathy (v2.0)**: Proposes ML architecture with interpretability hooks
3. **Dean (v2.5)**: Evaluates cost of interpretability at scale, optimization strategies

## What NOT to Do (Anti-Patterns)

❌ Rewriting entire sections without referencing original
❌ Contradicting previous mentor without acknowledging the conflict
❌ Adding redundant information already covered
❌ Changing format mid-document (dialogue → unified)
❌ Losing previous mentor's contributions
❌ Missing metadata updates
❌ Generic comments that don't leverage persona expertise

## Examples of Good Cross-Mentor Dialogue

### Good Example: Builds on Existing Work

```markdown
**[Eric Zhang - v2.0, → Karpathy on quantile regression]:**
Karpathy's quantile regression approach (v1.0) is technically sound,
but raises three operational concerns:

1. Storage scaling: Three predictions per order = 3× feature store writes
2. UX considerations: Stakeholders don't understand confidence intervals
3. Operational complexity: More outputs = more monitoring complexity

Recommendations:
- Use delta encoding for storage efficiency
- Add UX abstraction layer mapping to "High/Medium/Low confidence"
- Validate monotonicity: p10 ≤ p50 ≤ p90
```

This is good because it:
- Explicitly references Karpathy's v1.0 work
- Acknowledges the technical soundness
- Adds new perspective from systems/UX domain
- Provides concrete recommendations

### Bad Example: Ignores Existing Work

```markdown
**[Eric Zhang - v2.0]:**
We should use confidence intervals. Here's how to implement them...
```

This is bad because it:
- Doesn't acknowledge Karpathy already proposed quantile regression
- Duplicates existing content
- Fails to build on previous work

## Workflow Example: Three-Mentor Collaboration

### Iteration 1: Initial ML Plan (Karpathy)
```bash
/tech-mentor "Build propensity model with uncertainty"
```
→ Creates plan.md v1.0 with ML architecture

### Iteration 2: Add Systems/UX Perspective (Zhang)
```bash
/tech-mentor --persona "Eric Zhang" --refine plan.md --format dialogue \
  "Review from systems and UX perspective"
```
→ Updates plan.md to v2.0 with Zhang's commentary

### Iteration 3: Scale Analysis (Dean)
```bash
/tech-mentor --persona "Jeff Dean" --refine plan.md \
  --comment-on "Batch Prediction Pipeline" \
  "Analyze at 100x scale"
```
→ Updates plan.md to v2.5 with focused scale analysis
