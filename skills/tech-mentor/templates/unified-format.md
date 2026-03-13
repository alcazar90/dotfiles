# Unified Format Template

Use this format when synthesizing multiple perspectives into a single coherent narrative. Best for final production documentation where narrative flow matters more than attribution details.

## Structure

```markdown
---
title: [Project Name]
mentors:
  - name: [Mentor 1]
    iterations: [1.0]
    focus: [perspective]
    date: YYYY-MM-DD
  - name: [Mentor 2]
    iterations: [2.0]
    focus: [perspective]
    date: YYYY-MM-DD
version: 2.0
last_updated: YYYY-MM-DD
---

# [Project Name]

[One-paragraph overview synthesizing all perspectives]

## Component Name

[Unified description incorporating multiple viewpoints]

**What it does:**
- Point incorporating ML perspective
- Point incorporating systems perspective
- Point incorporating scale perspective

**Why it's needed:**
[Synthesized rationale from multiple angles]

**Implementation Considerations:**

*From [perspective 1]:*
- Consideration specific to that domain

*From [perspective 2]:*
- Consideration specific to that domain

*At scale:*
- Consideration specific to scale

**Trade-offs:**
[Unified discussion of trade-offs across perspectives]
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
  - name: Jeff Dean
    iterations: [2.5]
    focus: Scale analysis, performance optimization
    date: 2026-03-13
version: 2.5
last_updated: 2026-03-13
---

# Propensity Model with Uncertainty

Building a production-grade batch prediction pipeline for click-through propensity on airplane ancillary orders. The system handles 4M orders per run (3-5 runs daily) and provides not just point estimates but calibrated probabilities with uncertainty bounds, enabling risk-aware business decisions.

## Technical Approach

### Quantile Regression for Uncertainty

We'll use XGBoost with quantile regression to predict three values simultaneously: p10 (lower bound), p50 (median), and p90 (upper bound). This gives us natural prediction intervals without parametric assumptions.

**Why quantile regression:**
- Native XGBoost support via `objective='reg:quantileerror'`
- Single model outputs multiple quantiles efficiently
- Distribution-free approach (no Gaussian assumptions)
- 80% confidence interval = [p10, p90]

**Storage optimization:**
To reduce feature store writes and enforce monotonicity, we use delta encoding: store [p50, (p50-p10), (p90-p50)] instead of three absolute values. This compresses from 12 bytes to 8 bytes per prediction (33% reduction) and prevents quantile crossing at write time.

**At scale (100x):**
Even at 400M predictions, storage remains manageable at ~3.2 GB per run. The main bottleneck shifts to write throughput (222K writes/sec), which requires Redis-based feature store rather than Firestore.

## Component 2: Calibration Module

Post-hoc calibration ensures our predicted probabilities are trustworthy. If the model outputs 30%, it should actually mean 30% in practice.

**What it does:**
- Fits isotonic regression on validation set: `calibrated_score = f(raw_score)`
- Transforms raw XGBoost outputs to calibrated probabilities
- Evaluates calibration quality with reliability diagrams and ECE
- Stores calibration function bundled with model artifacts

**Why it's needed:**
Raw XGBoost outputs are often poorly calibrated. Isotonic regression corrects this while preserving ranking, and is more flexible than Platt scaling (doesn't assume sigmoid shape).

**Implementation Considerations:**

*From ML perspective:*
- Use held-out validation set (distinct from test set)
- Monitor Expected Calibration Error (ECE) over time
- Re-calibrate monthly or when ECE degrades beyond 0.05 threshold
- Isotonic regression requires minimal computation (~seconds to fit)

*From systems perspective:*
- Bundle calibration function with model artifact (single deployable unit)
- Deploy calibration before new model version to prevent version mismatch
- Cache calibration function in memory per worker (don't reload per prediction)
- Add UX abstraction layer for non-technical stakeholders

*At scale:*
- Inference cost: ~1μs per prediction (binary search in calibration curve)
- Memory footprint: <1MB per worker
- At 4M predictions: ~4ms total overhead (negligible)
- At 400M predictions (100x): still negligible at 400ms

**UX Abstraction Layer:**

Business users struggle with raw probabilities and confidence intervals. Add a mapping layer:

```python
def get_confidence_tier(calibrated_score, width):
    """Translate statistical outputs to actionable categories."""
    if width < 0.15 and calibrated_score > 0.3:
        return "high_confidence_positive"
    elif width < 0.15 and calibrated_score < 0.2:
        return "high_confidence_negative"
    else:
        return "uncertain"
