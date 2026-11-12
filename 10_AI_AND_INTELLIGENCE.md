# 10 — AI, Intelligence and Procurement Optimisation

**Principle:** intelligence **recommends**, and humans and physical evidence **decide**. Every output is explainable, versioned (`algorithm_version` / `model_version`) and stored. Predicted or planned quantities never enter the custody ledger (03 §2) or the EPR allocation ledger (05 §6).

| # | Capability | MVP approach | Priority |
|---|---|---|---|
| 1 | Plastic image identification | Fine-tuned small CNN (ONNX) | P1 |
| 2 | Collector & recycler matching | Weighted score | P1 |
| 3 | Smart feedstock aggregation | Greedy heuristic + rules | **P0 basic** |
| 4 | Landed cost optimiser | Deterministic formula | **P0 basic** |
| 5 | Supplier reliability & rejection risk | Rule-based indicators | P1 (ML risk: P2) |
| 6 | Supply & demand forecasting | Historical averages / seasonal naive | P1 (advanced: P2) |
| 7 | Verified yield analytics | Measured arithmetic | **P0** (part of the material passport) |
| 8 | Anomaly detection | Rules | P1 |

## 1. Plastic image identification

- Classes: PET, HDPE, PVC, LDPE, PP, PS, OTHER/UNKNOWN.
- Model: MobileNetV3/EfficientNet-B0 fine-tuned on public plastic-waste image sets plus locally labelled photos. It runs on CPU via ONNX.
- Output: top-3 classes with softmax confidence.

**Thresholds [DESIGN]:**

| Confidence | Behaviour |
|---|---|
| ≥ 0.80 | Pre-select the class; the user still clicks confirm |
| 0.50 – 0.80 | Show the top-3 and require an explicit choice |
| < 0.50 or OTHER | "Not sure": manual selection required |

- UI copy: "Photo-based suggestion only, not a material test. The recycler confirms material on receipt."
- Feedback loop: `ai_predictions.user_confirmed_code` and the recycler's receipt material form labelled data for retraining.
- **Limits:** resin codes are often invisible, colour and dirt mislead the model, and multilayer packaging is hard to classify. A photo cannot detect additives or contamination.

## 2. Matching

### 2.1 Generator → collector (ranks offers and available listings)

`score = 0.35·proximity + 0.20·material_fit + 0.15·capacity_fit + 0.15·reliability + 0.15·availability_overlap`

- Each term is normalised to [0, 1]. Material fit is a hard filter (0 means excluded), as is the minimum pickup kg.
- Reliability comes from §5. A collector with **fewer than 5 transactions** gets the neutral value 0.5 and is labelled "new".

### 2.2 Collector → recycler

Hard filters: material, min_kg, quality specification. Then rank by **net value per km**: `(price_per_kg × expected_accepted_kg − transport_cost) / distance`, using §4 for the transport cost.

**Explainability:** every ranking returns its components, for example `{"proximity":0.9,"material_fit":1,"reliability":0.62,"reasons":["2.1 km away","accepts PET","92% on-time over 38 pickups"]}`.

## 3. Smart Feedstock Aggregation Engine

### 3.1 Problem
A recycler posts a demand, for example **500 kg PP, quality ≥ B, contamination ≤ 5%, needed by 30 Nov**. Individual listings are small (10–80 kg). The engine proposes a set of **existing LISTED batches** (confirmed supply only) plus a collector and a pickup sequence.

### 3.2 Inputs
- Demand profile (05 §4.9): material, kg, min lot, quality, contamination, deadline, storage capacity.
- Candidate batches: status LISTED, same `material_category_id`, availability window before the deadline, not in another active plan.
- Expected usable factor per batch: `(1 − expected_rejection_rate) × (1 − expected_process_loss)`, taken from the generator's history (§5) and the recycler's measured yield (§7). If history is missing, conservative defaults apply [ASSUMPTION A-15].
- Collectors: service area, capacity, materials, reliability.
- Cost assumptions (§4).

### 3.3 Hard rules
1. **Same material category only.** The engine never mixes polymers (e.g. PP with HDPE) or mixes with OTHER/UNKNOWN. Batches whose material is unconfirmed (AI-only, low confidence) are excluded.
2. A batch's estimated contamination or expected grade must meet the specification. If unknown, the batch is included with an "inspection recommended" tag.
3. Planned kg per batch ≤ the batch's `estimated_kg`. Σ planned kg ≤ Σ source estimates (trivially true; a DB check enforces it).
4. A batch can belong to at most one ACTIVE plan (partial unique index).
5. Total planned kg ≤ collector capacity for the window, and ≤ recycler storage headroom.

### 3.4 Algorithm (MVP: transparent greedy)
1. Filter the candidates using the hard rules.
2. For each candidate, compute `expected_usable_kg` and its landed cost per usable kg, including the marginal transport cost from the cluster centroid.
3. Cluster by locality and time window (simple grid / DBSCAN on lat/lng with a 3 km radius).
4. Pick the best collector for each cluster (score from §2.1, constrained by capacity).
5. Add batches in ascending landed cost per usable kg until Σ expected usable kg ≥ target, or until the candidates run out.
6. Sequence pickups by nearest-neighbour from the collector base (P2: proper VRP).
7. Output whether the plan is feasible, any shortfall, and the reasons.

