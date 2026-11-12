# 11 — Security and Auditability

## 1. Authentication
Argon2id password hashes. Access JWT lasts 15 minutes; the refresh token lasts 7 days, is rotated, and is stored hashed. Login is rate-limited (5 attempts/min per IP and per account). The pickup OTP is 6 digits, single-use, valid for 10 minutes, and limited to 5 attempts. Platform admin requires TOTP 2FA (P1).

## 2. Authorisation model
Three checks run on every request, in FastAPI dependencies, **server-side**:
1. **Org type** permits the action (matrix §3).
2. **Org role** (OWNER/ADMIN/MEMBER/VIEWER) permits a write. VIEWER is read-only.
3. **Resource relationship**: the org owns, is assigned to, is the destination of, has scope over, or holds an allocation on the resource. Failure returns 404 to avoid leaking existence.

The org's `approval_status` must be APPROVED for any write by a Recycler, NGO or EPR client.

## 3. Role-permission matrix

Legend: **W** write · **R** read · **R-own** only the org's own records · **R-scope** within NGO scope · **R-linked** only records linked to the client's allocations · **—** none.

| Action | Generator | Collector | Recycler | NGO | EPR company |
|---|---|---|---|---|---|
| Create/edit own batch (LISTED) | W | — | — | — | — |
| View batch | R-own | R (listed/assigned) | R (destined/received) | R-scope | R-linked |
| Declare supply profile | W | — | — | — | — |
| Make collection offer | — | W | — | — | — |
| Accept collection offer | W | — | — | — | — |
| Record pickup weight | R | W (assigned) | R | R-scope | R-linked |
| Confirm handover (OTP/QR) | W | initiates | — | — | — |
| Create consignment / dispatch | — | W | R (incoming) | R-scope | — |
| Declare demand profile | — | — | W | — | — |
| Propose aggregation plan | — | — | W | — | — |
| Accept aggregation plan | per-batch offer only | W (if suggested) | W | — | — |
| Run cost estimate / compare | — | W (own perspective) | W | — | — |
| View supplier performance | own | own + generators (aggregate) | suppliers | R-scope | — |
| View forecasts | — | R (aggregate) | R | R (aggregate) | — |
| Record receipt (accepted/rejected) | R | R | W (destination) | R-scope | R-linked |
| Record processing / yield | R (passport) | — | W | R-scope | R-linked |
| Add certificate reference | — | — | W | R-scope | R-linked |
| Verify evidence (decision) | — | — | — | W | R-linked |
| Request allocation | — | — | — | — | W |
| Create / reverse allocation | — | — | W (own runs) | R-scope | R-own |
| Material passport | R-own (full) | R (own jobs) | R (received) | R-scope (full) | R-linked (generator PII masked) |
| Download EPR evidence report | — | — | own-run summary | R-scope | W/R |
| Resolve anomaly flag (note) | — | — | — | W (scope) | — |

This matrix refines the brief: only the recycler, as the certificate holder, writes allocations; the EPR client requests and views; the NGO reviews.

## 4. Implementation
- `require(org_types=[...], org_roles=[...])` dependency plus a resource loader that checks the relationship.
- No NGO or EPR code path exists in custody write services (defence in depth).
- PostgreSQL row-level security (P1) as a second layer on `org_id`.

## 5. Data privacy (India DPDP Act, 2023: consent and purpose limitation [REG-V; confirm rules in force, Q-08])
- Generator personal data (name, phone, exact address) is visible to the assigned collector and destination recycler **only while needed**. EPR clients and public reports see locality and generator type only.
- Payout identifiers are stored masked or tokenised. Full bank or UPI details are never stored in the MVP ([SIMULATED] payouts).
- Exact coordinates are snapped to about 100 m for anyone except the assigned collector.
- Supplier performance data is shown to counterparties only as indicators with n, never as raw complaint text.
- Data export and erasure requests: personal fields are anonymised, while custody quantities are kept for audit (lawful-basis retention, Q-08).

## 6. Document security
Private bucket, presigned URLs (PUT 10 min, GET 5 min) issued after a permission check. MIME/size whitelist, and EXIF GPS stripped from public renderings but retained (hashed original) for the NGO. SHA-256 is computed server-side. Antivirus scanning is P1.

## 7. Audit history and evidence integrity
- `audit_logs` row for every write. The app role is INSERT-only. Each row stores `prev_hash` and `row_hash = SHA-256(prev_hash || canonical_json(row))`. A nightly job verifies the chain and publishes the daily head hash in the NGO report.
- Versioned custody records, append-only verification, reversal-only ledgers (05 §7).
- Aggregation plans, cost estimates and forecasts store `algorithm_version` and `assumptions_version` so that recommendations can be reproduced.

## 8. Duplicate prevention
Unique `batch_code`, `qr_token`, `(recycler_org_id, certificate_ref)`, one accepted offer per batch, one current record per batch, one active plan per batch, one consignment per batch per trip, idempotency keys, the allocation cap (05 §6), and a photo-hash reuse flag.

## 9. Backup and recovery
Managed Postgres daily snapshots plus point-in-time recovery (7 days for the MVP, 35 days in production), and object-storage versioning. RPO ≤ 15 min, RTO ≤ 4 h (production target). A restore drill runs quarterly.

## 10. Threats

| Threat | Mitigation |
|---|---|
| Inflated weights by colluding parties | Cross-party confirmations, receipt vs pickup checks, NGO review, AN-rules, performance indicators |
| Fake processing to sell certificates | Mass-balance checks, yield plausibility, NGO, certificate uniqueness; off-platform double use is a declared residual risk (08 §7) |
| Double allocation (race) | Row lock plus a deferred constraint trigger |
| Gaming aggregation (fake listings to fill plans) | Plans use only listings, and kg becomes real only at OTP-confirmed pickup and receipt |
| Forecast treated as stock | No FKs from ledgers to forecasts; UI labelling |
| Algorithmic unfairness to suppliers | Rule-based, explainable indicators with n; no auto-ban; dispute path |
| IDOR | Relationship checks; 404 on mismatch |
| QR forgery | Random `qr_token`; the scan must match the expected destination |
| Insider tampering | Append-only grants and a hash chain |
