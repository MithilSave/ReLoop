# 09 — Dashboards and UI

Endpoints refer to 06. Statuses refer to 03 §6.

## 1. Design principles

- **Calm enterprise SaaS.** Neutral surfaces, one green brand accent, and status colour reserved for meaning (green = verified/complete, amber = pending/limited, red = flagged/rejected, grey = predicted).
- **Six-stage quantity bar** is the signature component. It is a horizontal stepped bar: Collected → Received → Accepted → Processed → Verified → Allocated. Each segment shows kg, and is never merged.
- **Predicted ≠ confirmed.** Forecasts are always drawn hatched or dashed, carry the label "Predicted", and are never summed into confirmed totals.
- **Explain every recommendation.** Ranked lists have a "Why?" disclosure showing score components and reasons (10).
- Role-specific navigation: one left nav per org type, with the generator and collector views mobile-first.
- Accessible tables: sortable headers, sticky first column, keyboard navigation, and status shown as text plus colour.
- Typography: Inter (UI) with tabular numerals for kg and ₹. Spacing scale of 4/8 px.

## 2. Generator (mobile-first, household-simple)

| Screen | Sees | Actions / inputs | Then | Endpoints |
|---|---|---|---|---|
| Overview | Active batches, ₹ earned, kg processed | "List plastic" button | → Create | GET `/batches`, `/payments` |
| Create listing | Photo upload, AI suggestion chip with confidence, kg slider, address, time window | Upload photo, confirm polymer, submit | Batch LISTED, QR shown | `/documents/*`, POST `/ai/classify`, POST `/batches` |
| My batches | Cards with status chip and the six-stage bar | Open, cancel (LISTED only) | | GET `/batches`, `/batches/{id}/events` |
| Collector offers | Ranked offers: ₹/kg, time, reliability with n, "Why?" | Accept one | ASSIGNED | GET/POST `/batches/{id}/offers…` |
| Pickup tracking | Collector ETA, weight the collector entered, OTP | Confirm via OTP or show QR | PICKED_UP | POST `/batches/{id}/handover/confirm` |
| Payments | Ledger | — | | GET `/payments` |
| Certificates | Contribution certificates (non-statutory, labelled) | Download | | GET `/generator/certificates` |
| Recurring supply (P1) | "I usually have ~20 kg PET every Sunday" | Create/edit a supply profile | Used in forecasts and plans | `/generator/supply-profiles` |
| Material passport | Read-only journey of the batch | Share snapshot | | GET `/passports/{code}` |
| Vouchers (P2) | Brand offers with substantiated claims | Redeem | | — |

## 3. Collector (mobile, practical)

| Screen | Key content | Actions | Endpoints |
|---|---|---|---|
| Overview | Today's jobs, kg, ₹ expected earnings | — | `/collections/jobs` |
| Available listings | Map + list, match score, "Why?" | Make an offer | `/collections/available`, POST offers |
| Aggregation plans | Plans proposing this collector: stops, sequence, kg, **expected earnings** (separate from recycler cost) | Accept / decline | `/aggregation/plans`, `/accept` |
| My jobs | Grouped by plan/route; stop list | Navigate, start pickup | |
| Pickup | Weight entry (large numeric keypad), camera, OTP wait | Submit pickup | POST `/collections/{id}/pickup` |
| Dispatch | Select picked-up batches into a consignment, choose recycler (offers ranked by net value) | Dispatch | POST `/consignments`, GET `/recycler/offers/public` |
| Earnings | Ledger, settlement status | — | `/payments` |
| Performance | Own indicators with n and history level; risk flags with reasons; dispute | Dispute | `/suppliers/{me}/performance` |

**No points, badges or loyalty tiers anywhere in this UI.**

## 4. Recycler

