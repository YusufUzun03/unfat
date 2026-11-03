# UnFat — Plan

Spec: `docs/SPEC.md`. Status legend: `[ ]` todo, `[~]` in progress, `[x]` accepted. Tiers: light / medium / careful / heavy / fable (savvy-flow).
Every UI task is verified with the CI screenshots job (loop D) plus a device check by Yusuf; a worker's "done" does not close a design task.

## M0 — Accounts (Yusuf, web, no Mac needed)
- [ ] **U1 Portal setup.** Create App IDs (`io.github.yusufuzun03.unfat` with App Groups, HealthKit, iCloud/CloudKit, Push; `.widgets` with App Groups), App Group, iCloud container, App Store Connect record (same bundle ID), public GitHub repo `unfat` with the four ASC secrets reused from couch-remote. Checklist: `docs/research/ios-stack.md` §7.1.
- [ ] **U2 Firebase.** Free Spark project, iOS app with the bundle ID, enable Firebase AI Logic (Gemini Developer API) and App Check (App Attest); store `GoogleService-Info.plist` base64 as secret `FIREBASE_PLIST`. Needed only before task 9.

## M1 — Foundation
- [x] **1 Scaffold + CI** · careful · after U1. XcodeGen `ios/project.yml` with app, widget extension, `Shared/`, `UnFatCore` local package, entitlements, App Group, String Catalog (tr), empty 4-tab shell. `.github/workflows/ios.yml`: push → simulator build + tests; dispatch `compile | device-ipa | testflight | screenshots`; ad hoc signed archive + entitlement check step (ios-stack.md §7.3). Verify: CI green, TestFlight build launches on the iPhone, `codesign` check shows HealthKit/App Group/iCloud entitlements, screenshots job uploads a PNG. — Status 2026-11-03: CI green, tests run; archive/TestFlight check waits for U1.
- [~] **2 Data layer** · careful · after 1. SwiftData models per SPEC "Data model", synced + local configurations in the App Group, sync opt-in switch, `SeedLoader` (JSON → in-memory index with Turkish-aware, diacritic-insensitive search), `WidgetSnapshotWriter`, fixture data for screenshots. Verify: unit tests for model creation, snapshot entries, search ranking; CI green.
- [~] **3 Core logic** · medium · after 1 (parallel with 2, 4, 5). `UnFatCore`: BMR, TDEE, targets, floors, EMA trend, adaptive TDEE, MET kcal, e1RM, PR detection, unit conversion. Formulas: `data-and-science.md` §3. Verify: package tests covering every formula with hand-computed cases.
- [~] **4 Seed data** · medium · after 1 (parallel). `foods_tr.json` (≥300 Turkish dishes + staples; per-100 g values derived from USDA FDC ingredients, Turkish serving units like kase/kepçe/dilim/adet, source note per item) and `exercises.json` (~200, TR + EN names, muscle, equipment, MET; text from free-exercise-db, no images). Plus a generator script and a validation test (schema, kcal ≈ 4P + 4C + 9F ± 15 %). Verify: validation test green; orchestrator spot-checks 20 items.
- [~] **5 Design system + debug tools** · medium · after 1 (parallel). Tokens and components from SPEC "Design decisions": calorie ring, macro bar, number roll, keypad, serving chips, rest timer view, list rows; tab bar with search-role "Ekle" tab; DEBUG gallery, tuning panel, `-UNFAT_SCREEN` router. Verify: screenshots of gallery in light and dark.

## M2 — Food
- [ ] **6 Onboarding + goals** · medium · after 2, 3, 5. Flow per SPEC; editable targets; floor warnings; settings goal editor reuses it. Verify: screenshots of each step; unit test of the profile → targets path.
- [ ] **7 Today + food logging** · careful · after 2, 4, 5, 6. Today dashboard and timeline, add sheet (recents, favorites, search, entry editor + keypad, custom food, quick kcal, copy yesterday), edit/delete entries, haptics and number/ring animations. Verify: screenshots of Today (empty, partial, over target), add sheet, editor; device check.
- [ ] **8 Barcode + Open Food Facts** · medium · after 7. DataScanner with `isSupported` fallback to AVFoundation, OFF v3 client (User-Agent, timeout, cache in `CachedProduct`), product card, "not found" → custom food prefilled with barcode. Verify: unit tests with recorded OFF JSON (found, partial nutrients, not found); device scan of 3 Turkish products.
- [ ] **9 Photo recognition** · careful · after 7, U2. Consent screen, camera/photo picker, Firebase AI Logic call with JSON schema output, editable draft rows + oil/sauce question, failure/offline states, settings toggle. Verify: unit tests for response parsing/validation; device test with 3 meals.
- [ ] **10 Widgets** · medium · after 2, 7. Small, medium and `accessoryCircular` widgets from `WidgetSnapshot`; reload after each change; date rollover. Verify: views in debug gallery screenshots; device check on Home and Lock Screen.

## M3 — Workout
- [ ] **11 Programs + active session** · careful · after 2, 4, 5. Program templates (Full body, Upper/Lower, PPL), program editor, exercise picker (seed + custom), active session with prefill from last session, set check → in-app rest timer, finish summary (duration, volume, kcal, PRs), history. Verify: unit tests for prefill and summary math; screenshots; device run of a short session.
- [ ] **12 Live Activity** · heavy · after 11. `WorkoutActivityAttributes`, Lock Screen + Dynamic Island views per mockup, `LiveActivityIntent`s (+15 s, skip, set done), local rest-end notification, stale/end handling, app-killed recovery. Verify: views in gallery screenshots; device test with the app suspended and killed.
- [ ] **13 HealthKit** · medium · after 2, 11. Permissions flow, read body mass/steps/active energy into local-only cache, write `HKWorkout` with energy, Today shows steps/active kcal. Verify: device check in the Health app; unit tests around mapping.

## M4 — Progress and release
- [ ] **14 Progress** · medium · after 3, 7, 11. Weight entry, trend chart, weekly intake vs target, adaptive TDEE card with accept-suggestion, per-exercise e1RM chart, PR list. Charts follow the dataviz rules. Verify: screenshots with fixture data (30/90 days).
- [ ] **15 Settings + App Store prep** · medium · after all. Sync toggle, units, Health and notification status, about, acknowledgements (ODbL, Firebase), disclaimer + methodology, privacy policy page (GitHub Pages), `PrivacyInfo.xcprivacy`, App Store metadata draft (tr), screenshots from loop D. Verify: checklist in SPEC "App Store requirements" ticked; TestFlight build reviewed on device.

## Order
U1 → 1 → (2 ∥ 3 ∥ 4 ∥ 5) → 6 → 7 → (8 ∥ 10 ∥ 11) → (9 ∥ 12 ∥ 13) → 14 → 15
