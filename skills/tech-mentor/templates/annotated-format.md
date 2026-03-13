# Annotated Format Template

Use this format when multiple mentors contribute independent insights to different parts of the system. Maintains clear attribution while preserving the component-based structure.

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

[One-paragraph overview]

## Component Name

**[Mentor Name - v1.0]**

[Original component description and rationale]

**What it does:**
- Point 1
- Point 2

**Why it's needed:**
[Explanation]

---

**[Another Mentor - v2.0, building on MentorName's approach]**

From a [perspective] lens, this component also needs:

**[Aspect Title]:**
[Commentary with specific concerns or extensions]

**[Another Aspect]:**
[More commentary]

---

## Another Component

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
  - name: Jeff Dean
    iterations: [2.5]
    focus: Scale analysis, performance optimization
    date: 2026-03-13
version: 2.5
last_updated: 2026-03-13
---

# Propensity Model with Uncertainty

Building a batch prediction pipeline for click-through propensity on airplane ancillary orders (~4M orders, 3-5 runs per day) with calibrated uncertainty estimates.

## Component 2: Calibration Module

**[Andrej Karpathy - v1.0]**

Post-hoc calibration using isotonic regression on validation predictions.

**What it does:**
- Takes raw XGBoost predictions on validation set
- Fits isotonic regression: `calibrated_score = f(raw_score)`
- Saves calibration function for inference time
- Evaluates calibration with reliability diagrams

**Why it's needed:**
XGBoost raw outputs are often not well-calibrated. If the model says 30% probability, we want it to actually mean 30% in practice. Isotonic regression corrects this while preserving ranking.

**Implementation:**
```python
from sklearn.isotonic import IsotonicRegression

iso_reg = IsotonicRegression(out_of_bounds='clip')
iso_reg.fit(y_pred_val, y_true_val)

# Apply at inference
calibrated_preds = iso_reg.transform(raw_preds)
```

**Why isotonic over Platt scaling:**
Isotonic regression is more flexible - doesn't assume sigmoid shape. Better for tree-based models.

---

**[Eric Zhang - v2.0, building on Karpathy's calibration approach]**

From a systems and operational perspective, the calibration module introduces deployment complexity:

**Versioning and Deployment:**
- Calibration function must be versioned alongside models
- Need to ensure calibration artifact and model version stay in sync
- Deployment order matters: deploy calibration before new model version
- Risk: deploying new model with old calibration breaks everything

**Recommendation:** Store calibration as part of model artifact (single bundle), not separate file.

**UX Layer Addition:**
Add a translation layer that converts calibrated scores to business-friendly tiers:

```python
def get_confidence_tier(calibrated_score, width):
    """Map probabilistic outputs to actionable categories."""
    if width < 0.15 and calibrated_score > 0.3:
        return "high_confidence_positive"
    elif width < 0.15 and calibrated_score < 0.2:
        return "high_confidence_negative"
    else:
        return "uncertain"
```

This gives downstream systems actionable categories instead of raw probabilities that non-technical stakeholders struggle to interpret.

**Monitoring Needs:**
- Track calibration drift over time (Expected Calibration Error on fresh data)
- Alert when ECE degrades beyond threshold
- Re-calibrate monthly or when drift detected

---

**[Jeff Dean - v2.5, on deployment complexity and scale]**

**Performance at Scale:**
At 4M predictions per batch, isotonic regression inference is negligible:
- Lookup time: ~1μs per prediction (binary search in calibration curve)
- Total overhead: ~4ms per batch
- Memory: calibration function is <1MB, easily cached

**Recommendation:**
- Cache calibration function in memory per worker instance
- Don't reload from disk per prediction
- Pre-load during worker initialization

**Scale Math:**
- 4M predictions × 3-5 runs/day = 12-20M calibrations/day
- At 1μs each = 12-20 seconds total CPU time/day
- Negligible cost - don't optimize this prematurely

**Monitoring at Scale:**
Weekly calibration health check:
```python
# Log calibrated vs raw score distributions
weekly_ece = compute_calibration_error(preds, actuals)
if weekly_ece > 0.05:
    trigger_recalibration_pipeline()
```

Track this as a time series to detect gradual drift before it impacts business metrics.

---

## Component 3: Batch Prediction Pipeline

**[Andrej Karpathy - v1.0]**

Vertex AI Pipeline that runs 3-5x per day to score all active orders.

**What it does:**
- Pulls latest features from Dataform
- Loads trained XGBoost models (p10, p50, p90)
- Runs batch prediction on ~4M orders
- Applies calibration function
- Computes derived metrics (confidence_width = p90 - p10)
- Writes to feature store

**Why batch over real-time:**
Orders don't change constantly - batch is 100x more efficient. We can parallelize across Vertex AI workers.

---

**[Eric Zhang - v2.0, building on Karpathy's batch approach]**

**Operational Considerations:**

**Staleness Handling:**
New orders won't have predictions immediately. Design decision needed:
- Option 1: Return 404 until next batch (simple, fails fast)
- Option 2: On-demand prediction fallback (complex, always works)
- Option 3: Default propensity value (simple, potentially wrong)

Recommendation: Start with Option 1 + monitoring. If cache miss rate >1%, add Option 2.

**Pipeline Failure Modes:**
- What happens if batch run fails mid-execution?
- Partial writes to feature store = inconsistent state
- Need: Atomic batch write or clear marking of failed runs

**User-Facing SLA:**
- Define freshness requirement: predictions must be <6 hours old?
- API should include `prediction_age` in response
- Clients decide if prediction is too stale for their use case

---

**[Jeff Dean - v2.5, analyzing scale at 100x volume]**

**Scale Analysis: 400M predictions (100x current)**

**Throughput Requirements:**
- 400M predictions in 30 minutes (target)
- = 13.3M predictions/minute
- = 222K predictions/second
- Need: ~200 Vertex AI workers (assuming 1K preds/sec/worker)

**Storage Impact:**
- Raw: 400M × 3 quantiles × 4 bytes = 4.8 GB per run
- Delta-encoded: 400M × 8 bytes = 3.2 GB per run
- At 5 runs/day × 30 days retention = 480 GB
- Cost: ~$10/month on GCS (negligible)

**Network Bottleneck:**
- Uploading 3.2 GB to feature store in 30 min
- = 107 MB/sec sustained
- Well within GCP network limits (10 Gbps+)

**Feature Store Write Throughput:**
- 400M writes in 30 minutes = 222K writes/sec
- Firestore: max 10K writes/sec/database → need 23 databases (sharded)
- Redis: handles 100K+ writes/sec easily → no sharding needed

**Recommendation:** Redis-based feature store, with sharding strategy ready but not needed at 100x.

**Cost Estimate (100x scale):**
- Compute: 200 workers × 30 min × $0.50/hour = $50/run × 5 runs/day = $250/day
- Storage: $10/month
- Feature store (Redis): $500/month
- **Total: ~$8K/month at 100x scale**

Still economically viable. Main bottleneck: Vertex AI quota (200 parallel workers).
```

## When to Use This Format

- Multiple mentors contributing independent insights
- Perspectives are complementary, not conflicting
- Need to track "who said what" for accountability
- Moderate document complexity
- Each mentor focuses on different aspects of the same components
