# ReLoop Flutter app (`mobile_v2`)

The ReLoop web app rebuilt in Flutter. It has the same six roles, the same screens and the same rules, and runs on Android, iOS, Windows, macOS, Linux and the web. Every screen reads and writes the FastAPI backend in `../backend`; there is no mock or demo data in the app.

`../mobile` is the team's earlier Flutter prototype (demo data). It is left untouched.

| Role | Layout on phones | Layout on desktop/tablet (≥1024px) |
|---|---|---|
| Generator, Collector, Recycler | Bottom tabs + "More" drawer | Sidebar |
| NGO auditor, EPR company, Platform admin | Top bar + drawer | Sidebar |

## Run it (Windows)

You need the Flutter SDK (stable channel, 3.29 or newer) and the ReLoop backend running.

1. **Start the backend.** In PowerShell window 1:
   ```powershell
   cd ReLoop\backend
   .\.venv\Scripts\Activate.ps1
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```
   `--host 0.0.0.0` lets a phone or emulator reach your PC. Run `python seed_data.py` first if `reloop.db` doesn't exist yet.

2. **Get the packages.** In PowerShell window 2:
   ```powershell
   cd ReLoop\mobile_v2
   flutter pub get
   ```

3. **Run it on one of these:**

   | Target | Command | Server address the app uses |
   |---|---|---|
   | Android emulator | `flutter run` with the emulator open | `http://10.0.2.2:8000` (automatic) |
   | Chrome | `flutter run -d chrome` | `http://localhost:8000` (automatic) |
   | Windows desktop | `flutter run -d windows` (needs Visual Studio with "Desktop development with C++") | `http://localhost:8000` (automatic) |
   | Real Android phone on the same Wi-Fi | `flutter run` with the phone connected by USB | Your PC's IPv4 from `ipconfig`, e.g. `http://192.168.1.20:8000` |

   To change the server address, tap **"API: …"** at the bottom of the sign-in screen. Or set it at build time with `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000`.

   Windows Firewall may block port 8000 for a real phone. Allow Python through the firewall when Windows asks.

4. **Sign in.** Debug builds list the seeded accounts; tap one to fill it in. Every account uses the password `reloop123`: `generator@`, `collector@`, `recycler@`, `ngo@`, `epr@` and `admin@reloop.in`.

## AI polymer detection

On **Create listing**, the generator taps **Detect from photo**. The photo is:
- registered as a listing document (its SHA-256 is recorded), and
- sent to `POST /api/v1/ai/classify`.

The app then shows the predicted polymer, its confidence and the top three classes.
- **High confidence:** the material field is pre-filled, and the generator can still change it.
- **Low confidence** (below `RELOOP_POLYMER_MIN_CONFIDENCE`, default 0.6): nothing is pre-filled and the generator chooses the material.

The prediction id is sent with the listing, and the backend records the material the generator finally chose against the prediction. That gives your team labelled feedback for retraining.