### 3.5 Output (stored as `aggregation_plans` + `aggregation_plan_items`)

```json
{
  "plan_code": "AGP-2026-0031", "material": "PP", "target_kg": "500.000",
  "est_total_kg": "560.000", "est_usable_kg": "498.400",
  "fulfils_requirement": false, "shortfall_kg": "1.600",
  "suggested_collector": "Andheri Green Movers",
  "est_collection_cost": "3920.00", "est_landed_cost": "6230.00",
  "landed_cost_per_usable_kg": "12.50",
  "items": [
    {"batch_code":"RL-MUM-2026-000201","seq":1,"est_kg":"60.000","est_usable_kg":"54.000",
     "reasons":["PP confirmed by generator","1.2 km from cluster centre","generator rejection 4% over 9 batches"]}
  ],
  "excluded": [{"batch_code":"RL-MUM-2026-000188","reason":"material unconfirmed (AI 0.46)"}],
  "assumptions_version": "pricing-v3", "algorithm_version": "agg-greedy-1.0"
}
```

### 3.6 Human acceptance and identity preservation
- Plan states: DRAFT → PROPOSED → ACCEPTED (needs **both** the recycler and the proposed collector) → ACTIVE → COMPLETED or CANCELLED.
- On ACTIVE, the engine creates **ordinary collection offers** for each batch, and **each generator still accepts individually**. A generator who declines drops out of the plan, which is re-evaluated.
- Each batch keeps its own `batch_code`, QR, pickup record, OTP confirmation and receipt. The shared truck is a **transport consignment** (05 §4.9) that only *groups* batches. At the recycler, each batch QR is scanned and weighed **individually** [DESIGN default]. If only a combined weighbridge weight is possible, see Q-14.

## 4. Landed Cost Optimiser

### 4.1 Formula
```
Total expected cost = generator payment
                    + collector margin / collection charge
                    + transport + sorting + handling + storage
                    + rejection-related cost
Expected usable kg  = est_kg × (1 − expected_rejection_rate) × (1 − expected_process_loss_rate)
Landed cost per usable kg = Total expected cost / Expected usable kg
```
Expected material loss is **not** a separate rupee line, because it is reflected in the denominator. Counting it as a cost as well would double count it. The loss in kg is shown as a separate line.

### 4.2 Perspective separation
The output always shows three distinct figures:
- **Recycler's total cost**
- **Amount received by the generator(s)**
- **Collector's expected earnings**: collection charge or margin, minus the collector's own transport if the collector bears it

Who bears transport is set per offer (`transport_borne_by`).

### 4.3 Configurable assumptions (`pricing_assumptions`, versioned, per recycler with platform defaults)
transport ₹/km and ₹/kg-km, sorting ₹/kg, handling ₹/kg, storage ₹/kg/day, default rejection rate per material, default process loss per material, rejection cost basis (return transport, disposal ₹/kg). **No fixed generator/collector split exists anywhere.**

### 4.4 Worked example [ILLUSTRATIVE]

| Option | Purchase (gen) | Collector | Transport | Sorting + handling | Est kg | Exp. rejection | Exp. loss | Usable kg | Total ₹ | ₹/usable kg |
|---|---|---|---|---|---|---|---|---|---|---|
| A: one supplier, 80 kg @ ₹7, 14 km | 560 | 160 | 280 | 80 | 80 | 12% | 10% | 63.4 | 1,080 | **17.05** |
| B: aggregated plan, 560 kg @ ₹8, 6 km avg | 4,480 | 1,120 | 900 | 560 | 560 | 4% | 8% | 494.6 | 7,060 | **14.27** |

A has the cheaper purchase price (₹7 vs ₹8/kg), but B is cheaper per usable kg because it has lower rejection and spreads transport over more material. This is why purchase price alone must not drive recommendations.

## 5. Supplier reliability and rejection risk

### 5.1 Indicators (`supplier_performance_metrics`, recomputed nightly, rolling 180 days plus all-time)

| Indicator | Definition | Applies to |
|---|---|---|
| Fulfilment rate | batches delivered / batches accepted | Collector |
| On-time pickup rate | pickups inside the agreed window / pickups | Collector |
| Weight discrepancy | median abs((received − collected) / collected) | Collector; (collected vs estimate) for Generator |
| Rejection rate | Σ rejected kg / Σ received kg | Generator (as source), Collector |
| Contamination rate | mean recorded contamination % | Generator, Collector |
| Completion rate | batches PROCESSED / batches ASSIGNED | Collector, Generator |

Each metric is displayed with **n** (the number of transactions it is based on), for example "Rejection 6.2% (n = 23)".

