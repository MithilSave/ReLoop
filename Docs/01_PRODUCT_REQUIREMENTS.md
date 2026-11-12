# 01 — Product Requirements

Priorities: **P0** = MVP mandatory, **P1** = important, **P2** = later (see 12). Workflows: 03. Permissions: 11 §3.

## 1. Functional requirements

### FR-AUTH: Identity and organisations
| ID | Requirement | P |
|---|---|---|
| FR-AUTH-1 | Users register with email/phone and password, and log in to receive a JWT | P0 |
| FR-AUTH-2 | Every non-household user belongs to an **organisation** with exactly one participant type (GENERATOR, COLLECTOR, RECYCLER, NGO, EPR_CLIENT) | P0 |
| FR-AUTH-3 | Within an organisation, users have org roles: OWNER, ADMIN, MEMBER, VIEWER | P0 |
| FR-AUTH-4 | An individual household is modelled as a single-member GENERATOR organisation | P0 |
| FR-AUTH-5 | A platform admin approves Recycler, NGO and EPR organisations after document review | P0 |

### FR-BATCH: Waste batches
| ID | Requirement | P |
|---|---|---|
| FR-BATCH-1 | A generator creates a batch with photos, estimated kg, material category, pickup location and an availability window | P0 |
| FR-BATCH-2 | The system assigns an immutable batch code (e.g. `RL-MUM-2026-000123`) and a QR payload | P0 |
| FR-BATCH-3 | The generator can edit a batch only while its status is LISTED | P0 |
| FR-BATCH-4 | Every status change writes an append-only `batch_event` | P0 |
| FR-BATCH-5 | AI suggests the polymer type with a confidence score, and the generator confirms it | P1 |

### FR-COLL: Collection
| ID | Requirement | P |
|---|---|---|
| FR-COLL-1 | Collectors see LISTED batches within their service area that match the materials they accept | P0 |
| FR-COLL-2 | A collector submits an offer (₹/kg to the generator, proposed pickup time) | P0 |
| FR-COLL-3 | The generator accepts one offer. Other offers expire automatically | P0 |
| FR-COLL-4 | At pickup, the collector records actual kg and photos. The generator confirms with an OTP or by scanning the QR | P0 |
| FR-COLL-5 | The collector records in-transit status and the destination recycler | P0 |
| FR-COLL-6 | Matching ranks collectors by distance, material, capacity, minimum quantity and reliability | P1 |

### FR-REC: Recycler
| ID | Requirement | P |
|---|---|---|
| FR-REC-1 | The recycler publishes recycler offers (material, ₹/kg, minimum kg, quality specification) | P0 |
| FR-REC-2 | The recycler scans the QR, then records received kg, accepted kg, rejected kg, quality grade and evidence | P0 |
| FR-REC-3 | The recycler creates a processing record linking one or more received batches, with input kg, processed output kg and residue/loss kg | P0 |
| FR-REC-4 | The recycler attaches statutory certificate references (number, category, quantity, date) to processing records | P1 (P0 for the demo, as [SIMULATED]) |
| FR-REC-5 | Only the recycler organisation that received a batch can record its receipt or processing | P0 |

### FR-NGO: Verification
| ID | Requirement | P |
|---|---|---|
| FR-NGO-1 | Processed batches within an NGO's scope enter its queue as PENDING | P0 |
| FR-NGO-2 | The NGO views the full chain of custody, evidence and quantity reconciliation in read-only mode | P0 |
| FR-NGO-3 | The NGO records a decision: VERIFIED, FLAGGED, REJECTED or REQUIRES_CORRECTION, with comments and the evidence reviewed | P0 |
| FR-NGO-4 | Decisions are append-only. A new decision supersedes the previous one but never deletes it | P0 |
| FR-NGO-5 | The NGO generates a verification report (PDF) | P1 |

