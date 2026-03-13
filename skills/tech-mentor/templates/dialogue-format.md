# Dialogue Format Template

Use this format when multiple mentors are having an evolving conversation about the design. This preserves the full context of each perspective and makes the reasoning transparent.

## Structure

```markdown
---
title: [Project Name]
mentors:
  - name: [First Mentor]
    iterations: [1.0]
    focus: [their perspective]
    date: YYYY-MM-DD
  - name: [Second Mentor]
    iterations: [2.0]
    focus: [their perspective]
    date: YYYY-MM-DD
version: 2.0
last_updated: YYYY-MM-DD
---

# [Project Name]

[One-paragraph overview]

## Design Dialogue

### Thread: [Topic Name]

**[Mentor Name - v1.0 - Date]:**
[Initial perspective and reasoning]

Key points:
- Point 1
- Point 2
- Point 3

**[Another Mentor - v2.0 - Date, → FirstMentor on [Topic]]:**
Building on [FirstMentor]'s approach, I see [implications/concerns/extensions]:

1. **[Aspect 1]**: [Commentary]
2. **[Aspect 2]**: [Commentary]

**[First Mentor - v2.0 - Date, → SecondMentor on [concern]]:**
Good point about [concern]. Here's how we can address it:
[Response]

---

### Thread: [Another Topic]

[Continue same pattern]
```

## Example

```markdown
---
title: Propensity Model with Uncertainty
mentors:
  - name: Andrej Karpathy
    iterations: [1.0]
    focus: ML architecture, uncertainty quantification
    date: 2026-03-13
  - name: Eric Zhang
    iterations: [2.0]
    focus: Systems design, UX considerations
    date: 2026-03-13
version: 2.0
last_updated: 2026-03-13
---

# Propensity Model with Uncertainty

Building a batch prediction pipeline for click-through propensity with calibrated uncertainty estimates.

## Design Dialogue

### Thread: Uncertainty Quantification Approach

**Andrej Karpathy - v1.0 - 2026-03-13:**
For uncertainty in tabular data with XGBoost, I recommend quantile regression. Train the model with `objective='reg:quantileerror'` to predict p10, p50, p90 simultaneously.

Why quantile regression:
- Native XGBoost support, no external dependencies
- Single model outputs multiple quantiles efficiently
- Distribution-free (no parametric assumptions)
- Natural confidence intervals: [p10, p90] gives 80% coverage

Alternative considered: Conformal prediction would work but requires post-hoc calibration set computation. Quantile regression is simpler for this use case.

**Eric Zhang - v2.0 - 2026-03-13, → Karpathy on quantile regression:**
The quantile approach is technically sound, but let's think about the system and user implications:

1. **Storage scaling**: Three predictions per order means 3× writes to the feature store
   - At 4M orders × 3-5 runs/day = ~60M writes daily
   - Recommendation: Use batched writes, consider delta encoding [p50, (p50-p10), (p90-p50)]

2. **UX considerations**: How will stakeholders interpret [p10, p90] intervals?
   - Most business users don't understand confidence intervals naturally
   - Suggest: Add abstraction layer mapping to "High/Medium/Low confidence" tiers
   - This makes predictions actionable without losing statistical rigor

3. **Operational complexity**: More outputs = more monitoring, more failure modes
   - Need validation that p10 ≤ p50 ≤ p90 (quantiles can cross when trained independently)
   - Separate drift alerts for each quantile's distribution

**Andrej Karpathy - v2.0 - 2026-03-13, → Zhang on storage and UX:**
Excellent points. On storage optimization - delta encoding is smart and also enforces monotonicity at write time, solving the quantile crossing issue.

On UX abstraction: You're right that raw quantiles aren't user-friendly. Here's a principled approach:
- Compute `confidence_width = p90 - p10`
- Calibrate thresholds on validation set (e.g., width < 0.15 = "high confidence")
- This preserves statistical foundation while making it interpretable

We should track calibration of these tiers too: does "high confidence" actually correlate with better predictions?

---

### Thread: Batch Inference Architecture

**Andrej Karpathy - v1.0 - 2026-03-13:**
For 4M predictions, batch inference on Vertex AI is the right pattern. Real-time would be wasteful since orders don't change constantly.

Pipeline: Features → XGBoost → Calibration → Feature Store → API lookup

**Eric Zhang - v2.0 - 2026-03-13, → Karpathy on batch pattern:**
Agree on batch approach. Adding system considerations:

- **Staleness handling**: New orders won't have predictions immediately
  - Fallback strategy: default propensity value, or wait for next batch run?
  - SLA: How fresh do predictions need to be? 1 hour? 6 hours?

- **API design**: The FastAPI service should expose freshness metadata
  - Include `prediction_timestamp` and `model_version` in every response
  - Downstream systems can decide if prediction is too stale

- **Graceful degradation**: What happens when feature store has cache miss?
  - Option 1: Return 404, client handles fallback
  - Option 2: On-demand prediction (slow but works)
  - Option 3: Return last known prediction with stale=true flag
```

## When to Use This Format

- Early exploration with conflicting approaches
- Trade-offs between perspectives need explicit discussion
- Educational contexts where reasoning process matters
- Capturing "design debate" is valuable for future reference