| Screen | Key content | Actions | Endpoints |
|---|---|---|---|
| Overview | Incoming kg, capacity utilisation, measured yield trend, open flags, shortage alerts | | several |
| Demand & offers | Demand profiles, recycler offers | Create/edit | `/recycler/demand-profiles`, `/recycler/offers` |
| Sourcing planner | "Need 500 kg PP by 30 Nov" → proposed plan: map of stops, items with reasons, excluded batches with reasons, feasibility/shortfall, cost breakdown | Propose, recompute, accept, cancel | `/aggregation/plans*` |
| Landed cost comparison | Table of options (single supplier / collector / combination / plan) with every cost line, usable kg and ₹/usable kg; three perspectives toggle | Compare, change assumptions version | `/costs/compare`, `/pricing-assumptions` |
| Supply outlook | Bar per week: **confirmed** (solid) vs **predicted** (hatched with band); gap callout; recommended suppliers | Draft an advance plan | `/forecasts/*` |
| Supplier insight | Indicators with n; risk flags and recommended inspection | — | `/suppliers/{id}/performance` |
| Incoming | Consignments and batches in transit; risk tag per batch | Scan QR | `/recycler/incoming` |
| Receipt | Received/accepted/rejected inputs with a live sum check; grade; evidence upload | Submit / correct | POST `/recycler/receipts` |
| Processing runs | Select receipts → inputs; output, residue; measurement status; computed yield and mass balance | Create / correct | `/recycler/processing-records` |
| Certificates | Certificate references per run | Add | `/…/certificates` |
| Allocations | Per run: eligible vs allocated bar; incoming client requests | Allocate, reverse | `/epr/allocations*` |
| Yield analytics | Yield by material and month (complete runs only) plus a count of incomplete runs | — | `/yield` |

## 5. NGO (evidence-first)

| Screen | Key content | Actions | Endpoints |
|---|---|---|---|
| Verification queue | PENDING/UNDER_REVIEW, kg, risk flags, age | Claim | `/ngo/verifications` |
| Batch review (split view) | Left: material passport timeline with every record version and diffs. Right: evidence viewer (photos, slips, hashes) and checklist (07 §6) | Decide, request documents | `/ngo/verifications/{id}`, `/decision`, `/document-requests` |
| Quantity reconciliation | Table of stages with variance % and thresholds | — | |
| Flagged | Anomaly flags in scope | Resolve (note only) | `/anomalies` |
| History | Own decisions, supersessions | — | |
| Impact & reports | By locality/material/facility; verified vs unverified | Generate PDF | `/ngo/reports`, `/ngo/impact` |
| Profile | Scope, COI list, agreement validity | — | `/orgs/me` |

No edit controls on operational data exist anywhere in the NGO app.

## 6. EPR company (compliance team)

| Screen | Key content | Actions | Endpoints |
|---|---|---|---|
| EPR overview | Per category and period: self-declared target vs allocated (split verified/unverified), pending discrepancies | Period switch | `/epr/dashboard` |
| Profile & targets | Registration no., categories, targets (self-declared) | Edit | `/orgs/me`, `/epr/targets` |
| Allocations | Ledger including reversals; drill into the processing run → passports of source batches | Request allocation | `/epr/allocations`, `/epr/allocation-requests` |
| Processing & yield | Linked runs, measured yield, measurement status | — | `/yield` |
| Recycler info | Registration no./validity, processing type | — | |
| NGO verification | Decision per allocated batch | — | |
| Certificate references | Labelled "recycler-declared" | — | `/epr/certificates` |
| Discrepancies | Flags/decisions touching its allocations | — | `/epr/discrepancies` |
| Reports | Evidence report generation (with boundary disclaimer) | Generate/download | `/epr/reports` |

## 7. Charts (Recharts)
Stacked stage bar, yield line (complete runs only), confirmed vs predicted bar with error band, landed-cost waterfall (purchase → collector → transport → sorting/handling → storage → rejection → total, then ÷ usable kg), and verification donut (verified/pending/flagged/rejected).