**Connecting your model** happens in `backend/app/modules/ai/classifier.py`:
1. In the notebook, save the trained model to a file, for example `model.save("polymer_model.keras")`, `torch.save(...)` or `joblib.dump(...)`.
2. Paste the notebook's loading code into `load_model()`.
3. Paste its preprocessing and prediction code into `predict()`. Use the same image size, normalisation and class order as in training.
4. Map your class labels to ReLoop material codes in `LABEL_TO_MATERIAL`.
5. Install the framework into the backend virtualenv, for example `pip install tensorflow pillow`.
6. Start the backend with the model path set:
   ```powershell
   $env:RELOOP_POLYMER_MODEL = "C:\path\to\polymer_model.keras"
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

The badge on the detection panel then shows **Model connected**. Until a model is connected, the endpoint answers 503 `AI_MODEL_NOT_CONFIGURED` and the app says that detection is not connected. The old placeholder that always answered "PET 92%" has been removed, so the app never shows a made-up prediction.

## Rules the app holds to (same as the web app)

- **Each of the six quantity stages comes from its own field** (`lib/core/quantities.dart`):
  - processing input comes from `/batches/{id}/trace`;
  - `quantities.processed_kg` is shown as **recovered output (pro rata)**;
  - NGO-verified kg is shown only when the current decision is VERIFIED **and** output has been measured.
- **Validation runs in the app first, and the backend still decides.** This covers:
  - accepted + rejected = received;
  - input ≤ available stock;
  - output + residue ≤ input;
  - eligible ≤ output;
  - the ±20% weigh-in note and the scale photo.
- **Server refusals keep their own figures.** A refusal (409/422) is shown with the server's numbers and is **never retried with a changed quantity**. For example, `ALLOCATION_EXCEEDS_AVAILABLE` shows declared eligible, allocated and available kg.
- **Labels stay inside the facts.**
  - NGO verification is labelled independent and non-statutory.
  - Certificate references are labelled as generated on the CPCB portal, not by ReLoop.
  - EPR targets are labelled self-declared.
- **Every save refreshes every screen that shows the same record.** Pull down on any screen to reload it from the backend.

### Differences from the web app

| Web app | Flutter app |
|---|---|
| CSV files download in the browser | **Export CSV** opens the CSV text with a **Copy to clipboard** button, because file saving differs on every platform |
| Charts drawn with Recharts | Same charts drawn with plain widgets. Tap a bar to read its value |
| Data tables | Tables on wide screens; one card per row on phones, with the same search, filters, sorting and paging |
| Dialogs and side drawers | Dialogs on wide screens; bottom sheets on phones |

## Tests

```powershell
flutter analyze
flutter test
```

On Flutter 3.47 and newer, `flutter analyze` also lists `package:flutter/material.dart` as deprecated, because Material is moving to its own package. Those notices are expected; the app builds and runs normally.

- `test/quantities_test.dart`, `errors_test.dart`, `format_test.dart`, `roles_test.dart`, `routes_test.dart` test the quantity mapping, the error envelope, formats and validation, role mapping and route coverage.
- `test/screens_smoke_test.dart` opens **every screen for every role** (plus the passport and an NGO case) at 390px and 1400px wide, and the home screen in dark mode. It uses real API responses recorded from the seeded backend (`test/fixtures/api.json`), and it fails on any exception or layout error. To regenerate the fixtures after backend changes:
  ```powershell
  cd ..\backend
  python seed_data.py
  python ..\mobile_v2\tool\dump_fixtures.py ..\mobile_v2\test\fixtures\api.json
  ```

## Code layout

```
lib/
  core/      api.dart (only HTTP client, single-flight token refresh), errors.dart, json.dart,
             auth.dart, query.dart (cached queries + invalidation), quantities.dart, format.dart,
             roles.dart (navigation per role), nav.dart
  ui/        theme.dart (design tokens, light/dark), widgets.dart, data_list.dart, charts.dart, states.dart
  features/  passport.dart (passport, quantity ladder, timeline, QR, tabs), photos.dart, ai_detect.dart
  shell/     app_shell.dart (sidebar, top bar, bottom tabs, drawer, backend-status banner)
  pages/     generator, collector, recycler, ngo, epr, admin, shared (login, profile, passport)
  app.dart   routes (/g/listings, /passport/CODE, … same paths as the web app)
```

## Backend gaps still visible in the app

These are the same gaps as in the web app, and each affected screen says so where it applies:

- File storage is a stub, so only SHA-256 hashes of photos are recorded.
- EPR allocation requests are not stored.
- NGO and EPR PDF reports are stubs.
- Document requests are batch events only.
- `/forecasts/shortages` substitutes placeholder figures.
- The cost endpoints use fixed rates.
- There are no collector-earnings records.
- Aggregation plans have no collector.
- No list endpoint has pagination.
- The handover OTP is returned only once, so it is shown only on the device that recorded the weight.