### FR-EPR: EPR client
| ID | Requirement | P |
|---|---|---|
| FR-EPR-1 | An EPR client records its registration number, packaging categories, reporting periods and targets | P0 |
| FR-EPR-2 | The dashboard shows allocated, verified and pending quantities by category and period | P0 |
| FR-EPR-3 | An allocation draws from the eligible quantity of a processing record. The sum of active allocations can never exceed eligible kg | P0 |
| FR-EPR-4 | Allocations are created by the recycler (the party holding the certificate) at an EPR client's request. They are reversible only by an audited reversal entry | P0 |
| FR-EPR-5 | The client exports an evidence report (PDF/CSV) for the allocated quantities | P0 |

### FR-AN: Anomalies and impact
| ID | Requirement | P |
|---|---|---|
| FR-AN-1 | Rule-based anomaly flags (see 10 §4) | P1 |
| FR-AN-2 | Impact dashboard shows the six quantity stages separately | P1 |

### FR-PASS: Material passport and yield
| ID | Requirement | P |
|---|---|---|
| FR-PASS-1 | Every batch has a material passport covering all fields listed in 05 §4.10, with role-filtered views | P0 |
| FR-PASS-2 | Passport snapshots are immutable and stored with a hash | P0 |
| FR-PASS-3 | Processing yield is computed only from measured input and output. Incomplete runs show "Incomplete measurement" and are never treated as 100% | P0 |
| FR-PASS-4 | Combined runs preserve per-batch lineage, and per-batch output is shown as pro-rata and labelled informational | P0 |

### FR-AGG: Smart feedstock aggregation
| ID | Requirement | P |
|---|---|---|
| FR-AGG-1 | A recycler declares a demand (material, kg, quality, contamination, need-by) and requests a plan | P0 |
| FR-AGG-2 | The engine proposes a plan from LISTED batches only, considering every factor in 10 §3.2 | P0 (basic) |
| FR-AGG-3 | The engine never mixes material categories and excludes unconfirmed materials, with a reason | P0 |
| FR-AGG-4 | The output includes items, total estimated kg, expected usable kg, sequence, suggested collector, collection cost, landed cost, feasibility/shortfall, and reasons | P0 |
| FR-AGG-5 | A plan needs acceptance by the recycler **and** the collector. Each generator accepts its own offer | P0 |
| FR-AGG-6 | Batches keep their identity through consignment and receipt. A batch can be in at most one active plan | P0 |
| FR-AGG-7 | Pickup sequence optimisation beyond nearest-neighbour | P2 |

### FR-COST: Landed cost
| ID | Requirement | P |
|---|---|---|
| FR-COST-1 | Estimate cost lines (purchase, collector, transport, sorting, handling, storage, rejection) and the usable kg | P0 |
| FR-COST-2 | Compare individual generators, collectors, combinations and plans by ₹ per usable kg | P0 (basic) |
| FR-COST-3 | Show recycler cost, generator receipts and collector earnings separately | P0 |
| FR-COST-4 | Pricing assumptions are configurable and versioned. No fixed split exists | P0 |

### FR-PERF: Supplier reliability
| ID | Requirement | P |
|---|---|---|
| FR-PERF-1 | Separate indicators per supplier (10 §5.1), each shown with n | P1 |
| FR-PERF-2 | "Insufficient history" when n < 5. No inflated confidence | P1 |
| FR-PERF-3 | Explainable risk flags that recommend inspection and never ban anyone | P1 |
| FR-PERF-4 | Suppliers can view and dispute their own indicators | P1 |
| FR-PERF-5 | ML rejection risk, only with sufficient labelled data | P2 |

### FR-FC: Forecasting
| ID | Requirement | P |
|---|---|---|
| FR-FC-1 | Generator recurring supply profiles and recycler recurring demand profiles | P1 |
| FR-FC-2 | Statistical supply and demand forecasts with a configurable horizon and a confidence band | P1 |
| FR-FC-3 | Shortage alerts showing confirmed and predicted gaps separately, with supplier recommendations and advance-plan suggestions | P1 |
| FR-FC-4 | Forecasts are never used as inventory or allocation input | P1 |

