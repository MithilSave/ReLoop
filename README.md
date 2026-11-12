# ReLoop – Circular Plastics Traceability & EPR Exchange

ReLoop is a plastic waste marketplace and statutory EPR compliance traceability platform for urban environments (pilot: Mumbai, India). It connects five core participants around a single traceable unit — the **waste batch** — with immutable custody tracking, zero double-counting safeguards, Edge-AI polymer classification, and digital material passports.

---

## 🚀 Quick Start (Running Locally)

### 1. Prerequisites
- Python 3.12+ (installed in `backend/.venv`)
- Flutter 3.29+ / Dart 3.7+ (`C:\App Devlopment\flutter\bin\flutter.bat`)

### 2. Start the Backend API
In a PowerShell terminal:
```powershell
cd "C:\Users\Mithil Save\Documents\GitHub\LYB\backend"
& ".\.venv\Scripts\Activate.ps1"
uvicorn app.main:app --reload --port 8000
```
- Interactive Swagger API docs: [http://localhost:8000/docs](http://localhost:8000/docs)
- Health check: [http://localhost:8000/health](http://localhost:8000/health)

*(Note: The database automatically operates on zero-config local SQLite `reloop.db` or connects to PostgreSQL if available)*

### 3. Re-seed Demo Data (Optional)
To reset and re-seed sample Mumbai batches, users, and transactions:
```powershell
cd "C:\Users\Mithil Save\Documents\GitHub\LYB\backend"
& ".\.venv\Scripts\python.exe" seed_data.py
```

### 4. Run Automated Backend Test Suite
```powershell
cd "C:\Users\Mithil Save\Documents\GitHub\LYB\backend"
& ".\.venv\Scripts\python.exe" test_api_suite.py
```

### 5. Start the Flutter Mobile Application
In another terminal:
```powershell
cd "C:\Users\Mithil Save\Documents\GitHub\LYB\mobile"
# Run on Windows desktop
& "C:\App Devlopment\flutter\bin\flutter.bat" run -d windows

# Or run on Chrome / Web
& "C:\App Devlopment\flutter\bin\flutter.bat" run -d chrome

# Run full test suite & static analysis
& "C:\App Devlopment\flutter\bin\flutter.bat" test
& "C:\App Devlopment\flutter\bin\flutter.bat" analyze
```

---

## 👥 Demo Personas & Logins

All demo accounts share the password: `reloop123`

| Participant Role | Organisation | Email | What You Can Do in the UI |
|---|---|---|---|
| **Generator** | Godrej Green Towers CHS | `generator@reloop.in` | List waste with Edge-AI scanner, view 6-stage bars, accept collector offers, get 6-digit pickup OTP |
| **Collector** | Dharavi Waste Collectors Society | `collector@reloop.in` | Browse nearby listings, submit offers, weigh & verify handover with OTP, build vehicle consignments |
| **Recycler** | Ecoplas Circular Solutions Ltd | `recycler@reloop.in` | Record gross/tare receipts (`accepted + rejected = received`), log processing runs, calculate yield, allocate output |
| **NGO Auditor** | Green Ledger Foundation India | `ngo@reloop.in` | View unalterable custody chain, verify weighbridge slips, make statutory decisions (`VERIFIED` / `FLAGGED`) |
| **EPR Brand** | Hindustan Consumer Goods Ltd | `epr@reloop.in` | Track Cat-I, Cat-II, Cat-III compliance targets vs verified allocated volume, export CPCB audit dossiers |
| **Admin** | ReLoop Governance Ops | `admin@reloop.in` | Network telemetry, KYB organization approvals, platform anomaly alerts |

*(You can also use the **1-Click Persona Switcher** in the top navigation bar to instantly jump between roles!)*

---

## 🏗️ Architecture & Core Innovations

1. **Six-Stage Quantity Ledger**:
   - `Collected → Received → Accepted → Processed → Verified → Allocated`
   - Explicit kilogram tracking at every handoff with zero premature equivalence.
2. **Database-Level Anti-Double-Counting Safeguards**:
   - Concurrency locking on processing runs.
   - Sum of active allocations cannot exceed measured eligible output (`HTTP 409 ALLOCATION_EXCEEDS_AVAILABLE`).
3. **Structurally Independent NGO Audit**:
   - NGOs review immutable passport snapshots with zero write privileges on operational custody data.
4. **Digital Material Passport**:
   - Every batch has a permanent public QR endpoint (`/b/{batch_code}`) with complete cryptographic lineage from household to pellet output.
5. **Procurement Intelligence**:
   - Greedy feedstock aggregation engine clustering compatible batches without erasing individual identity.
   - Landed-cost optimizer showing costs per *usable* kg.
   - Separation of confirmed vs predicted supply in shortage forecasts.
