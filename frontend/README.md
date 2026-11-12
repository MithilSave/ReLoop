# ReLoop web app

The integrated ReLoop frontend: one responsive React application for all six roles.

| Role | Layout |
|---|---|
| Generator, Collector, Recycler | Phone-first. Bottom tabs below 1024px, sidebar on desktop. Installable as a PWA |
| NGO auditor, EPR company, Platform admin | Desktop console that remains usable on phones |

Every screen reads and writes the FastAPI backend in `../backend`; there is no mock data. The backend is the source of truth for rules, permissions, calculations and records.

`../frontend-legacy` is the earlier prototype, kept for reference. It ran entirely on demo data.

## Run locally

```bash
# 1. Backend (Python 3.12+)
cd backend
python -m venv .venv && . .venv/bin/activate      # Windows: .venv\Scripts\Activate.ps1
pip install -r requirements.txt                    # now includes aiosqlite
python seed_data.py                                # fresh demo data (deletes nothing; re-run after removing reloop.db)
uvicorn app.main:app --reload --port 8000          # http://localhost:8000/docs

# 2. Frontend (Node 20+)
cd frontend
cp .env.example .env.development                   # VITE_API_BASE_URL=http://localhost:8000
npm install
npm run dev                                        # http://localhost:5173
```

Demo accounts come from `backend/seed_data.py` and all use the password `reloop123`: `generator@`, `collector@`, `recycler@`, `ngo@`, `epr@` and `admin@reloop.in`. The login screen lists them only when `VITE_SHOW_DEMO_ACCOUNTS=true`; `.env.production` turns this off.

## Tests

```bash
npm test            # unit tests: quantity mapping, error envelope, role mapping
npm run build       # type-check + production build
npm run e2e         # Playwright against the running backend and dev server (seed first)

cd ../backend
python seed_data.py && python test_api_suite.py && python test_integration_fixes.py
```

`e2e/workflow.spec.ts` drives one batch through the full chain in the UI, signing in as each role in turn, and checks the backend's state after every step:

1. listing;
2. offer (including the duplicate-offer refusal);
3. acceptance;
4. weigh-in, with the ±20% note, a required scale photo and the second-weigh-in guard;
5. OTP handover (wrong code refused);
6. consignment;
7. arrival and receipt (an unbalanced receipt is blocked; a second receipt is refused);
8. processing run (over-input blocked in the browser and refused by the server; re-processing refused);
9. NGO decision (a non-verified decision requires a reason);
10. allocation (a 409 over-allocation is shown with its figures; a valid allocation is saved);
11. EPR lineage.

It also covers role isolation (the UI and a backend 403), session expiry, silent token refresh, and logout revoking the refresh token.

`e2e/pages.spec.ts` opens all 52 routes for their roles at 1400px and 390px. It fails on JavaScript errors, error states or horizontal overflow.

## Architecture

```
src/
  api/        Axios client, error envelope → ApiError, token store, single-flight refresh
  services/   One module per backend area. The only place HTTP calls are made
  hooks/      TanStack Query hooks and query keys; mutation helper that invalidates affected records
  types/      TypeScript mirrors of the FastAPI schemas (field names unchanged)
  lib/        Quantity mapping (tested), formatting, Zod field helpers, CSV export, role mapping
  components/ shadcn-style UI on Radix (button, dialog/drawer, tabs, data table, field), states
  features/   Material passport, six-stage quantity ladder, QR, event timeline
  layouts/    App shell: sidebar, top bar, phone bottom tabs, backend-status banner
  pages/      Screens per role
  app/        Router, auth provider, route guards, navigation
```

Stack: React 18, Vite 5, TypeScript, Tailwind 3, Radix UI (shadcn/ui pattern, written by hand because the shadcn CLI registry wasn't reachable), React Router 6, TanStack Query 5, Axios, React Hook Form, Zod, Recharts, Lucide.

### Rules the UI holds to

- **Each quantity stage comes from its own field** (`lib/quantities.ts`):
  - processing input is read from `/batches/{id}/trace`;
  - `quantities.processed_kg` is shown as **recovered output (pro rata)**;
  - NGO-verified kg appears only when the current decision is VERIFIED **and** output has been measured, because the backend falls back to estimated kg otherwise.
- **Validation runs in the browser first, and the backend still decides.** This covers `accepted + rejected = received`, input ≤ available stock, output + residue ≤ input, and eligible ≤ output. A server refusal (409/422) is shown with its own figures and is never retried with altered values.
- **Labels stay inside the facts.** NGO verification is labelled independent and non-statutory. Certificates are labelled "recycler-entered, generated on the CPCB portal". EPR targets are labelled self-declared.
- **Mutations refresh every screen that shows the same record**, so one action updates every role's view.

## What depends on backend work

The integration patch (`backend/`, first commit on this branch) added:
- the organisation directory;
- the receipts list;
- integrity guards on receipts, processing, pickups and NGO decisions;
- auth fixes: refresh no longer returns 500, token types are checked, and logout exists.

These gaps remain in the backend. Each affected screen says so where it applies:

| Gap | Effect in the app |
|---|---|
| File storage is a stub (fake upload URLs) | Photos and slips are hashed in the browser and only the SHA-256 is recorded; the file itself isn't stored |
| No polymer model is connected by default. `/ai/classify` returns 503 `AI_MODEL_NOT_CONFIGURED` until the team's model is plugged into `backend/app/modules/ai/classifier.py` (the old fixed "PET 0.92" answer was removed) | The web form uses manual selection; the Flutter app (`mobile_v2`) offers "Detect from photo" |
| EPR allocation requests aren't persisted | Request button disabled, with an explanation |
| EPR and NGO PDF reports are stubs | CSV export built in the browser from API data |
| NGO document requests are batch events only | Listed from events; no status or response tracking |
| `/forecasts/shortages` substitutes placeholder figures | Suspect values are flagged; hard-coded supplier names are hidden |
| Cost and plan endpoints use fixed rates, not pricing assumptions | Results are labelled model estimates |
| EPR dashboard counts a whole allocation as verified once any input is | Recomputed per source batch from passports |
| No collector-earnings records | Only generator payouts are shown |
| Plans have no collector, and acceptance doesn't assign batches | Stated on the plans screen |
| No pagination on any list | Tables paginate in the browser |
| Admin user's org is NGO-typed, so new cases go to it | All cases are listed; noted on the Cases screen |
| Batch codes are numbered from the row count, but seeded codes are 000101–000105 | After about 96 new batches a new code collides with a seeded one (unique constraint → 500). Fix in `generate_batch_code` |
