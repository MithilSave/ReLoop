# 06 — API Specification

The base path is `/api/v1`. The JSON shape follows the Pydantic schemas. Table names come from 05, and permission codes from 11 §3.

## 1. Conventions

| Topic | Rule |
|---|---|
| Auth | `Authorization: Bearer <access JWT>` on all endpoints except register, login and refresh |
| Org context | Taken from the JWT `org_id`. Users in multiple orgs switch with `POST /auth/switch-org` |
| IDs | UUIDs. Batches can also be addressed by `batch_code` where noted |
| Quantities | Decimal **strings** in JSON (`"97.500"`) to avoid float loss |
| Time | ISO-8601 UTC |
| Pagination | `?page=1&page_size=25` (max 100). Response: `{items, page, page_size, total}` |
| Filtering/sort | `?status=LISTED&material=PET&from=2026-11-01&to=…&sort=-created_at` |
| Idempotency | `Idempotency-Key` header required on POSTs that move quantity or money (pickup, receipt, processing, allocation, payment). Repeats return the original response |
| Errors | `{"error": {"code": "STRING_CODE", "message": "...", "details": {...}}}` |

### Error codes
| HTTP | Code examples |
|---|---|
| 400 | `VALIDATION_ERROR` |
| 401 | `UNAUTHENTICATED`, `TOKEN_EXPIRED` |
| 403 | `FORBIDDEN_ROLE`, `FORBIDDEN_ORG`, `ORG_NOT_APPROVED`, `NGO_OUT_OF_SCOPE`, `NGO_CONFLICT_OF_INTEREST` |
| 404 | `NOT_FOUND` (also returned for other orgs' resources, to avoid leaking their existence) |
| 409 | `INVALID_STATE_TRANSITION`, `ALLOCATION_EXCEEDS_AVAILABLE`, `DUPLICATE_CERTIFICATE_REF`, `ELIGIBLE_BELOW_ALLOCATED`, `OFFER_ALREADY_ACCEPTED` |
| 422 | `QUANTITY_INCONSISTENT`, `OTP_INVALID` |

## 2. Auth and organisations

| Method & path | Who | Body → Response |
|---|---|---|
| POST `/auth/register` | public | `{full_name, email?, phone?, password, org: {org_type, legal_name, address, lat, lng}}` → `{user, org, access_token, refresh_token}`. GENERATOR orgs are auto-approved; others start PENDING |
| POST `/auth/login` | public | `{login, password}` → tokens |
| POST `/auth/refresh` | public | `{refresh_token}` → new tokens (rotation) |
| GET `/auth/me` | any | `{user, memberships[], active_org}` |
| POST `/auth/switch-org` | member | `{org_id}` → tokens |
| GET/PATCH `/orgs/me` | OWNER/ADMIN | org fields plus type-specific profile |
| POST `/orgs/me/members` | OWNER/ADMIN | `{email|phone, org_role}` |
| POST `/admin/orgs/{id}/approve` | platform admin | `{decision, note}` |

## 3. Reference data
`GET /materials` (any) → material categories.

## 4. Batches

| Method & path | Perm | Notes |
|---|---|---|
| POST `/batches` | GENERATOR | `{material_code, estimated_kg, pickup_address, lat, lng, locality, available_from, available_to, document_ids[], ai_prediction_id?}` → `201 {id, batch_code, status:"LISTED", qr_url}` |
| GET `/batches` | any (scoped) | Generators see their own; collectors see assigned ones; recyclers see those destined for or received by them; NGOs see those in scope; EPR clients see batches linked to their allocations |
| GET `/batches/{id_or_code}` | scoped | Full detail with a `quantities` block (the 6 stages, 03 §2) |
| PATCH `/batches/{id}` | owning GENERATOR | Only while LISTED, else 409 |
| POST `/batches/{id}/cancel` | owning GENERATOR | LISTED/ASSIGNED only |
| GET `/batches/{id}/events` | scoped | Timeline |
| GET `/batches/{id}/qr` | owner, assigned collector, destination recycler | PNG/SVG |
| GET `/batches/{id}/trace` | scoped | Lineage: pickup → receipt → processing → certificates/allocations (allocations shown to EPR clients only when they are the allocation's client) |

**Example: GET /batches/RL-MUM-2026-000123 (excerpt)**
```json
{
  "batch_code": "RL-MUM-2026-000123",
  "status": "PROCESSED",
  "material": "PET",
  "quantities": {
    "estimated_kg": "100.000", "collected_kg": "98.000",
    "received_kg": "97.500", "accepted_kg": "90.000", "rejected_kg": "7.500",
    "processed_kg": "82.000", "ngo_verified_kg": "82.000",
    "epr_allocated_kg": "60.000"
  },
  "verification": {"decision": "VERIFIED", "ngo": "Green Ledger Foundation", "at": "2026-11-20T10:02:00Z"}
}
```

## 5. Collections

| Method & path | Perm | Notes |
|---|---|---|
| GET `/collections/available` | COLLECTOR (approved) | LISTED batches matching materials/radius, sorted by `match_score` (10 §3). `?lat&lng&radius_km` |
| POST `/collections/{batch_id}/offers` | COLLECTOR | `{generator_rate_per_kg, proposed_pickup_at}` |
| GET `/batches/{batch_id}/offers` | owning GENERATOR | Ranked offers |
| POST `/batches/{batch_id}/offers/{offer_id}/accept` | owning GENERATOR | → batch ASSIGNED. Other offers become DECLINED |
| POST `/collections/{batch_id}/withdraw` | assigned COLLECTOR | → LISTED |
| POST `/collections/{batch_id}/pickup` | assigned COLLECTOR | `{collected_kg, document_ids[]}` → `{pickup_record_id, otp_required:true}`. The OTP is shown to the generator |
| POST `/batches/{batch_id}/handover/confirm` | owning GENERATOR | `{otp}` or `{qr_token}` → PICKED_UP |
| POST `/consignments` | COLLECTOR | `{batch_ids[], destination_recycler_org_id, vehicle_no?, aggregation_plan_id?}` → a consignment. Every batch must be PICKED_UP by this collector. Each batch becomes IN_TRANSIT and keeps its own identity |
| POST `/consignments/{id}/arrive` | destination RECYCLER | Marks ARRIVED. Each batch is still received individually via `/recycler/receipts` |
| GET `/consignments` | COLLECTOR / RECYCLER (own) | |
| GET `/collections/jobs` | COLLECTOR | Own jobs by status |

Validation: `collected_kg > 0`. If it exceeds 120% of the estimate, a `note` is required and an anomaly flag is raised.

## 6. Recycler

| Method & path | Perm | Notes |
|---|---|---|
| GET/POST/PATCH `/recycler/offers` | RECYCLER | Recycler offers |
| GET `/recycler/offers/public?material=PET` | COLLECTOR | Active offers for choosing a destination |
| GET `/recycler/incoming` | RECYCLER | IN_TRANSIT batches destined for this org |
| POST `/recycler/receipts` | RECYCLER (destination) | `{qr_token or batch_id, received_kg, accepted_kg, rejected_kg, quality_grade, contamination_pct, rejection_disposition, document_ids[]}`. 422 if accepted + rejected ≠ received |
| POST `/recycler/receipts/{id}/corrections` | RECYCLER | New version, `{…fields, reason}` |
| POST `/recycler/processing-records` | RECYCLER | `{material_code, run_started_at, run_ended_at, inputs:[{recycler_receipt_id, input_kg}], output_kg, residue_kg, output_form, eligible_kg, eligibility_basis, document_ids[]}` |
| POST `/recycler/processing-records/{id}/corrections` | RECYCLER | New version. 409 `ELIGIBLE_BELOW_ALLOCATED` if needed |
| GET `/recycler/processing-records` | RECYCLER | List with allocated vs eligible |
| POST `/recycler/processing-records/{id}/certificates` | RECYCLER | `{certificate_ref, packaging_category, certificate_kg, issued_on, document_id}`. 409 on duplicate ref |
| GET `/recycler/capacity` | RECYCLER | Utilisation summary |

Processing validation: inputs must be this recycler's current receipts with the same material; Σ inputs = `input_kg`; per-receipt cumulative ≤ accepted; `output + residue ≤ input`; `eligible ≤ output`.

## 7. NGO

| Method & path | Perm | Notes |
|---|---|---|
| GET `/ngo/verifications?decision=PENDING` | NGO | Queue within scope |
| GET `/ngo/verifications/{id}` | NGO | Batch trace, all record **versions**, documents, reconciliation table, open anomaly flags |
| POST `/ngo/verifications/{id}/claim` | NGO reviewer | → UNDER_REVIEW, sets reviewer |
| POST `/ngo/verifications/{id}/decision` | NGO reviewer | `{decision: VERIFIED|FLAGGED|REJECTED|REQUIRES_CORRECTION, comments, evidence_doc_ids[], follow_up_required?}`. Creates a new row, supersedes the previous one, and stores `reviewed_record_versions` |
| POST `/ngo/verifications/{id}/document-requests` | NGO | `{addressed_to_org_id, request_text}`. Notifies the party |
| GET `/ngo/reports?period=…` | NGO | Generates/lists verification PDFs |
| GET `/ngo/impact` | NGO | Aggregates by locality/material/facility |

NGO tokens get **403 on every write endpoint in §4–§6 and §8**. Server-side guards check `org_type`, not the UI.

## 8. EPR

| Method & path | Perm | Notes |
|---|---|---|
| GET `/epr/dashboard?period=FY2026-27` | EPR_CLIENT | Targets (self-declared) vs allocated, verified-allocated, unverified-allocated, pending |
| GET/POST `/epr/targets` | EPR_CLIENT | Own targets |
| GET `/epr/allocations` | EPR_CLIENT (own); RECYCLER (created by it) | |
| POST `/epr/allocation-requests` | EPR_CLIENT | `{recycler_org_id, packaging_category, reporting_period, quantity_kg, note}`. A request only |
| POST `/epr/allocations` | RECYCLER | `{processing_record_id, epr_org_id, certificate_id?, packaging_category, reporting_period, quantity_kg, request_id?}`. Enforces 05 §6. 409 `ALLOCATION_EXCEEDS_AVAILABLE` |
| POST `/epr/allocations/{id}/reverse` | RECYCLER (creator) | `{reason}` |
| GET `/epr/certificates` | EPR_CLIENT | Certificate refs linked to its allocations |
| POST `/epr/reports` | EPR_CLIENT | `{period, format: pdf|csv}` → `202 {report_id}` |
| GET `/epr/reports/{id}` | EPR_CLIENT | Status plus a signed download link |
| GET `/epr/discrepancies` | EPR_CLIENT | Flags and non-VERIFIED decisions touching its allocations |

**Example: POST /epr/allocations → 409**
```json
{"error":{"code":"ALLOCATION_EXCEEDS_AVAILABLE",
  "message":"Requested 300.000 kg exceeds available 200.000 kg",
  "details":{"eligible_kg":"1000.000","allocated_kg":"800.000","available_kg":"200.000"}}}
```

## 9. Material passport and yield

| Method & path | Perm | Notes |
|---|---|---|
| GET `/passports/{batch_code}` | scoped (role-filtered fields, 11 §3) | Full material passport (05 §4.10) |
| POST `/passports/{batch_code}/snapshot` | owner generator, recycler, NGO in scope, allocated EPR client | Immutable PDF/JSON with hash → `{document_id}` |
| GET `/yield?recycler_id&material&from&to` | RECYCLER (own), NGO (scope), EPR client (linked records) | Run-level yield. Runs with `INCOMPLETE` measurement are listed separately and excluded from averages |

## 10. Procurement intelligence

| Method & path | Perm | Notes |
|---|---|---|
| GET/POST/PATCH `/recycler/demand-profiles` | RECYCLER | 05 §4.9 |
| GET/POST/PATCH `/generator/supply-profiles` | GENERATOR | Declared recurring supply |
| POST `/aggregation/plans:propose` | RECYCLER | `{demand_profile_id | {material_code, target_kg, quality, need_by}}` → `201` plan in PROPOSED with items, excluded list, cost estimate, and explanations (10 §3.5). No side effects on batches beyond reserving `active_plan_id` |
| GET `/aggregation/plans` / `{id}` | RECYCLER (own), suggested COLLECTOR | |
| POST `/aggregation/plans/{id}/accept` | RECYCLER or suggested COLLECTOR | Both are needed → ACCEPTED, then ACTIVE (creates per-batch collection offers) |
| POST `/aggregation/plans/{id}/cancel` | RECYCLER / COLLECTOR | Releases batches |
| POST `/aggregation/plans/{id}/recompute` | RECYCLER | After a generator declines or new listings appear. Returns a new version of the items |
| POST `/costs/estimate` | RECYCLER, COLLECTOR | `{subject_type, subject_id | options:[…], assumptions_version?}` → cost estimate(s) with full breakdown and three perspectives (10 §4.2) |
| POST `/costs/compare` | RECYCLER | `{options:[{type:BATCH|COLLECTOR|PLAN|COMBINATION, ids:[…]}]}` → ranked by landed ₹/usable kg, each with its breakdown |
| GET/POST `/pricing-assumptions` | RECYCLER (own), admin (defaults) | Creates a new version; old versions stay |
| GET `/suppliers/{org_id}/performance` | RECYCLER, COLLECTOR, the org itself | Indicators with `n` and `history_level`; risk flags with reasons |
| POST `/suppliers/{org_id}/performance/disputes` | the org itself | Admin review |
| GET `/forecasts/supply?material&locality&horizon_weeks` | RECYCLER, COLLECTOR, admin | Every row is labelled `kind:"PREDICTED"` |
| GET `/forecasts/demand?material` | COLLECTOR (aggregate), RECYCLER (own) | |
| GET `/forecasts/shortages` | RECYCLER | `{demand_kg, confirmed_supply_kg, predicted_supply_kg, gap_confirmed_kg, gap_expected_kg, recommended_suppliers[], suggested_advance_plans[]}`. Confirmed and predicted are always separate fields |

Validation highlights:
- Plans reject mixed materials (422 `INCOMPATIBLE_MATERIAL`).
- A batch already in an active plan returns 409 `BATCH_IN_ACTIVE_PLAN`.
- `planned_kg` greater than the batch estimate returns 422.
- Forecast endpoints are read-only and cannot be referenced by allocation endpoints.

## 11. Payments, documents, AI, anomalies, impact

| Method & path | Perm | Notes |
|---|---|---|
| GET `/payments` | scoped to payer/payee org | [SIMULATED] ledger |
| POST `/payments/{id}/mark-paid` | payer org ADMIN | `{external_ref}` |
| POST `/documents/upload-url` | any | `{doc_type, mime_type, size_bytes}` → `{document_id, upload_url}` |
| POST `/documents/{id}/complete` | uploader | Server hashes the file → READY |
| GET `/documents/{id}/download-url` | permission-checked via linked entity | |
| POST `/ai/classify` | GENERATOR | `{document_id}` → `{prediction_id, top_k:[{code,confidence}], needs_confirmation}` |
| GET `/anomalies` | RECYCLER/COLLECTOR (own), NGO (scope), admin | |
| POST `/anomalies/{id}/resolve` | admin or NGO (scope) | `{status, note}` (does not edit data) |
| GET `/impact/summary` | any (aggregate, no PII) | Six stages, contamination rate, etc. |
| GET `/generator/certificates` | GENERATOR | Contribution certificate PDFs |