### FR-REW: Generator rewards
| ID | Requirement | P |
|---|---|---|
| FR-REW-1 | Contribution certificate (PDF) per generator, covering processed kg (and verified kg where available) | P1 |
| FR-REW-2 | Brand vouchers for generators only. **Collectors receive no loyalty points** | P2 |

## 2. Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-1 | All authorisation is enforced server-side. The UI only hides controls |
| NFR-2 | Weights are `NUMERIC(12,3)` in kg. Money is `NUMERIC(14,2)` in INR. No floats |
| NFR-3 | Operational records are never hard-deleted. Corrections create new versions |
| NFR-4 | p95 API latency under 500 ms for dashboard reads at pilot scale (about 10k batches/month) |
| NFR-5 | The collector UI is usable on a 360 px Android screen over 3G |
| NFR-6 | Evidence files are stored with a SHA-256 hash, and the hash is shown in reports |
| NFR-7 | DPDP-aware handling of personal data (see 11 §5) |
| NFR-8 | WCAG 2.1 AA for forms and tables |

## 3. User stories (selected)

- *As a housing-society secretary*, I want to list 100 kg of PET with a photo so that collectors can bid and I get paid per kg.
- *As a collector*, I want listings near my route that match the materials I accept, so I do not waste trips.
- *As a collector*, I want the generator to confirm the weight by OTP so that weight disputes are settled on the spot.
- *As a recycler*, I want to record accepted vs rejected kg so that I pay only for usable material.
- *As a recycler*, I want to combine many small batches into one processing run without losing traceability.
- *As an NGO reviewer*, I want to see each quantity stage side by side with its evidence so that I can spot gaps quickly.
- *As a recycler buyer*, I want 12 small PP listings proposed as one 500 kg plan with its true cost per usable kg, so that I can source from households economically.
- *As a recycler buyer*, I want to see next month's HDPE gap with confirmed and predicted supply kept apart, so that I don't plan on supply that may not exist.
- *As a collector*, I want to see why I was flagged ("weight discrepancy in 3 of the last 5 pickups") and dispute it.
- *As an EPR compliance manager*, I want proof that the kg allocated to us have not been allocated to anyone else.

## 4. User journeys

Detailed in 03 §3–§5, with diagrams.

## 5. Acceptance criteria (key)

| Feature | Given / When / Then |
|---|---|
| Handover | Given an ASSIGNED batch, when the collector submits pickup kg and the generator enters the correct OTP, then the status becomes PICKED_UP and a `pickup_record` exists with both party IDs and a timestamp |
| Receipt | Given received 98 kg, when the recycler enters accepted 90 and rejected 10, then the API returns 422 (accepted + rejected ≠ received) |
| Processing | When processed kg + residue kg > input kg, then the API returns 422 |
| Allocation | Given eligible kg 1,000 with 800 already allocated, when someone requests 300, then the API returns 409 `ALLOCATION_EXCEEDS_AVAILABLE`. Two concurrent requests of 150 kg each: exactly one succeeds |
| NGO independence | Given an NGO token, when it calls any PATCH/POST on pickup, receipt or processing endpoints, then the API returns 403 |
| No double count | When a certificate reference number already exists for that recycler, then the API returns 409 and an anomaly flag is raised |
| Aggregation identity | Given a plan of 12 batches delivered in one consignment, each batch has its own pickup record and receipt, and its passport shows the plan and consignment codes |
| Aggregation compatibility | When a PP plan is proposed and an HDPE or unconfirmed batch is nearby, then it appears in `excluded` with a reason, never in `items` |
| Landed cost | The estimate's `total_cost` equals the sum of its lines, and `landed_cost_per_usable_kg` = total ÷ expected usable kg |
| Forecast separation | The shortage response returns `confirmed_supply_kg` and `predicted_supply_kg` as separate fields, and no allocation endpoint accepts a forecast ID |
| Yield | When output is null, yield is null and the run is excluded from averages |
| Verified totals | Dashboard "verified kg" includes only batches whose *current* verification decision is VERIFIED |

## 6. MVP scope vs future

Exactly as in the project brief: P0 / P1 / P2. The milestone mapping is in 12.