```

This preserves statistical rigor while making predictions consumable by downstream systems. Track calibration of these tiers separately: does "high confidence" actually correlate with better accuracy?

## Component 3: Batch Prediction Pipeline

Vertex AI pipeline running 3-5x daily to score all active orders. Batch processing is 100x more efficient than real-time since orders don't change constantly.

**Pipeline flow:**
1. Pull latest features from Dataform
2. Load XGBoost models (p10, p50, p90)
3. Run batch prediction on ~4M orders across parallel workers
4. Apply calibration function
5. Compute derived metrics (confidence_width = p90 - p10, confidence_tier)
6. Write to feature store with atomic batch commits

**Output per order:**
```json
{
  "order_id": "ABC123",
  "propensity_p50": 0.28,
  "propensity_p10": 0.15,
  "propensity_p90": 0.42,
  "calibrated_score": 0.26,
  "confidence_width": 0.27,
  "confidence_tier": "uncertain",
  "model_version": "v1.2.3",
  "prediction_timestamp": "2026-03-13T10:30:00Z"
}
```

**Implementation Considerations:**

*From ML perspective:*
- Parallelize across Vertex AI workers (current: ~20 workers)
- Validate outputs: ensure p10 ≤ p50 ≤ p90
- Monitor prediction distribution drift over time
- Log inference metrics (throughput, latency) per batch

*From systems perspective:*
- **Staleness handling**: New orders lack predictions immediately. Options:
  - Return 404 until next batch (simple, fails fast) ← start here
  - On-demand fallback prediction (complex, always works)
  - Default propensity value (simple, potentially misleading)
- **Failure modes**: Atomic batch writes to prevent partial updates
- **API freshness metadata**: Include `prediction_age` so clients decide if too stale
- **SLA definition**: Predictions must be <6 hours old for most use cases

*At scale (100x → 400M predictions):*
- Target: 30-minute batch completion
- Required throughput: 222K predictions/second
- Workers needed: ~200 (assuming 1K preds/sec/worker)
- Network: 107 MB/sec sustained upload (well within GCP limits)
- Feature store: Redis (100K+ writes/sec) vs Firestore (10K/sec max)
- **Cost estimate**: ~$250/day compute + $500/month Redis = ~$8K/month
- Main constraint: Vertex AI quota (request 200 parallel workers)

**Trade-offs:**

Batch vs real-time:
- **Chosen**: Batch predictions every few hours
- **Pro**: Much simpler architecture, lower cost, higher throughput
- **Con**: Predictions can be stale by hours
- **Why**: Orders don't change rapidly; staleness is acceptable for this use case

Atomic batch writes vs streaming writes:
- **Chosen**: Atomic batch commits
- **Pro**: Prevents inconsistent state during failures
- **Con**: Higher latency to first availability after batch starts
- **Why**: Consistency more important than incremental availability

Redis vs Firestore for feature store:
- **Chosen**: Redis (future-proof for 100x scale)
- **Pro**: Higher write throughput, lower latency
- **Con**: More operational complexity than managed Firestore
- **Why**: Write throughput becomes bottleneck at scale; invest early

## Success Criteria

**Calibration Quality:**
- Expected Calibration Error (ECE) < 0.05 on test set
- Reliability diagram shows predictions close to diagonal
- Brier score beats baseline by ≥10%

**Uncertainty Estimation:**
- 80% confidence intervals cover true outcome ~80% of time
- Confidence width correlates with prediction error
- High confidence tier has measurably better accuracy than uncertain tier

**System Performance:**
- Batch prediction completes in <30 minutes for 4M orders
- FastAPI p99 latency <50ms
- Feature store cache hit rate >99% during business hours

**Operational Health:**
- Calibration drift alerts trigger before business impact
- Pipeline success rate >99.5%
- Zero incidents from stale predictions (SLA violations)

**Business Value:**
- Downstream systems successfully use confidence tiers for decision logic
- A/B test shows confidence-aware strategy outperforms point-estimate-only baseline
```

## When to Use This Format

- Perspectives are synthesized into coherent whole
- Final production documentation
- Narrative flow matters more than explicit attribution
- Simpler reading experience for stakeholders
- All perspectives are complementary (no major conflicts to highlight)