### 5.2 Insufficient history
- n < 5: the indicator is shown as "Insufficient history". Matching uses the neutral prior (0.5).
- 5 ≤ n < 20: a value is shown with a "limited history" badge and a Wilson 90% interval.
- No single opaque "trust score" is shown to other parties.

### 5.3 Risk flags (rule-based, explainable)

| Rule | Recommendation |
|---|---|
| Source rejection rate > 15% (n ≥ 5) | "Inspection recommended at receipt" |
| Weight discrepancy > 10% in 3 of the last 5 | "Weigh in presence of both parties" |
| Contamination above the recycler specification in 2 of the last 3 | "Request sorting before pickup" |
| New supplier (n < 5) | "New supplier — standard inspection" |

Flags carry reasons and data points. They **never** auto-ban, block or accuse anyone. Participants can see their own indicators and dispute them (the dispute is reviewed by an admin).

### 5.4 ML (P2)
A gradient-boosted classifier for P(rejection > x%) may be added only once there are at least 1,000 labelled receipts. It must be evaluated against the rule baseline and must ship with feature attributions.

## 6. Supply and demand forecasting

### 6.1 Supply forecast
- Inputs: generator supply profiles (declared recurring supply), historical listings, pickups, and a festival/event calendar.
- MVP method: for each (locality, material, week), take the **trailing 8-week mean × a seasonal factor** (the same week last year divided by the annual mean, where at least 1 year of data exists). Recurring profiles are added as "expected recurring".
- Output: `predicted_kg` plus `lower_kg`/`upper_kg` (empirical 10th/90th percentile of weekly residuals), `n_history_points`, and a `confidence_label` (LOW if n < 8).

### 6.2 Demand forecast
- Inputs: recycler demand profiles, historical procurement (receipts), current inventory (if supplied), processing schedule, and future capacity.
- Method: the declared demand takes precedence. Otherwise, the trailing mean of receipts, capped at capacity.

### 6.3 Shortage detection
```
confirmed_supply  = Σ est. usable kg of LISTED/ASSIGNED batches + active plan items (matching material, before need-by)
predicted_supply  = forecast predicted_kg (shown separately, never added into confirmed)
gap_confirmed     = demand − confirmed_supply
gap_expected      = demand − (confirmed_supply + predicted_supply)
```
Example: the recycler needs 5,000 kg HDPE next month and confirmed supply is 3,000 kg. The confirmed gap is **2,000 kg**, and the forecast adds about 1,200 kg (LOW–MEDIUM confidence). The alert lists the top generators by recurring-supply profile and reliability, plus collectors with spare capacity. It suggests "advance collection plan" drafts (a pre-booked aggregation plan for recurring suppliers) that **still need human acceptance**.

### 6.4 Rule
Forecasts live only in the `forecasts` table. They are never written to batches, receipts or allocations, and the UI always labels them "Predicted".

## 7. Verified yield analytics

- **Facility processing yield** = `output_kg / input_kg × 100`. It is computed **only** when `measurement_status = COMPLETE`, meaning input, output and residue have all been measured.
- If any measurement is missing, the yield is shown as "Incomplete measurement" and **never assumed to be 100%**.
- Mass balance check: `unaccounted_kg = input − output − residue`. If this exceeds 3% of input, a flag is raised [ASSUMPTION A-16].
- Distinct rates (always labelled separately):

| Metric | Formula |
|---|---|
| Collection rate | collected kg / listed estimated kg |
| Acceptance rate | accepted kg / received kg |
| Processing yield | output kg / input kg (measured) |
| Recycling quantity | Σ output kg (processing type = RECYCLING only) |
| NGO-verified quantity | 03 §2 |
| EPR-allocated quantity | 03 §2 |

- Per-batch attribution in a combined run is pro rata by input kg (05 §5). It is **informational** and labelled as such in the passport, not a measured per-batch yield.

## 8. Anomaly detection rules

| Code | Rule | Severity |
|---|---|---|
| AN-01 | collected > estimate × 1.2 without a note | WARN |
| AN-02 | received > collected × 1.02 | HIGH |
| AN-03 | output + residue > input (blocked by the DB; logged if attempted) | HIGH |
| AN-04 | Duplicate QR scan at a second recycler | HIGH |
| AN-05 | Duplicate certificate_ref attempt | HIGH |
| AN-06 | Allocation attempt exceeding available kg | WARN |
| AN-07 | Missing pickup or receipt evidence document | WARN |
| AN-08 | Same photo hash reused across batches | WARN |
| AN-09 | ≥ 3 weight discrepancies > 10% for one party in 30 days | WARN |
| AN-10 | Mass-balance unaccounted > 3% | WARN |
| AN-11 | Processing date earlier than receipt date | HIGH |

Flags are review prompts. The wording is neutral, e.g. "Received weight exceeds collected weight by 6%".

## 9. Future opportunities (P2+)
VRP route optimisation (OR-Tools), ML rejection risk, hierarchical demand forecasting, NIR-spectroscopy integration at the recycler, and automated procurement suggestions (still subject to human acceptance).
