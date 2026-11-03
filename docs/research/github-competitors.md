# UnFat: open-source landscape and competitor UX

Research date: 2026-11-03. Star counts, last-push dates and licenses were pulled from the GitHub API on that date (`gh api repos/<owner>/<repo>`). "Last push" means the newest push to any branch. Claims I could not confirm against a primary source are marked **unverified**.

## License legend (read first)

| Tag | Licenses | Can code go into a closed-source App Store app? |
|---|---|---|
| OK | MIT, Apache-2.0, BSD | Yes, if you keep the copyright and license notice (put it in an in-app "Acknowledgements" screen). |
| WEAK | MPL-2.0 | Yes, as long as the MPL-licensed files stay MPL and you publish your changes to those files. |
| **COPYLEFT** | GPL-3.0, AGPL-3.0 | **No.** Copying the code makes UnFat a GPL work, and GPL terms conflict with App Store distribution terms (the reason VLC was pulled in 2011). Read it for ideas only and do not copy or paste. AGPL also covers network use. |
| NONE | No license file, or NOASSERTION | **No.** The default is all rights reserved. Read only. |

Food data sources these apps use: **Open Food Facts** (data under ODbL, so you must attribute it and share back changes to the database itself; the API is free) and **USDA FoodData Central** (CC0, public domain). Both are free for the 0 TL budget.

---

## 1. Open-source calorie and nutrition trackers

