# ReLoop — Backend Audit and API Integration Inventory (Stage 1)

**Repository audited:** `MithilSave/ReLoop` at commit `55f9ce4` ("main push"). `MithilSave/LYB` is the same commit with identical files.
**Method:** I read every router, schema, core module and the seed script. I ran the seed and the existing test suite, then started the API (`uvicorn app.main:app`, SQLite) and probed it with live requests. The probe scripts are in `docs/evidence/` and can be re-run.
**Date:** 12 Nov 2026

> **Status update (integration branch `integration/web-app`).** Proposed changes #1–#4 in §7 are implemented in the first commit on this branch, with tests (`backend/test_integration_fixes.py`). Defects D1–D5 are fixed by that commit. D6–D11 and changes #5–#9 remain open; the web app labels each affected screen. Everything below describes the backend **as audited at `55f9ce4`**.

---

## 0. Verdict in one paragraph

The FastAPI backend is real and runs. It exposes 90 operations under `/api/v1` (each also mounted under `/api`), plus `/health` and `/docs`. The happy-path workflow from listing to allocation works end to end, and the existing test suite passes. The quantity safeguard at **allocation** time (`ALLOCATION_EXCEEDS_AVAILABLE`) works.

Several things in the README or brief are **not** in the code, and some safeguards are enforced only partly:

- There is **no organisation directory endpoint**. A collector cannot list recyclers to deliver to. A recycler cannot list EPR clients to allocate to.
- There is **no endpoint that lists recycler receipts**, which a recycler needs before it can build a processing run.
- **Token refresh crashes** (HTTP 500) on the default SQLite database.
- **Uploads, AI classification, EPR reports, allocation requests and generator certificates are stubs** that return placeholder values.
- **Processing runs do not check input quantities against accepted stock.** I created a 5,000 kg run from a 480 kg receipt and processed the same receipt twice. Both runs became allocatable. This defeats double-counting protection upstream of the allocation check.

None of this stops building the frontend. It does change what "working" can honestly mean for several screens. Section 7 lists the backend changes I propose separately; I have not made any of them.

---

## 1. Runtime facts (verified)

| Item | README / brief says | Actual |
|---|---|---|
| Health | `/health` | ✅ `GET /health` → `{"status":"ok","app":"ReLoop","version":"1.0.0"}` |
| API docs | `/docs` | ✅ Swagger at `/docs`, OpenAPI at `/openapi.json` |
| API prefix | — | `/api/v1/*` (canonical) and `/api/*` (duplicate mount) |
| Database | SQLite or PostgreSQL | ✅ Default `sqlite+aiosqlite:///./reloop.db`; falls back to SQLite if Postgres fails. **`aiosqlite` is not in `requirements.txt`**, so a clean install fails until it is added |
| Migrations | Alembic | ❌ `alembic/versions/` is empty; tables are created with `create_all` at startup |
| Object storage | S3 / MinIO | ❌ No S3 calls exist. Upload URLs point to `https://reloop-storage.local/…` (fake host) |
| Public passport | `/b/{batch_code}` | ❌ No such route (404). `GET /passports/{code}` requires login |
| Existing tests | `test_api_suite.py` | ✅ Passes (in-process ASGI client) once `aiosqlite` is installed |
| Unused dependencies | — | `weasyprint`, `onnxruntime`, `boto3`, `apscheduler`, `pandas`, `scikit-learn` are installed but never imported |
| CORS | — | Allows all origins (`"*"` in the default list) with credentials |
| Existing web frontend | — | `frontend/` (React 19, Vite, Tailwind 4, TanStack Query, Axios, Recharts). **Every page reads `context/demoData.ts`; no screen calls the API** |
| Existing mobile app | — | `mobile/` (Flutter). Calls `/auth/login`, `/batches`, `/passports`, NGO decision and allocation endpoints, and falls back to demo data |

---

## 2. Authentication and sessions

**Mechanism.** JWT bearer tokens (HS256, `python-jose`) and Argon2 password hashes.

| Endpoint | Body | Returns |
|---|---|---|
| `POST /auth/login` | `{login: email-or-phone, password}` | `AuthResponse` |
| `POST /auth/register` | `{full_name, email?, phone?, password, org:{org_type, legal_name, display_name?, city_id="MUM", address, lat?, lng?, gstin?}}` | `AuthResponse` (201). GENERATOR orgs are auto-approved; all others start `PENDING` |
| `GET /auth/me` | — | `{user, active_org, active_role, memberships[]}` |
| `POST /auth/switch-org` | `{org_id}` | New tokens for another org the user belongs to |
| `POST /auth/refresh` | `{refresh_token}` | New pair; the old refresh token is revoked (rotation) |