| Repo | Stars | Last push | License | Stack | Worth learning or reusing |
|---|---|---|---|---|---|
| [simonoppowa/OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker) | 2,797 | 2026-11-01 | **GPL-3.0** | Flutter | The most mature open tracker. It combines OFF, USDA FDC and the German BLS, and cites its formulas (IOM 2005 kcal, WHO macros). It has one-tap re-log, a micronutrient panel, encrypted local storage, and JSON/CSV export. Use it as a reference for the data model and formulas only. |
| [openfoodfacts/smooth-app](https://github.com/openfoodfacts/smooth-app) | 1,446 | 2026-11-02 | Apache-2.0 | Flutter | The official OFF app. Shows the best-practice barcode flow: scan, show a product card, and fall back to "add missing product" when there is no match. Code is reusable. |
| [davidhealey/waistline](https://github.com/davidhealey/waistline) | 756 | 2026-10-21 | **GPL-3.0** (stated in the README; GitHub detects none) | Cordova + Framework7 | A classic diary and food-list model that merges OFF and USDA search and supports user uploads to OFF. Ideas only. |
| [openfoodfacts/openfoodfacts-dart](https://github.com/openfoodfacts/openfoodfacts-dart) | 230 | 2026-11-02 | Apache-2.0 | Dart SDK | The reference implementation of the OFF API: search, barcode lookup and product upload. |
| [brandonp2412/FitBook](https://github.com/brandonp2412/FitBook) | 177 | 2026-11-02 | MIT | Flutter | Offline-first. Bundles about 7k foods (CORGIS dataset) as a local seed and uses OFF for barcode lookup. A good pattern: ship a local DB so search works instantly without network. |
| [openfoodfacts/openfoodfacts-swift](https://github.com/openfoodfacts/openfoodfacts-swift) | 70 | 2026-09-08 | Apache-2.0 | Swift SDK | The official Swift wrapper for the OFF API. Directly usable if UnFat goes SwiftUI. |
| [femiaf13/manatee-fitness](https://github.com/femiaf13/manatee-fitness) | 48 | 2025-03-13 | **AGPL-3.0** | TypeScript (Tauri, **unverified**) | Ships USDA Foundation Foods preloaded with OFF as a live fallback, plus recipes, Mifflin-St Jeor and macro percentages. Ideas only. |
| [antomanc/simple-calorie-tracker](https://github.com/antomanc/simple-calorie-tracker) | 40 | 2025-01-22 | **GPL-3.0** | React Native | A minimal RN calorie tracker. Ideas only. Low activity. |
| [VaggelisKa/caloryn](https://github.com/VaggelisKa/caloryn) | 3 | 2026-10-31 | Apache-2.0 | SwiftUI + SwiftData + WidgetKit + App Intents | **The closest match to UnFat's native stack**, despite few stars. It has a SwiftData model, CloudKit sync, OFF barcode lookup with serving-size fallback logic, a daily calorie ring, a copy-yesterday flow, home screen widgets fed by an App Group snapshot, and Siri/Shortcuts quick-log. Code is reusable. Code quality has not been reviewed. |
| [SimonVreman/vreetmeter](https://github.com/SimonVreman/vreetmeter) | 5 | 2026-09-26 | MIT | SwiftUI + HealthKit | Writes nutrition to HealthKit and reads body mass to set goals. It also has a strength program log with JSON program templates, so it covers both food and workouts like UnFat. Small, readable, reusable. |
| [Jerryzjx/NutriScan](https://github.com/Jerryzjx/NutriScan) | 22 | 2025-05-27 | Apache-2.0 | Swift / SwiftUI | A barcode-scan-to-log sample. Small and stale, but readable. |
| [rbaumier/kcalz](https://github.com/rbaumier/kcalz) | 3 | 2026-08-20 | MIT | SwiftUI | Offline search. The author says it was "vibe-coded with Claude Code", so treat code quality as unknown. |
| [Appllama/zest-kcal-tracker](https://github.com/Appllama/zest-kcal-tracker) | 20 | 2026-10-06 | MIT | Expo + RN + Skia + `@expo/ui` | A **UI template, not a real tracker**: it has no food recognition and no AI calls. It is the best RN example of native iOS 26 Liquid Glass (`expo-glass-effect`, SwiftUI buttons via `@expo/ui`), progressive blur and Skia animation. |
| [Blueturboguy07/nut-ai](https://github.com/Blueturboguy07/nut-ai) | 56 | 2026-11-02 | **NONE** (NOASSERTION) | TypeScript | An AI photo calorie tracker whose stated rule is "never show a number it cannot..." (the description is truncated). That principle is interesting for UnFat's photo logging. Read only. |
| [ecliptik/onigiri](https://github.com/ecliptik/onigiri) | 5 | 2026-10-26 | **NONE** (NOASSERTION) | Swift | A personal calorie and goal app. Read only. |

Takeaways:
- There is **no popular, permissively licensed SwiftUI calorie tracker.** The big ones are Flutter, and the best (OpenNutriTracker) is GPL. Caloryn (Apache) and vreetmeter (MIT) are small but are the right architecture reference for SwiftUI.
- Every serious open tracker uses the same data strategy: **a bundled local seed DB (USDA/CORGIS) for instant offline search, OFF for barcodes and branded items, and a custom food or "add missing product" fallback.**

## 2. Open-source workout and gym trackers

| Repo | Stars | Last push | License | Stack | Worth learning or reusing |
|---|---|---|---|---|---|
| [Snouzy/workout-cool](https://github.com/Snouzy/workout-cool) | 8,660 | 2026-11-02 | MIT | Next.js (web) | Its exercise database and program builder are the useful parts. It is a web app with no mobile UI to copy. Check the license of the exercise media separately (**unverified**). |
| [wger-project/wger](https://github.com/wger-project/wger) | 7,227 | 2026-11-02 | **AGPL-3.0** | Django | The largest open exercise DB, with routines, nutrition and weight tracking. The **exercise data is CC-BY-SA** (per wger docs, **unverified**), so the data may be usable with attribution even though the code is not. |
| [wger-project/flutter](https://github.com/wger-project/flutter) | 990 | 2026-11-02 | **AGPL-3.0** | Flutter | The mobile client for wger. Ideas only. |
| [astashov/liftosaur](https://github.com/astashov/liftosaur) | 770 | 2026-11-02 | **AGPL-3.0** | TS/Preact PWA in thin native shells | Has a progression DSL ("Liftoscript"), built-in 5/3/1 and GZCLP programs, a plate calculator and weight rounding to your available plates. The **program and progression model** is the thing to study, but write UnFat's own version. |
| [LiamMorrow/LiftLog](https://github.com/LiamMorrow/LiftLog) | 603 | 2026-11-02 | **AGPL-3.0** | Expo / React Native (migrated from .NET MAUI) | **The best Expo reference for a gym logger**: local-first, Material 3 plus Liquid Glass, and E2E-encrypted feeds. Read it to see how Expo handles a production workout UI. Do not copy code. |
| [brandonp2412/Flex](https://github.com/brandonp2412/Flex) | 454 | 2026-11-02 | MIT | Flutter | An offline workout logger with plans, a rest timer and graphs. Reusable logic, and same author as FitBook. |
| [hasaneyldrm/logpress-public](https://github.com/hasaneyldrm/logpress-public) | 291 | 2026-07-16 | MIT | React Native 0.80 + Redux Toolkit + Supabase | A sanitized commercial app. Shows a full RN production setup (onboarding, an Adapty paywall, Lottie, i18n). Reusable. |
| [karthick-mallow/BodyProgress](https://github.com/karthick-mallow/BodyProgress) | 269 | 2022-04-17 | MIT | SwiftUI + Core Data + widgets | Simple SwiftUI workout tracker with a widget. Stale, but a reusable starting point. |
| [karimknaebel/Iron](https://github.com/karimknaebel/Iron) | 235 | 2024-11-17 | **GPL-3.0** | SwiftUI (Xcode 13 era) | The most polished open SwiftUI lifting tracker, with a watch app and App Group. Read it for UI flow only. Pre-SwiftData and stale. |
| [WhyAsh5114/MyFit](https://github.com/WhyAsh5114/MyFit) | 142 | 2026-11-01 | **AGPL-3.0** | SvelteKit PWA | Models RP-hypertrophy-style mesocycles (volume progression). Ideas only. |
| [danielkuhlwein/strength-training](https://github.com/danielkuhlwein/strength-training) | 17 | 2026-07-03 | MIT | SwiftUI | A small, recent native set logger. Reusable. |
| [open-trackers/Gym-Routine-Tracker-Plus-App](https://github.com/open-trackers/Gym-Routine-Tracker-Plus-App) | 8 | 2023-10-14 | MPL-2.0 | SwiftUI (iPhone + Watch) | Minimalist routine model. Usable under MPL file-level terms. Stale. |
| [jadenzaleski/SwiftLift](https://github.com/jadenzaleski/SwiftLift) | 11 | 2025-05-15 | **GPL-3.0** | SwiftUI + SwiftData | Read for its SwiftData schema only. |

Takeaways:
- Every popular workout tracker is **AGPL or GPL** (wger, Liftosaur, LiftLog, Iron). Treat them as product references, not code sources.
- The minimal common data model is `Exercise` → `Routine/Program` → `Workout(session)` → `SetEntry(weight, reps, rpe?, type: warmup/normal/drop/failure, completedAt)`, plus a `progression` rule per exercise (Liftosaur is the most expressive) and a per-exercise `restSeconds` default.

## 3. Live Activities, Dynamic Island and widgets

### Native SwiftUI (ActivityKit and WidgetKit)

| Resource | Stars / last push | License | Notes |
|---|---|---|---|
| Apple sample "Emoji Rangers" ([docs](https://developer.apple.com/documentation/widgetkit/emoji-rangers-supporting-live-activities-interactivity-and-animations)) | Apple | Apple sample license (permissive) | The canonical sample for Live Activities, interactive widgets via App Intents, and widget animations. Start here. |
| [sparrowcode/live-activity-example](https://github.com/sparrowcode/live-activity-example) | 37 / 2024-04-11 | MIT | Covers start, update and end, plus Dynamic Island layouts. Clean and small. |
| [megabitsenmzq/Live-Activity-Background-Update-Demo](https://github.com/megabitsenmzq/Live-Activity-Background-Update-Demo) | 46 / 2024-08-12 | NONE | A trick for updating Live Activities from the background. Read only. Do not rely on it: App Review risk. |
| [batikansosun/iOS-16-Live-Activities-Dynamic-Island](https://github.com/batikansosun/iOS-16-Live-Activities-Dynamic-Island) | 89 / 2022-10-10 | NONE | Old iOS 16 tutorial. Read only. |
| [rgommezz/timer-live-activity](https://github.com/rgommezz/timer-live-activity) | 249 / 2024-03-07 | NONE (no LICENSE file) | An RN plus Swift **timer** Live Activity. The exact rest-timer use case. Read only. |

Key techniques for the workout and rest timer (from Apple docs; well established):
- Use `Text(timerInterval: start...end, countsDown: true)` and `ProgressView(timerInterval:)` in the Live Activity. **The system animates the countdown itself, so the app does not need to push updates every second.** Only push an update on state changes (set completed, rest skipped).
- Use **interactive buttons** (iOS 17+) via `Button(intent:)` with a `LiveActivityIntent`, for actions like "+15 s", "Skip rest" and "Complete set". Hevy ships exactly this.
- Pushing updates while the app is suspended requires APNs ActivityKit push. A local-only, timer-interval design avoids needing a server.
- Widgets and the app share data through an **App Group** (UserDefaults or a SwiftData store in the group container), then call `WidgetCenter.shared.reloadTimelines`.

### React Native / Expo libraries

| Library | Stars | Last push | License | Status | How it works |
|---|---|---|---|---|---|
| [expo-widgets](https://docs.expo.dev/versions/latest/sdk/widgets/) (in [expo/expo](https://github.com/expo/expo)) | part of expo (53k) | active (SDK 58) | MIT | **Official.** The docs give no alpha/beta label. | Widgets and Live Activities written in JSX using `@expo/ui/swift-ui` components, compiled into a separate isolated runtime. **Widget code cannot use hooks, state, async work or imports.** Needs a dev build and a config plugin. Supports push-updated Live Activities. |
| [callstackincubator/voltra](https://github.com/callstackincubator/voltra) | 855 | 2026-10-16 | MIT | Active, Callstack-backed | Turns JSX into SwiftUI for Live Activities and Dynamic Island, and into Glance for Android widgets. Keeps hot reload, supports ActivityKit push tokens, and its config plugin generates the extension target. The **strongest RN option for a "no Swift" workflow.** |
| [EvanBacon/expo-apple-targets](https://github.com/EvanBacon/expo-apple-targets) (`@bacons/apple-targets`) | 1,407 | 2026-11-02 | MIT (in package.json) | Very active (Expo team member) | A config plugin that generates widget, Live Activity, App Clip and other targets. **You write real Swift** under `/targets` and CNG links it in. The most flexible option and it fits CI builds, but the README assumes Xcode for development. Without a Mac, Swift only compiles in CI, so the iteration loop is slow. |
| [bndkt/react-native-widget-extension](https://github.com/bndkt/react-native-widget-extension) | 564 | 2026-05-25 | MIT (in package.json) | Low activity; 0.3.0 beta for Expo 56 | Swift widget and Live Activity code plus an Expo module bridge. Lags Expo SDK releases. |
| [software-mansion-labs/expo-live-activity](https://github.com/software-mansion-labs/expo-live-activity) | 517 | 2026-06-01 | MIT | **Archived and deprecated.** The README says to use expo-widgets instead. | Avoid. |
| [mrevanzak/expo-live-activities-demo](https://github.com/mrevanzak/expo-live-activities-demo) | 64 | 2025-04-23 | NONE | Demo | Read only. |

Verdict for the stack decision: in RN, Live Activities **are feasible** through expo-widgets or Voltra without writing Swift. In native SwiftUI they are first-class and easier to make pixel-perfect. In both cases, the Live Activity UI is SwiftUI under the hood.

## 4. Useful libraries

### Charts

| Library | Stack | Stars / push | License | Notes |
|---|---|---|---|---|
| Swift Charts (Apple) | SwiftUI, iOS 16+ | n/a | Apple SDK | Native, animated, supports accessibility. It is the default for SwiftUI. [jordibruin/Swift-Charts-Examples](https://github.com/jordibruin/Swift-Charts-Examples) (2,449, MIT) is the best catalog. |
| [ChartsOrg/Charts](https://github.com/ChartsOrg/Charts) (DGCharts) | UIKit | 27,973 / 2026-03 | Apache-2.0 | Legacy. Unnecessary with Swift Charts. |
| [FormidableLabs/victory-native-xl](https://github.com/FormidableLabs/victory-native-xl) | RN (Skia + Reanimated) | 1,235 / 2026-10-20 | MIT (in package.json, v5) | Performant, gesture-driven charts on Skia. The best fit for a polished RN UI. |
| [react-native-gifted-charts](https://github.com/Abhinandan-Kushwaha/react-native-gifted-charts) | RN (SVG) | 1,374 / 2026-10-27 | MIT | Easiest to start with, including donut/ring charts. Less fluid than Skia. |

### Barcode scanning

| Option | Stack | Notes |
|---|---|---|
| VisionKit `DataScannerViewController` | Native, iOS 16+ | Apple's live scanner. It draws the highlight UI, supports tap-to-select and handles EAN-13/UPC well. **It needs an A12 or newer chip and does not run on the simulator.** Check `isSupported` and `isAvailable`. It is UIKit-only, so SwiftUI needs a `UIViewControllerRepresentable` wrapper. [Apple docs](https://developer.apple.com/documentation/visionkit/datascannerviewcontroller) |
| AVFoundation `AVCaptureMetadataOutput` | Native | Lower level, so you build the whole UI. Use it if you want a custom, branded scanner look. |
| [twostraws/CodeScanner](https://github.com/twostraws/CodeScanner) | SwiftUI | 1,228 / 2026-04-02 / MIT. A drop-in SwiftUI wrapper over AVFoundation. |
| `expo-camera` (`CameraView` with `barcodeScannerSettings`) | Expo | Built-in scanning. `launchScanner()` uses the system DataScanner on iOS 16+ (per Expo docs, **unverified for current SDK**). |
| [react-native-vision-camera](https://github.com/margelo/react-native-vision-camera) | RN | 9,650 / 2026-11-02 / MIT. Has a code scanner plus frame processors. Use it if photo recognition needs on-device ML frames. |

### Animation

| Library | Stack | Notes |
|---|---|---|
| SwiftUI native (`withAnimation`, `.spring`, `matchedGeometryEffect`, `PhaseAnimator`/`KeyframeAnimator`, `.contentTransition(.numericText())`, `sensoryFeedback`) | SwiftUI | Covers everything UnFat needs, including animated number counters for calories (`numericText`), ring fills and haptics. No dependency. |
| [react-native-reanimated](https://github.com/software-mansion/react-native-reanimated) | RN | 11,045 / 2026-11-02 / MIT. The baseline for 60–120 fps UI-thread animation. |
| [moti](https://github.com/nandorojo/moti) | RN | 4,551 / **2025-03-11** / MIT. A declarative layer over Reanimated. **Last push was about 8 months ago, so maintenance has slowed.** Optional. |
| [react-native-skia](https://github.com/wcandillon/react-native-skia) (Shopify) | RN | 8,766 / 2026-11-02 / MIT. Custom drawing for progress rings, blur and shaders. Used by victory-native-xl and the Zest template. |
| `@expo/ui` (SwiftUI components in RN) | Expo | Real SwiftUI views (Liquid Glass buttons, pickers) inside RN. See zest-kcal-tracker. |

### HealthKit wrappers for RN

| Library | Stars / push | License | Notes |
|---|---|---|---|
| [kingstinct/react-native-healthkit](https://github.com/kingstinct/react-native-healthkit) | 723 / 2026-10-12 | MIT | TypeScript-first, has an Expo config plugin and broad coverage of quantity types and workouts. **The recommended choice.** |
| [agencyenterprise/react-native-health](https://github.com/agencyenterprise/react-native-health) | 1,163 / 2026-04-27 | MIT | Older Objective-C bridge with more stars but less activity. |
| [kilohealth/rn-fitness-tracker](https://github.com/kilohealth/rn-fitness-tracker) | 126 / 2024-05-22 | MIT | Stale. Avoid. |

Native: HealthKit directly (`HKHealthStore`; dietary energy and macros as `HKQuantitySample`, workouts via `HKWorkoutBuilder`). No wrapper needed.

### Photo-based food recognition (note)
No mature, permissive open-source food-recognition model ready for iOS turned up in this search. Open apps (nut-ai, caloriemate, tahaygun/ai-calorie-tracker) all call a cloud LLM vision API. That is **not free at scale** (opsiyonel, ücretli), and per-call cost and privacy matter. A free path would be a Core ML image classifier for food *labels*, with portion size confirmed by the user (**unverified feasibility**).

---

## 5. Competitor UX patterns

| App | What makes logging fast | Standout UI / animation | What users complain about |
|---|---|---|---|
| **MacroFactor** | The company claims the fewest taps of 21 apps on its own "Food Logging Speed Index" ([2025 update](https://macrofactor.com/fastest-food-logger-2025/); self-run, best-case settings). Global search toolbar on every page; + → food → done, auto-timestamped into the current hour. Copy/paste of foods, hours or whole days; "To Today" and "To Tomorrow"; multi-paste. Barcode, **label scanner**, speech-to-text and AI photo logging. Custom numeric keypad with the serving quantity preselected and common servings near the thumb ([timeline article](https://macrofactor.com/timeline-based-food-logger/)). | A **timeline by hour instead of breakfast/lunch/dinner buckets**, with hour-level macro summaries and dense or spacious modes. A week banner of intake vs target. **Targets never turn orange or red** (no shaming). | Price (no free tier), a learning curve, no social features. Recent-update instability is reported by aggregators only (**unverified**) ([aggregator](https://macaron.im/playbook/macrofactor-reviews)). |
| **Hevy** | The routine pre-fills the previous weights and reps. Tapping the check on a set auto-starts the rest timer. | **Live Activity**: the rest timer shows on the Lock Screen and Dynamic Island; ±15 s and skip; **sets can be completed from the Live Activity**; included in the free tier ([Hevy help](https://help.hevyapp.com/hc/en-us/articles/35649846517399)). Social feed, PR badges. | Some users want more automation. Mostly positive; the evidence is thin and comes from aggregators (**unverified**) ([comparison](https://setgraph.app/ai-blog/hevy-vs-strong)). |
| **Strong** | Often called the fastest pure set logger: minimal chrome, previous values shown inline, configurable rest presets per exercise ([repreturn](https://repreturn.com/strong-app-vs-hevy/), affiliate site). | A spreadsheet-like set table and a plate calculator. Very little animation; speed over flair. | The Watch app stops when the phone is out of range, sync and data-loss scares ("Erased all my workout data!" on r/strongapp), slow development, and people moving to Hevy ([unstar](https://unstar.app/blog/strava-strong-fitbod-nike-run-club-peloton-apple-fitness-workout-apps-ranked-2026), [gummysearch](https://gummysearch.com/r/strongapp/)). Pricing has varied by region (**unverified**). |
| **Yazio** | Meal-bucket diary, recents and favorites, barcode. A built-in fasting timer is its signature feature. | Polished, colorful onboarding; the fasting timer ring is praised. | Billing and surprise auto-renewal, unclear subscription terms, database accuracy, and the fasting start time not being editable ([kimola](https://kimola.com/reports/unveil-insights-with-yazio-calorie-counter-diet-feedback-report-app-store-us-147620), [Trustpilot](https://www.trustpilot.com/review/yazio.com?page=7)). |
| **MyFitnessPal** | The largest database (user-submitted), recents and meal copy. | Dated, ad-heavy UI. | **The barcode scanner was moved behind Premium (announced in 2022)** ([Slashdot/Verge](https://news.slashdot.org/story/22/08/25/1955238/myfitnesspal-paywalls-barcode-scanner-that-made-counting-calories-easy)); ads interrupt logging; duplicate and incorrect user entries. One vendor analysis says 27 of 202 negative reviews named the scanner paywall ([unstar](https://unstar.app/blog/is-myfitnesspal-premium-worth-it-paywall-app-reviews-2026); methodology **unverified**). |
| **Cal AI** | Photo → AI estimate of calories and macros in one shot. The ads sell this "snap and done" speed. | A minimal result card with a big number, plus a streaks and progress home screen. | **Accuracy**: it misses oil and sauces, struggles with mixed dishes and bowls, and gets portion sizes wrong. Users report hard paywalls and trial billing complaints ([kimola](https://kimola.com/reports/unveil-user-insights-on-cal-ai-calorie-tracker-app-store-us-155190), [eesel](https://www.eesel.ai/en/blog/cal-ai-pricing)). Independent tests of photo apps find large errors ([HealthDay](https://www.healthday.com/health-news/nutrition/how-accurate-are-photo-based-calorie-apps-4-are-put-to-the-test)). |
| **Lose It** | Simple diary, barcode, and "Snap It" photo logging. | A friendly, gamified budget metaphor ("calorie budget"). | User-submitted database errors and duplicates; Snap It identifies about 55% of foods (a figure attributed to CNET, **unverified**); hard cancellation ([calorie-trackers.com](https://calorie-trackers.com/reviews/lose-it/), [kimola](https://kimola.com/reports/dive-into-lose-it-app-reviews-a-comprehensive-analysis-app-store-fi-145724)). |
| **Apple Fitness** | Zero setup: Activity rings fill automatically. iOS 26 adds a custom workout builder on iPhone ([MacStories](https://www.macstories.net/stories/watchos-26-the-macstories-review/3/)). | The **rings** are the visual benchmark: a satisfying ring-close animation and haptic, and award badges. Workout Buddy voice coaching. | No set/rep strength logging. Workout Buddy is unreliable for strength workouts in early reviews ([TechRadar](https://www.techradar.com/health-fitness/i-tried-watchos-26s-workout-buddy-but-had-to-turn-it-off-heres-why)). No nutrition at all, which is the gap UnFat fills. |

Note on sources: most review-complaint material comes from review aggregators (kimola, unstar, macaron) and competitor blogs (Nutrola). These are directionally consistent but biased. Primary App Store and Reddit threads were not read directly.

---

## Patterns to copy

1. **Pre-filled sets and auto rest timer** (Hevy, Strong): show the previous session's weight×reps as the placeholder, and tap the check to log and start rest.
2. **Interactive Live Activity for rest** (Hevy): countdown via `Text(timerInterval:)`, ±15 s, skip, complete set, plus a compact Dynamic Island view. No server push needed.
3. **Global quick-add** (MacroFactor): search is reachable from every screen, auto-timestamped, with recents and favorites on top and a **copy yesterday / copy meal** action.
4. **A custom numeric keypad** with the serving preselected and common servings as chips (MacroFactor).
5. **Barcode first, then local DB, then custom food fallback**, with a bundled offline seed DB for instant search (FitBook, Manatee, OpenNutriTracker).
6. **AI photo as an editable draft, not a verdict**: show the detected items and grams as editable rows, and ask about oil and sauce. The nut-ai principle: never show a number the model cannot justify.
7. **Non-judgmental colors** (MacroFactor): no red when over target. A neutral accent fits UnFat's single-accent Apple style.
8. **Ring and number animations** (Apple Fitness): ring fill on log, `numericText` counter roll, a light haptic on success.
9. **Free barcode scanning**: competitors' paywalls on basics are the top complaint, so keep the scanner free.
10. **App Group snapshot → widget** (Caloryn): the widget reads a small precomputed struct (kcal left, macros) instead of querying the DB.

## Pitfalls to avoid

1. **Copying GPL/AGPL code** (OpenNutriTracker, Waistline, wger, Liftosaur, LiftLog, Iron, MyFit, SwiftLift). This is not allowed in a closed App Store build. Repos with no license (nut-ai, onigiri, timer-live-activity, the Live Activity demos) are also read-only.
2. **Trusting user-submitted food data blindly** (MFP, Lose It, Yazio complaints). Prefer USDA and OFF, and flag unverified entries.
3. **Overpromising photo accuracy** (Cal AI, Snap It). Users notice hidden calories. Keep the user in the loop on portions.
4. **Dark-pattern billing** (Yazio, Cal AI, Lose It): surprise trial conversions and hard cancellation lead to 1-star reviews.
5. **Fragile Watch and sync** (Strong): data-loss scares destroy trust. Local-first storage with export is safer.
6. **Ads inside the logging flow** (MFP).
7. **Meal buckets as the only model**: they slow down logging for people who eat irregularly (MacroFactor's reason for the timeline).
8. **RN-specific**: expo-live-activity is archived (do not adopt it). expo-widgets widget code cannot use hooks or state. Moti's maintenance has slowed. react-native-widget-extension lags Expo SDK releases.
9. **No-Mac specific**: with expo-apple-targets or native Swift you cannot preview widgets or Live Activities locally. Every UI tweak costs a CI build plus a TestFlight round-trip. JSX-based options (expo-widgets, Voltra) let you iterate faster, but still need a dev build on a device.
10. **DataScannerViewController** fails silently on unsupported devices or the simulator. Always check `isSupported` and fall back to AVFoundation or CodeScanner.