`AuthResponse` = `{user:{id, full_name, email, phone, is_platform_admin, status}, org:{id, org_type, legal_name, display_name, city_id, address, lat, lng, gstin, approval_status}, role, access_token, refresh_token, token_type:"bearer"}`

**Access-token claims:** `sub` (user id), `org_id`, `role` (org role), `org_type`, `exp`, `type:"access"`.
**Lifetime:** 24 hours (default config; `.env.example` says 60 minutes). Refresh tokens last 30 days and are stored hashed in `refresh_tokens`.

**There is no logout endpoint.** Refresh tokens can't be revoked by the client, so logout can only discard tokens locally.

**Verified defects:**
1. `POST /auth/refresh` returns **500** on SQLite: `TypeError: can't compare offset-naive and offset-aware datetimes` (`auth/service.py`, `record.expires_at < datetime.now(timezone.utc)`). Silent token refresh is unusable until this is fixed.
2. **A refresh token is accepted as a bearer access token.** `GET /auth/me` returned 200 when I sent a refresh token. The dependency never checks `type == "access"`, so a stolen refresh token gives 30 days of API access.
3. Every invalid token is reported as `TOKEN_EXPIRED`, because the message checked for "expired" always contains "Invalid or expired token". The frontend cannot tell an expired session from a malformed token by code alone. It should treat both as "session ended".

---

## 3. Roles and permissions

Authorisation uses a single dependency, `require(*roles_or_types)` in `core/permissions.py`. It passes if **any** of these holds:

- the caller is a platform admin (`is_platform_admin`), which bypasses everything;
- the active org's `org_type` is in the list (`GENERATOR`, `COLLECTOR`, `RECYCLER`, `NGO`, `EPR_CLIENT`);
- the caller's `org_role` is in the list (`OWNER`, `ADMIN`, `MEMBER`, `VIEWER`).

Non-GENERATOR orgs must also be `APPROVED`/`ACTIVE`; otherwise the request gets `403 ORG_NOT_APPROVED`.

**Roles that actually exist:**

| Role in UI | How the backend identifies it | Demo login (password `reloop123`) | Org |
|---|---|---|---|
| Generator | `org_type = GENERATOR` | generator@reloop.in | Godrej Green Towers Housing Society |
| Collector | `org_type = COLLECTOR` | collector@reloop.in | Dharavi Waste Collectors Welfare Society |
| Recycler | `org_type = RECYCLER` | recycler@reloop.in | Ecoplas Circular Solutions Ltd |
| NGO Auditor | `org_type = NGO` | ngo@reloop.in | Green Ledger Foundation India |
| EPR Brand | `org_type = EPR_CLIENT` | epr@reloop.in | Hindustan Consumer Goods Ltd |
| Admin | `user.is_platform_admin = true` (**not** an org type) | admin@reloop.in | Member of an org called "ReLoop Platform Governance" whose `org_type` is **NGO** |

**Permission gaps the frontend cannot fix:**
- Every seeded user is an org `OWNER`. Any endpoint guarded by `require("NGO", "OWNER", "ADMIN")` is therefore open to **all** demo users. That includes `POST /anomalies/{id}/resolve`, so a collector can resolve a flag raised against its own pickup.
- Several read endpoints are not scoped to the caller's organisation:
  - `GET /batches/{id_or_code}`, `/batches/{id}/events`, `/trace`, `/qr`, and `/passports/{code}`: any logged-in user can read any batch. Passports hide generator names from EPR clients only.
  - `GET /batches` for NGO and EPR users: returns all batches.
  - `GET /ngo/verifications`: returns every NGO's queue, not just the caller's.
  - `GET /anomalies` and `GET /audit/logs`: return everything.
  - `GET /aggregation/plans` for collectors: returns every recycler's plans.
- **The admin's org is typed NGO.** New verifications are auto-assigned to "the first approved NGO", which on the seeded database is the admin's governance org, not Green Ledger (verified). Green Ledger can still see and decide them only because the queue is unscoped (previous point).

---

## 4. Error format

All errors share one envelope (custom handlers in `main.py`):

```json
{ "error": { "code": "ALLOCATION_EXCEEDS_AVAILABLE", "message": "Requested 200.000 kg exceeds available 130.000 kg",
             "details": { "eligible_kg": "130.000", "allocated_kg": "0.000", "available_kg": "130.000" } } }
```

| HTTP | Codes observed in code | Frontend handling |
|---|---|---|
| 400 | `VALIDATION_ERROR`, `INVALID_MATERIAL` | Show inline on the form |
| 401 | `UNAUTHENTICATED`, `TOKEN_EXPIRED` | Try a refresh once (after fix #1), otherwise end the session and return to login with a message |
| 403 | `FORBIDDEN_ROLE`, `FORBIDDEN_ORG`, `ORG_NOT_APPROVED`, `USER_SUSPENDED` | Unauthorised state; never retry |
| 404 | `NOT_FOUND`, `HTTP_ERROR` (unknown route) | Not-found state |
| 409 | `INVALID_STATE_TRANSITION`, `DUPLICATE_OFFER`, `OFFER_ALREADY_ACCEPTED`, `ALLOCATION_EXCEEDS_AVAILABLE`, `INCOMPLETE_MEASUREMENT`, `NOT_CURRENT`, `ALREADY_REVERSED`, `DUPLICATE_CERTIFICATE_REF`, `USER_ALREADY_EXISTS` | Show the message and the `details`; refresh the record; **never auto-retry with a different quantity** |
| 422 | `VALIDATION_ERROR` (Pydantic, with `details[].loc/msg`), `QUANTITY_INCONSISTENT`, `OTP_INVALID` | Map `details[].loc` to form fields |
| 500 | (unhandled) | Generic error with retry; see the defect list in §6 |

---

## 5. API integration inventory

**Legend:** ✅ works as needed · ⚠️ works, with a caveat the UI must state · 🟥 stub or placeholder (no real effect) · ⛔ missing (the screen needs it but no endpoint exists). Paths are relative to `/api/v1`.

### 5.1 Shared and reference

| Module | Endpoint | Method | Required role | Frontend screen | Status |
|---|---|---|---|---|---|
| Health | `/health` (root) | GET | public | App boot, backend-down banner | ✅ |
| Materials | `/materials` | GET | public | Material pickers, polymer labels | ✅ 8 categories (PET, HDPE, PVC, LDPE, PP, PS, OTHER, MLP) |
| Orgs | `/orgs/me` | GET | any | Organisation profile (all roles) | ✅ Includes the type-specific profile (registration numbers, capacity, etc.) |
| Orgs | `/orgs/me` | PATCH | org role OWNER/ADMIN | Edit profile | ⚠️ Only generator kind and collector radius/capacity are updatable in `profile_data` |
| Orgs | `/orgs/me/members` | POST | OWNER/ADMIN | Team access | ⚠️ Adds an existing user only; no list-members endpoint |
| Orgs | *(directory / list orgs)* | — | — | Recycler picker (collector), EPR-client picker (recycler), recycler picker (EPR), admin approvals | ⛔ |
| Payments | `/payments` | GET `?status` | any (scoped to payer or payee) | Generator payments, collector transactions | ✅ Simulated ledger, labelled as such |
| Payments | `/payments/{id}/mark-paid` | POST `{external_ref}` | payer org | Collector settles generator payout | ✅ Simulated |
| Anomalies | `/anomalies` | GET `?status&severity` | any | NGO discrepancies, recycler and collector flags | ⚠️ Not scoped by org |
| Anomalies | `/anomalies/{id}/resolve` | POST `{status, note}` | NGO or any OWNER | NGO discrepancy management | ⚠️ Every owner passes the check (§3) |
| Audit | `/audit/logs` | GET `?entity_type` | any | Admin and NGO audit history | ⚠️ Last 100 rows, unscoped; includes the hash chain |
| Documents | `/documents/upload-url` → `/{id}/complete` → `/{id}/download-url` | POST/POST/GET | any | Listing photos, scale photos, weighbridge slips, evidence | 🟥 No bytes are stored. URLs point to `reloop-storage.local`. Without a client `sha256`, the hash is computed from the document id, not the file |
| Impact | `/impact/summary` | GET | public | Platform totals (admin, public) | ⚠️ "trees" and "CO₂" are fixed multipliers, so they need a label |

### 5.2 Generator

| Module | Endpoint | Method | Required role | Frontend screen | Status |
|---|---|---|---|---|---|
| Batches | `/batches` | GET `?status&material&locality` | any (scoped to own org for generators) | Overview, listings, batch tracking | ✅ Returns `quantities` and `verification` per batch |
| Batches | `/batches` | POST | GENERATOR | Create listing | ✅ `{material_code, estimated_kg>0, pickup_address, lat?, lng?, locality?, available_from, available_to, document_ids?, ai_prediction_id?}` → `{id, batch_code, qr_token, status, qr_url}` |
| Batches | `/batches/{id}` | PATCH | GENERATOR (owner) | Edit listing | ✅ Only while `LISTED` (otherwise 409) |
| Batches | `/batches/{id}/cancel` | POST | GENERATOR (owner) | Withdraw listing | ✅ `LISTED` or `ASSIGNED` |
| AI | `/ai/classify` | POST `{document_id?, sample_text?}` | any | Polymer suggestion while listing | 🟥 **Always returns PET at 0.92**, whatever the input. I will not present it as a classification |
| AI | `/ai/classify`, `/ai/status` (AI patch) | POST `{image_base64, document_id?}` | any | "Detect from photo" in the Flutter app | ✅ Placeholder removed. Answers 503 `AI_MODEL_NOT_CONFIGURED` until the team's model is plugged into `backend/app/modules/ai/classifier.py`; then returns the model's top-3 with confidence. The generator's final material is stored against the prediction |
| Offers | `/batches/{id}/offers` | GET | any | Offers | ✅ Sorted by rate descending; includes collector name, status, expiry |
| Offers | `/batches/{id}/offers/{offer_id}/accept` | POST | GENERATOR (owner) | Accept offer | ✅ Declines the other open offers |
| Offers | *(reject a single offer)* | — | — | Decline offer | ⛔ Offers are declined only by accepting another one |
| Handover | `/batches/{id}/handover/confirm` | POST `{otp?}` or `{qr_token?}` | GENERATOR (owner) | Handover confirmation | ✅ Sets `PICKED_UP` and creates the payout. **Flow direction:** the collector records the weight first and receives the OTP; the generator then enters that OTP. This is the reverse of the prototype |
| Passport | `/passports/{batch_code}` | GET | any | Material passport | ✅ Full custody, receipts (all versions), runs, certificates, NGO history, allocations, documents, anomalies |
| Passport | `/passports/{code}/snapshot` | POST | any | "Save snapshot" | 🟥 Creates a document row only; no PDF is produced |
| Batches | `/batches/{id}/qr` | GET (PNG) | any | QR on the passport | ✅ Encodes `reloop://batch/{qr_token}` |
| Batches | `/batches/{id}/events` | GET | any | Timeline | ✅ |
| Batches | `/batches/{id}/trace` | GET | any | Lineage; **processing input kg** | ✅ The only per-batch source of processing **input** kg |
| Payments | `/payments` | GET | any | Payments | ✅ |
| Reports | `/generator/certificates` | GET | GENERATOR | Certificates | 🟥 `kg_contributed` is the **estimated** (listed) kg, and the download URLs are fake. I will not show this as a recycling statement; I'll derive one from passport quantities instead |
| Intelligence | `/generator/supply-profiles` | GET/POST | GENERATOR | Recurring supply (analytics) | ✅ |

### 5.3 Collector

| Module | Endpoint | Method | Required role | Frontend screen | Status |
|---|---|---|---|---|---|
| Collections | `/collections/available` | GET `?lat&lng&radius_km` | COLLECTOR | Available listings | ⚠️ Returns `material_category_id` but no code; join it with `/materials`. Distance is a flat-earth approximation and is 0 when coordinates are missing |
| Collections | `/collections/{batch_id}/offers` | POST `{generator_rate_per_kg>0, proposed_pickup_at}` | COLLECTOR | Make offer | ✅ `409 DUPLICATE_OFFER` if one is already open |
| Collections | `/collections/jobs` | GET `?status` | COLLECTOR | Assignments | ✅ Minimal fields (no material, no quantities) |
| Collections | `/collections/{batch_id}/pickup` | POST `{collected_kg>0, document_ids?, notes?}` | COLLECTOR (assigned) | Pickup verification | ⚠️ Returns the `otp` in the response (demo behaviour). Raises the `PICKUP_WEIGHT_EXCESS` flag only above **+20%**; nothing is flagged below −20%. **Calling it twice breaks the batch** (§6) |
| Collections | `/collections/{batch_id}/withdraw` | POST | COLLECTOR (assigned) | Can't collect | ⚠️ No status check, so it can be called after pickup |
| Consignments | `/consignments` | POST `{batch_ids[], destination_recycler_org_id, vehicle_no?, aggregation_plan_id?}` | COLLECTOR | Create consignment | ⚠️ Needs a recycler org id, and there is no directory (⛔). The only source is `GET /recycler/offers/public` (`recycler_org_id` with no name) |
| Consignments | `/consignments`, `/consignments/{id}` | GET | COLLECTOR / RECYCLER (scoped) | Consignments, delivery records | ✅ Items carry `estimated_kg` only; received figures come from per-batch quantities |
| Plans | `/aggregation/plans`, `/aggregation/plans/{id}` | GET | any | Aggregation plans | ⚠️ Plans have no collector field, so a collector sees every plan |
| Plans | `/aggregation/plans/{id}/accept` and `/cancel` | POST | RECYCLER / COLLECTOR | Accept or decline a plan | ⚠️ No ownership check. Acceptance does **not** assign batches to the collector |
| Payments | `/payments` | GET | any | Earnings and transactions | ⚠️ Only generator payouts exist (collector as payer). **No collector-earnings records** |
| Performance | `/suppliers/{org_id}/performance` | GET | any | Own indicators | ✅ Returns `INSUFFICIENT` with nulls when there is no history |

### 5.4 Recycler

| Module | Endpoint | Method | Required role | Frontend screen | Status |
|---|---|---|---|---|---|
| Incoming | `/recycler/incoming` | GET | RECYCLER | Incoming batches | ✅ `IN_TRANSIT`/`ASSIGNED` batches destined for me, including `qr_token` |
| Consignments | `/consignments`, `/consignments/{id}/arrive` | GET/POST | RECYCLER | Incoming consignments | ✅ |
| Receipts | `/recycler/receipts` | POST `{batch_id \| qr_token, received_kg, accepted_kg, rejected_kg, quality_grade, contamination_pct, rejection_disposition?, document_ids?}` | RECYCLER | Record receipt | ⚠️ Enforces `accepted + rejected = received` (422 `QUANTITY_INCONSISTENT`) ✅. **Does not check batch status or for an existing receipt** (§6). **No gross/tare fields**: the brief and README mention them, but the API takes received kg only |
| Receipts | `/recycler/receipts/{id}/corrections` | POST `{received_kg, accepted_kg, rejected_kg, quality_grade, contamination_pct, reason}` | RECYCLER (owner) | Correct receipt (new version) | ✅ Versioned; the old version is kept |
| Receipts | *(list my receipts, with ids)* | — | — | Material receipts table; **choosing inputs for a run** | ⛔ Receipt ids are returned only at creation time. Seeded receipts can't be used as run inputs from the UI |
| Processing | `/recycler/processing-records` | POST `{material_code, run_started_at, run_ended_at, inputs:[{recycler_receipt_id, input_kg>0}], output_kg, residue_kg, output_form?, eligible_kg, eligibility_basis?, document_ids?}` | RECYCLER | Record a run | ⚠️ Enforces output + residue ≤ input and eligible ≤ output ✅. Computes yield and unaccounted ✅. Auto-queues NGO review ✅. **Does not check input against accepted kg, re-use of a receipt, or material match** (§6). **No "incomplete measurement" mode**: output is required |
| Processing | `/recycler/processing-records` | GET | RECYCLER | Runs list | ✅ Includes `eligible_kg`, `allocated_kg`, `available_kg`, `yield_pct`; no input breakdown |
| Certificates | `/recycler/processing-records/{id}/certificates` | POST `{certificate_ref, packaging_category, certificate_kg, issued_on?, evidence_doc_id?}` | RECYCLER | Record a CPCB certificate reference | ✅ Duplicate-reference check and kg ≤ output. No list endpoint (refs appear in passports) |
| Yield | `/yield` | GET `?material` | any (own runs for recyclers) | Material yield | ✅ The mass-balance 3% flag is **not** raised by the backend |
| Capacity | `/recycler/capacity` | GET | RECYCLER | Dashboard | ✅ |
| Offers | `/recycler/offers` (GET/POST), `/recycler/offers/public` (GET, public) | | RECYCLER / public | Procurement requirements (price offers) | ✅ |
| Demand | `/recycler/demand-profiles` | GET/POST | RECYCLER | Procurement requirements | ✅ |
| Aggregation | `/aggregation/plans/propose` (also `plans:propose`) | POST `{demand_profile_id? \| material_code+target_kg, need_by?, max_distance_km?}` | RECYCLER | Aggregation planner | ⚠️ **Persists the plan and reserves batches immediately**; there is no preview. Uses a fixed 92% usable factor, a fixed 12.5 km distance and fixed ₹15/₹8 rates, not the pricing assumptions. "Fulfils" compares **listed** kg (not usable kg) with the target. `max_distance_km` is ignored |
| Costing | `/costs/estimate`, `/costs/compare` | POST | any | Landed cost comparison | ⚠️ Hard-coded rates (₹15/₹8, then ₹14.5/₹7.5 in compare); `ids` and pricing assumptions are ignored. The UI must label these as model estimates |
| Costing | `/pricing-assumptions` | GET (public) / POST | RECYCLER/OWNER/ADMIN | Assumptions panel | ✅ Versioned, but **the cost endpoints don't use them** |
| Forecast | `/forecasts/shortages` | GET `?material` | RECYCLER | Supply outlook | 🟥/⚠️ **Substitutes invented numbers when real values are zero** (2,500 / 4,800 / 6,000 kg; verified with LDPE). `recommended_suppliers` and `suggested_advance_plans` are hard-coded names. Confirmed supply is not scoped to the recycler |
| Forecast | `/forecasts/supply`, `/forecasts/demand` | GET (public) | — | Supply outlook | ✅ Rows are labelled `PREDICTED` |
| Performance | `/suppliers/{org_id}/performance` | GET | any | Supplier performance | ⚠️ No endpoint lists suppliers; ids must come from batches and consignments |
| Allocations | `/epr/allocations` | GET `?status` | RECYCLER (own runs) / EPR | Allocation ledger | ✅ |
| Allocations | `/epr/allocations` | POST `{processing_record_id, epr_org_id, certificate_id?, packaging_category, reporting_period, quantity_kg>0, request_id?}` | RECYCLER | Allocate | ✅ **`409 ALLOCATION_EXCEEDS_AVAILABLE` verified.** ⚠️ `epr_org_id` isn't checked to be an EPR client, and there is no directory to pick one (⛔) |
| Allocations | `/epr/allocations/{id}/reverse` | POST `{reason}` | RECYCLER | Reverse | ✅ Append-only reversal row |

### 5.5 NGO auditor

| Module | Endpoint | Method | Required role | Frontend screen | Status |
|---|---|---|---|---|---|
| Queue | `/ngo/verifications` | GET `?decision` | NGO | Dashboard, assigned cases | ⚠️ Unscoped (§3) |
| Case | `/ngo/verifications/{id}` | GET | NGO | Evidence review, reconciliation | ✅ All pickup and receipt versions (with ids), anomalies, documents |
| Claim | `/ngo/verifications/{id}/claim` | POST | NGO | Start review | ✅ |
| Decision | `/ngo/verifications/{id}/decision` | POST `{decision: VERIFIED\|FLAGGED\|REJECTED\|REQUIRES_CORRECTION, comments?, evidence_doc_ids?, follow_up_required?}` | NGO | Record decision | ⚠️ Append-only ✅. Accepts a **non-current** id, which can leave two current decisions. Comments are optional server-side, so the UI will require them for non-VERIFIED decisions |
| Doc requests | `/ngo/verifications/{id}/document-requests` | POST `{addressed_to_org_id, request_text}` | NGO | Document requests | ⚠️ Stored only as a batch event. There is no list, no response, no status and no notification to the party (⛔ for follow-up) |
| Custody | `/batches/{id}/events`, `/batches/{id}/trace`, `/passports/{code}` | GET | any | Chain of custody | ✅ |
| Discrepancies | `/anomalies`, `/anomalies/{id}/resolve` | GET/POST | NGO | Discrepancy management | ✅ / ⚠️ (§3) |
| Reports | `/ngo/reports` | GET | NGO | Verification reports | ⚠️ Counts by decision only; the period is hard-coded "FY2026-27" |
| Impact | `/ngo/impact` | GET | any | Dashboard | ⚠️ "Verified kg" uses **accepted** kg, not recovered output; CO₂ uses a fixed multiplier |
| Audit | `/audit/logs` | GET | any | Audit history | ⚠️ (§5.1) |

### 5.6 EPR brand / PIBO

| Module | Endpoint | Method | Required role | Frontend screen | Status |
|---|---|---|---|---|---|
| Dashboard | `/epr/dashboard` | GET `?period` | EPR_CLIENT | Compliance overview | ⚠️ **Overstates verification.** An allocation counts as 100% verified if *any* input batch of its run is verified. I'll compute the verified share per batch from passports instead and show the backend figure with that caveat |
| Targets | `/epr/targets` | GET `?period` / POST `{reporting_period, packaging_category, target_kg, source_note?}` | EPR_CLIENT | Obligations and targets | ✅ Upsert, self-declared |
| Ledger | `/epr/allocations` | GET | EPR_CLIENT (own) | Allocation history | ✅ Includes `processing_record_id`. ⚠️ EPR users can't call the processing-record list, so lineage goes through passports |
| Requests | `/epr/allocation-requests` | POST | EPR_CLIENT | Request allocation | 🟥 **Not persisted.** Returns a random id; the recycler never sees it (verified: no table exists) |
| Certificates | `/epr/certificates` | GET | EPR_CLIENT | Supporting records | ✅ Recycler-entered certificate references linked to my active allocations |
| Discrepancies | `/epr/discrepancies` | GET | EPR_CLIENT | Discrepancy monitoring | ✅ Anomaly flags on batches behind my allocations. ⚠️ No way to raise one |
| Reports | `/epr/reports`, `/epr/reports/{id}` | POST / GET | EPR_CLIENT | Reports and exports | 🟥 Returns a random id and a fake `reloop-storage.local` PDF URL. I'll generate CSV client-side from real ledger data instead |
| Traceability | `/passports/{code}`, `/batches/{id}/trace` | GET | any | Batch traceability | ✅ Generator identity is hidden for EPR users |
| Recyclers | — | — | — | Recycler records | ⛔ No directory |

### 5.7 Admin

| Module | Endpoint | Method | Required role | Frontend screen | Status |
|---|---|---|---|---|---|
| Approvals | `/admin/orgs/{id}/approve` | POST `{decision: APPROVED\|REJECTED\|SUSPENDED, note?}` | platform admin | Organisation approvals | ⚠️ Works by id, but **there is no endpoint to list pending orgs** (⛔), so the admin cannot find what to approve. The note isn't stored |
| Monitoring | `/impact/summary`, `/anomalies`, `/audit/logs` | GET | — | Platform overview, alerts, audit trail | ✅ (with caveats above) |
| Users | — | — | — | User management | ⛔ None |

**Admin scope I'll build:** platform totals, the anomaly feed with resolve, the audit-log viewer with hash-chain display, and approval by org id (with a stated limitation). No user management.

---

## 6. Verified defects (reproduced against the running API)

| # | Severity | Defect | Effect on the frontend |
|---|---|---|---|
| D1 | **High** | `POST /auth/refresh` → 500 on SQLite (naive vs aware datetime) | No silent refresh. Sessions end at access-token expiry (24 h) |
| D2 | **High (security)** | Refresh tokens are accepted as access tokens | Store the refresh token carefully; backend fix needed |
| D3 | **High (integrity)** | `POST /recycler/processing-records` accepts input kg above the receipt's accepted kg (5,000 from 480), the same receipt in multiple runs, and a material that doesn't match | The frontend will cap inputs at accepted kg minus already-processed kg and lock the material. **The backend still accepts bad data from other clients, so double-counting protection is incomplete upstream of allocation** |
| D4 | **High (integrity)** | `POST /recycler/receipts` accepts a batch in any status (including `LISTED`, never collected) and a second receipt on the same batch | The frontend only offers receipts for `IN_TRANSIT` batches with no receipt. The backend accepts both |
| D5 | **High** | A second `POST /collections/{id}/pickup` before confirmation leaves two current pickup records. `GET /batches/{id}` then **500s permanently** for that batch (same after D4) | Disable the pickup action once a pickup exists; the backend needs a guard |
| D6 | Medium | New NGO verifications are assigned to the admin's NGO-typed governance org | Cases still appear (unscoped list), but "assigned to me" can't be shown accurately |
| D7 | Medium | The EPR dashboard counts a whole allocation as verified if any input batch is verified | Compute verification per batch on the client and label the source |
| D8 | Medium | `/forecasts/shortages` replaces zeros with invented figures and returns hard-coded supplier names | I'll show a figure only if the material has real demand-profile and forecast rows; supplier suggestions are hidden |
| D9 | Medium | `quantities.processed_kg` is **recovered output** (pro rata), not processing input. `ngo_verified_kg` falls back to accepted, collected or **estimated** kg when nothing is processed | The UI maps the fields explicitly (§8) and never shows a verified quantity without a measured output |
| D10 | Low | `requirements.txt` is missing `aiosqlite`; Alembic has no migrations | Documented in the run guide |
| D11 | Low | Plans and cost endpoints ignore the pricing assumptions; propose has no preview | Labelled as model estimates; "Propose" is presented as creating a plan |

---

## 7. Proposed backend changes (separate; none made)

In order of value to the integration. Each is small and leaves existing business rules intact; most only add the guards the docs already describe.

1. **Directory endpoint:** `GET /orgs?type=RECYCLER|EPR_CLIENT|COLLECTOR&status=` (id, legal name, type, approval status, registration fields), plus `GET /admin/orgs?status=PENDING`. This unblocks consignment destinations, allocation targets, the EPR recycler records page and admin approvals.
2. **Receipts list:** `GET /recycler/receipts?current=true` returning `id, batch_id, batch_code, material, accepted_kg, processed_kg, available_kg`. This unblocks processing runs.
3. **Integrity guards (D3–D5):**
   - receipts only for `IN_TRANSIT`/`ARRIVED` batches with no current receipt;
   - processing input ≤ accepted kg minus already processed, and material must match;
   - only one pickup while unconfirmed;
   - decisions only on current verification rows.
4. **Auth fixes (D1–D2):** make `expires_at` timezone-aware, check `type == "access"` in the dependency, and add `POST /auth/logout` that revokes the refresh token.
5. **Persist allocation requests:** add a table, `GET /epr/allocation-requests` for both sides, and link `request_id` on allocation.
6. **Document requests:** a list endpoint with status and responses.
7. **Scoping:** NGO queue by `ngo_org_id`; anomalies by involvement; plans by collector; give the admin user a non-NGO org.
8. **Shortages:** remove the invented fallbacks and hard-coded supplier names.
9. **Pagination:** no endpoint paginates or sorts. Add `limit`/`offset` to `/batches`, `/anomalies`, `/audit/logs` and `/epr/allocations`. Until then, tables paginate on the client, which is acceptable at pilot volumes.

---

## 8. Quantity-field mapping the frontend will use

| UI stage | Source | Notes |
|---|---|---|
| Listed | `quantities.estimated_kg` | Generator estimate |
| Collected | `quantities.collected_kg` | Present from collector weigh-in; **confirmed** only when `passport.custody.pickup_records[].confirmed_at` is set. The UI shows "awaiting generator confirmation" until then |
| Received | `quantities.received_kg` | Current receipt version |
| Accepted / Rejected | `quantities.accepted_kg` / `rejected_kg` | Rejected stays visible |
| Processing input | `GET /batches/{id}/trace → processing_runs[].input_kg` | **Not** in `quantities` |
| Recovered output | `quantities.processed_kg` (= `apportioned_output_kg`) | Label "Recovered output (pro rata)", never "processed" |
| NGO-verified | `quantities.ngo_verified_kg`, **shown only if** `processed_kg` is present and the current decision is `VERIFIED` | Prevents the fallback-to-estimate in D9 |
| EPR-eligible | Run-level `eligible_kg` (recycler-declared), via `/recycler/processing-records` | Not exposed per batch to other roles |
| EPR-allocated | `quantities.epr_allocated_kg` | Pro rata share of active allocations on the run |
| Predicted supply | `/forecasts/supply` | Always labelled "Predicted, not inventory" |

All `quantities` values arrive as **strings** with three decimal places and are parsed once in the API layer.

---

## 9. Pagination, filtering, sorting, uploads

- **Pagination:** none on any endpoint.
- **Filtering:** query parameters as listed in §5 (`status`, `material`, `locality`, `decision`, `period`, `severity`, `entity_type`).
- **Sorting:** fixed server order (mostly newest first).
- **File uploads:** no multipart endpoint. The upload-URL flow is a stub (§5.1). The frontend will compute SHA-256 in the browser, call `upload-url` and `complete` with the real hash, and link `document_ids`. The bytes themselves can't be stored until real storage exists, and the UI will say so.

---

## 10. Stage plan given these findings

| Stage | Scope | Depends on backend change? |
|---|---|---|
| 2 Foundation | Vite + React + TS + Tailwind + shadcn/ui, router, Axios client with the error envelope, TanStack Query, auth (login, `/auth/me`, logout-local, 401/403 handling, session-expired state), role layouts, design tokens from the prototype | No (refresh disabled until D1 is fixed) |
| 3 Core workflows | Generator (list, offers, handover by OTP, passport, payments); collector (available, offer, pickup weigh-in with OTP hand-off, consignment); recycler (incoming, arrive, receipt with the rule, correction, runs, allocation) | Consignment destination and allocation target need **#1**; runs from seeded receipts need **#2**. Workaround: ids from `/recycler/offers/public` and existing allocations, clearly marked |
| 4 Verification and compliance | NGO queue, claim, checklist from real data, decisions, flags, reports; EPR overview (per-batch verification), targets, ledger, traceability, certificates, discrepancies, CSV export | Requests and document requests stay "not persisted by the backend" until **#5/#6** |
| 5 Intelligence | Demand profiles, offers, propose plan, plan detail, cost estimate and compare, forecasts (D8 handling), supplier performance | Labelled model estimates |
| 6 Testing | Playwright run against the live API per role; quantity, safeguard and permission tests; `npm run build`; existing backend suite unchanged | — |
