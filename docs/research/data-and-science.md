# UnFat: data sources, science and photo recognition

Research date: 2026-11-03. Scope: personal iOS app (calorie/macro + workout tracking), user in Turkey, zero budget, on-device + iCloud, no own backend preferred.
Claims I could not confirm from a primary source are marked **(unverified)**. Prices are USD.

---

## 0. Recommendations at a glance

| Need | Recommendation | Cost |
|---|---|---|
| Barcode lookup | Open Food Facts API v3 (live, per scan) + local cache of every looked-up product | Free (ODbL attribution) |
| Generic food search (incl. Turkish dishes) | Bundled, hand-curated Turkish dish table (per-100 g + typical portion) built from recipes x USDA ingredient values; USDA SR Legacy/Foundation for raw ingredients | Free (CC0) |
| Offline starter set | Ship SQLite with: ~300-600 curated TR dishes/basics + USDA Foundation/SR Legacy subset + OFF Turkey subset (~6k products) | Free |
| Exercises | wger data (CC-BY-SA, 900+ exercises, per-image licenses) or free-exercise-db (Unlicense, 800+) for text; translate names to TR yourself | Free |
| Photo recognition | LLM vision (Gemini Flash-Lite) through Firebase AI Logic + App Check (no own backend, key not in app), restricted to TR storefront if using the free tier; fallback: user-brings-own-key | Free tier; paid ~0.03-0.1 cents/photo |
| TDEE | Mifflin-St Jeor x activity factor at start, then adaptive TDEE from EMA-smoothed weight + logged intake | n/a |

---

## 1. Food databases

### 1.1 Open Food Facts (OFF): primary source for barcodes

| Item | Detail |
|---|---|
| Product by barcode | `GET https://world.openfoodfacts.org/api/v3/product/{barcode}.json` (v3 current; v2 `/api/v2/product/{barcode}` deprecated but supported). Use `?fields=code,product_name,product_name_tr,brands,nutriments,serving_size,image_front_small_url` to keep responses small. |
| Search | `GET /api/v2/search` (structured filters, e.g. `countries_tags_en=turkey`), legacy `/cgi/search.pl`. Full-text: Search-a-licious (`search.openfoodfacts.org`). |
| Rate limits (per IP) | Product reads: **15 req/min**. Search: **10 req/min**, explicitly "do not use for search-as-you-type". Exceeding can get the IP banned. Since calls come from users' phones, limits are effectively per user. Global limits return HTTP 503. |
| Auth | Reads: none. Writes (adding products/photos): login session or `user_id`+`password` on POST; Keycloak/OAuth migration underway. |
| User-Agent | Required custom UA: `AppName/Version (ContactEmail)`, e.g. `UnFat/1.0 (contact@example.com)`. Use a project email, not a personal university one. |
| Staging | `https://world.openfoodfacts.net`, basic auth `off:off`. Use for write tests. |
| Usage rule | "Each API call should correspond to one real user scan"; scraping via API gets blocked. Fill in the API usage form before launch. |
| Data dumps | Nightly: MongoDB dump, JSONL (gz), Parquet (Hugging Face, simplified), CSV (food file ~0.9 GB gz / 9 GB raw), daily 14-day delta files. |
| Turkish coverage | `countries_tags_en=turkey` returned **6,078 products** on 2026-11-03 (live query). Global DB ~4.5M products **(unverified, third-party figure)**. Expect gaps for local brands (Ülker, Eti, Pınar etc. are present but incomplete; **unverified spot check not done**). |
| Data quality | User-contributed, "no guarantee of accuracy". Typical issues: missing nutriments, per-serving vs per-100 g mix-ups, kJ/kcal swaps, missing Turkish names. Validate: kcal ≈ 4P + 4C + 9F (+2 fiber, +7 alcohol) within ~15-20%; reject entries outside. |

**License obligations (ODbL database, DbCL contents, images CC BY-SA 3.0):**
- Attribution: show "Food data from Open Food Facts, available under the ODbL" with links to openfoodfacts.org and the ODbL, prominently (e.g. on the product detail screen and in Settings > Credits).
- Share-alike: if you publicly use an *adapted database* (e.g. ship a cleaned OFF subset inside the app), that derived DB must be offered under ODbL. Practical approach: keep OFF-derived rows in a separate table/file, and publish your cleaned subset (e.g. on GitHub) under ODbL. Your own curated TR dish table and app code stay yours as long as they are not derived from OFF.
- No DRM-style lock-in on redistributed OFF data unless an unrestricted copy is also offered.
- Images: CC BY-SA, may contain third-party trademarks; showing the product front thumbnail is common practice, keep attribution.
- Recommended: let users add missing products and send them back to OFF (needs an OFF account per user or an app account; can be a later feature).

Sources: [OFF API docs](https://openfoodfacts.github.io/openfoodfacts-server/api/), [OFF data/licence page](https://world.openfoodfacts.org/data), [ODbL](https://opendatacommons.org/licenses/odbl/).

### 1.2 USDA FoodData Central (FDC): raw ingredients, fully free

| Item | Detail |
|---|---|
| API key | Free data.gov key; required per request. Keys found posted publicly get deactivated, so **do not embed in the app**; instead use the bulk download offline. |
| Limits | 1,000 req/hour/IP default; `DEMO_KEY` 30/h, 50/day. Higher on request. |
| License | Public domain, **CC0 1.0**. USDA asks for credit ("U.S. Department of Agriculture, FoodData Central") and optionally notification. |
| Data types | Foundation Foods (best quality, small), SR Legacy (~7.8k foods, final April 2018 release, no updates), FNDDS (survey, mixed dishes, US-centric), Branded (US barcodes, useless for TR). |
| Bulk | CSV/JSON. Foundation (Dec 2025) ~3.4 MB zip / 29 MB raw; SR Legacy ~6.7 MB zip / 54 MB raw **(size read from a garbled table, verify)**. |

Use: bundle a trimmed SR Legacy + Foundation subset (macros + fiber + a few micros) as the raw-ingredient base, and to compute Turkish dish values from recipes.
Sources: [FDC API guide](https://fdc.nal.usda.gov/api-guide/), [FDC downloads](https://fdc.nal.usda.gov/download-datasets), [FDC about/licence](https://fdc.nal.usda.gov/about-us.html).

### 1.3 Turkish food composition sources

| Source | Content | License / usability in an app |
|---|---|---|
| **TürKomp** (turkomp.tarimorman.gov.tr; Ministry of Agriculture + Ministry of Health + TÜBİTAK) | ~645 foods, 14 food groups, ~100 components, ~63k data points. Mostly ingredients/basic foods measured by lab analysis, plus 53 traditional foods (production techniques documented). Not a dish/recipe DB. | **No open license found.** App listing shows "© Türkomp"; a TÜBİTAK document lists "data set selling" as a sustainability model. Free to browse, **not cleared for bundling**. Action: email TAGEM / Gıda ve Yem Kontrol Merkez Araştırma Enstitüsü asking for permission for a free non-commercial app. Until then, use only as a manual cross-check, do not copy the table. Site was unreachable from here (ECONNRESET) on 2026-11-03. |
| **BeBiS** (Beslenme Bilgi Sistemi) | Professional dietitian software with thousands of foods incl. Turkish dishes; used in universities. | Commercial, closed, no API; price not published. **Not usable.** |
| Ministry of Health "Türkiye Beslenme Rehberi (TÜBER 2022)" | Dietary guidelines, portion sizes, energy targets for TR population. | Government publication; use as a reference for portion sizes and guidance text, not as a DB **(license not checked, unverified)**. |
| Turkish brand websites / package labels | Per-product nutrition | Facts are not copyrightable per se, but scraping sites is a ToS risk. Better: users scan and contribute to OFF. |

**Practical path for Turkish dishes** (mercimek çorbası, pilav, kuru fasulye, karnıyarık, menemen, lahmacun, simit, ayran...):
1. Write a curated list (~300-600 items) of common dishes with a standard recipe (ingredients in grams, yield).
2. Compute per-100 g values from USDA ingredient data (CC0), apply cooking yield/water loss factors.
3. Add typical portions in Turkish units: "1 kase (250 g)", "1 porsiyon pilav (150 g)", "1 adet simit (~100-120 g)", "1 su bardağı ayran (200 ml)".
4. Cross-check ranges manually against TürKomp/published tables (checking against them is fine; copying is the licensing issue).
5. Store as your own data file; you own it (no ODbL contamination as long as you don't derive from OFF).

### 1.4 Commercial APIs (all optional)

| API | Free tier | Turkey | Notes |
|---|---|---|---|
| **FatSecret Platform** | Basic: free, **5,000 calls/day**, **US dataset only, English only**, attribution required. Premier Free: free for verified startups/non-profits/students, unlimited calls, still US-only, attribution required. | Localized data (62+ countries, 26 languages) only in **Premier (paid, price on request)**; Turkey not confirmed in the list **(unverified)**. | Needs OAuth2 client credentials = a secret, so needs a proxy. Not useful for TR without paid Premier. |
| **Edamam Food Database** | Historic free developer tier (~10 req/min, limited monthly) **(unverified, old figures)**; paid plans historically $99-799/mo **(unverified)**. | Weak TR coverage **(unverified)** | Requires attribution badge; caching restrictions in ToS **(unverified)**. |
| **Nutritionix** | Free tier reportedly still exists with low limits **(unverified)**; enterprise ~$1,850+/mo per third-party listing **(unverified)**. | US-focused | Strong NLP ("2 eggs and toast"), US only. |
| **Spoonacular, CalorieNinjas** etc. | Small free quotas | US-centric | Not worth it for TR. |

**Verdict:** skip commercial food APIs. OFF + own TR table + USDA covers the zero-budget case better for Turkey.

### 1.5 Recommended food data architecture

```
Search order (local first, all offline-capable):
  1. user's own foods & recent/favorites (SwiftData/Core Data, synced via CloudKit)
  2. bundled curated TR dishes (own data)
  3. bundled USDA subset (CC0), Turkish display names added by you for common items
  4. bundled OFF Turkey subset (ODbL, separate table) + cache of scanned products
Barcode scan:
  local cache -> OFF API v3 (1 call per real scan) -> "add product" form (optionally contribute to OFF)
```
- Turkish-aware search: normalize diacritics (ç/c, ğ/g, ı/i, İ/i, ö/o, ş/s, ü/u) with `tr_TR` locale case folding; SQLite FTS5 with a custom folded column.
- OFF Turkey subset: build with DuckDB from the JSONL/Parquet dump on your PC (filter `countries_tags` contains `en:turkey` and nutriments present); refresh with each app release. ~6k rows, a few MB.

---

## 2. Exercise databases

| Dataset | License | Count | Media | Muscles / fields | Turkish |
|---|---|---|---|---|---|
| **wger** (wger.de, `/api/v2/`) | Code AGPL-3.0 (irrelevant if you only use data). Exercise data **CC-BY-SA**; each image has its own license field (CC-BY-SA 3/4, CC-BY 4, CC0) plus author fields. | **904 exercises** (API, 2026-11-03), **383 images** | PNG/JPG photos and drawings, some SVG muscle diagrams; per-image attribution needed | 15 muscles (with front/back flag and muscle images), equipment, category, variations | Turkish is a supported language, but only **31 exercises** translated (API count). |
| **free-exercise-db** (yuhonas, GitHub) | **Unlicense** (public domain dedication) | 800+ (873) | JPG, 2 frames per exercise | primaryMuscles, secondaryMuscles, equipment, level, force, mechanic, category, instructions | None |
| **ExerciseDB** (exercisedb.dev / RapidAPI) | Code AGPL-3.0; data/GIF terms in a separate ToS not reviewed **(unverified)** | V1 open: 1,300-1,500; commercial: 11k+ exercises, 5k+ GIFs | Animated GIFs (the main draw) | bodyParts, targetMuscles, secondaryMuscles, equipments | None |

Notes and risks:
- free-exercise-db images: the repo says Unlicense but provenance of the photos is not documented (upstream `wrkout/exercises.json` also Unlicense, sources not stated). The photos resemble a well-known commercial fitness site's library **(unverified)**. Treat image copyright as a risk for an App Store release; text fields are low risk.
- ExerciseDB GIFs: commercial product; do not bundle GIFs without a license.
- wger CC-BY-SA: if you bundle and modify their exercise text, your modified exercise DB must stay CC-BY-SA and attribute wger. Images: show author/license per image (the API exposes `license`, `license_author`).

**Recommendation:** Build your own exercise table (~150-250 common gym exercises) with English + Turkish names written by you, mapped to a fixed muscle enum (chest, front/side/rear delts, triceps, biceps, forearms, lats, upper back/traps, lower back, abs, obliques, glutes, quads, hamstrings, adductors, calves) and equipment enum. Seed names/muscles from free-exercise-db (Unlicense, text only). Images: none at first (or SF Symbols-style muscle-map highlighting drawn by you), optionally wger CC0/CC-BY images with attribution. Turkish names are your own work (e.g. "Bench Press" = "Bench Press / Göğüs pres", "Squat" = "Squat / Çömelme", "Lat Pulldown" = "Lat çekiş"); Turkish gym slang mostly uses English names, so show both.

Sources: [free-exercise-db](https://github.com/yuhonas/free-exercise-db), [wrkout/exercises.json](https://github.com/wrkout/exercises.json), [wger docs](https://wger.readthedocs.io/en/latest/), wger API (`https://wger.de/api/v2/language/`, `/exercise/`, `/exerciseimage/`, `/license/`), [ExerciseDB repo](https://github.com/ExerciseDB/exercisedb-api).

---

## 3. Science and formulas

### 3.1 BMR / RMR

| Formula | Equation | When |
|---|---|---|
| **Mifflin-St Jeor** (1990) | Men: `BMR = 10*W + 6.25*H - 5*A + 5` ; Women: `BMR = 10*W + 6.25*H - 5*A - 161` (W kg, H cm, A years) | Default. Best-validated predictive equation for non-obese and obese adults (ADA evidence review, Frankenfield 2005). |
| **Katch-McArdle** | `BMR = 370 + 21.6 * LBM`, `LBM = W * (1 - BF%)` | When the user knows body fat % (lean/athletic users). |
| Cunningham (option) | `RMR = 500 + 22 * LBM` | Athletes; gives higher values. |

Sources: Mifflin et al., Am J Clin Nutr 1990;51:241-7 ([PubMed](https://pubmed.ncbi.nlm.nih.gov/2305711/)); Frankenfield et al., J Am Diet Assoc 2005 ([PubMed](https://pubmed.ncbi.nlm.nih.gov/15883556/)).

### 3.2 TDEE activity multipliers (standard, approximate)

| Level | Description | Factor |
|---|---|---|
| Sedentary | desk job, little exercise | 1.2 |
| Lightly active | light exercise 1-3 d/week | 1.375 |
| Moderately active | 3-5 d/week | 1.55 |
| Very active | 6-7 d/week hard | 1.725 |
| Extremely active | physical job + training | 1.9 |

`TDEE_initial = BMR * factor`. These are rough (error easily ±10-20%), which is why the adaptive estimate below matters. Tip: do **not** also add logged workout calories on top of a multiplier that already includes exercise (double counting). Pick one model: either multiplier includes exercise, or use 1.2-1.375 base + logged workout kcal.

### 3.3 Adaptive TDEE (MacroFactor-style, in principle)

MacroFactor publicly describes: deterministic algorithm; daily weights smoothed into a trend with more weight on recent values; expenditure = logged intake adjusted by the energy equivalent of trend weight change; starts from an equation estimate, moves after ~1 week, stabilizes after ~14-30 days; targets recalculated weekly; during logging gaps, the last high-confidence estimate is carried forward. It does not publish its constants. A reasonable open implementation:

1. **Trend weight (EMA)**, Hacker's Diet style:
   `T_t = T_(t-1) + α * (W_t - T_(t-1))`, α ≈ 0.1 (≈ 10-day smoothing). Missing day: carry `T` forward (or interpolate weights linearly before smoothing).
2. **Energy balance over a window** of N days (N = 14-28):
   `TDEE_obs = mean(intake over window) - (T_end - T_start) * ρ / N`
   ρ = energy density of tissue change. Classic value 7,700 kcal/kg (3,500 kcal/lb). It overstates reality for small/early changes (water, glycogen), so many implementations use ~7,000-7,700; Hall's dynamic model gives a lower effective value early in a diet ([Hall 2008](https://pubmed.ncbi.nlm.nih.gov/17848938/), [Hall et al. Lancet 2011](https://pubmed.ncbi.nlm.nih.gov/21872751/)). Recommend ρ = 7,700 and accept the bias; it is consistent and self-correcting over weeks.
3. **Blend with prior** (Bayesian-ish shrinkage, keeps it stable):
   `TDEE_est = TDEE_prev + k * (TDEE_obs - TDEE_prev)`, k ≈ 0.1-0.25 per weekly update; increase confidence (k) with more logged days; skip/down-weight weeks where < ~70-80% of days have complete food logs.
4. **Clamp**: limit weekly change of the estimate (e.g. ±100-150 kcal/week) and keep within e.g. `[0.8, 1.6] * BMR*1.2` bounds to absorb logging errors.
5. **Target**: `kcal_target = TDEE_est + goal_rate_kg_per_week * ρ / 7` (negative rate = deficit).

Caveats to display: water weight (creatine, sodium, menstrual cycle) distorts 1-2 weeks; underlogging makes TDEE look low, so the algorithm effectively calibrates to the user's logging habits (which is actually useful).
Sources: [MacroFactor algorithms & philosophy](https://macrofactor.com/macrofactors-algorithms-and-core-philosophy/), [MacroFactor expenditure help](https://help.macrofactorapp.com/dashboard/expenditure), [The Hacker's Diet (Walker), trend chapter](https://www.fourmilab.ch/hackdiet/).

### 3.4 Macro recommendations

| Macro | Recommendation | Source |
|---|---|---|
| Protein, general active adult | 1.4-2.0 g/kg/day | ISSN position stand, Jäger et al. 2017 ([JISSN](https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8)) |
| Protein, muscle gain with resistance training | ~1.6 g/kg/day (benefit plateau), up to 2.2 g/kg upper CI | Morton et al. 2018 meta-analysis, BJSM ([PubMed](https://pubmed.ncbi.nlm.nih.gov/28698222/)) |
| Protein, lean trainee in a deficit | 2.3-3.1 g/kg **of fat-free mass** | Helms et al. 2014 ([PubMed](https://pubmed.ncbi.nlm.nih.gov/24092765/)) |
| Protein, RDA minimum | 0.8 g/kg/day | IOM DRI |
| Fat | 20-35 % of kcal (AMDR); practical floor ~0.5-0.6 g/kg | IOM DRI 2005 |
| Carbs | Remainder of kcal; AMDR 45-65 % of kcal; RDA floor 130 g/day | IOM DRI 2005 |
| Fiber | ~14 g per 1,000 kcal (≈25 g women, ≈38 g men) | IOM DRI; TÜBER also gives ~25-30 g **(unverified exact TR figure)** |

Default app logic: protein 1.6-2.2 g/kg (use goal weight or LBM for users with high BMI, otherwise protein targets become huge), fat 25-30 % kcal, carbs = rest.

### 3.5 Safe deficit / surplus rates

| Goal | Rate | Source |
|---|---|---|
| Fat loss | 0.5-1.0 % body weight/week (lean trainees: lower end to preserve muscle) | Helms et al. 2014 |
| General weight loss guideline | 0.5-1 kg/week (≈ 500-1,000 kcal/day deficit) | NIH/NHLBI obesity guidelines **(classic guidance, not re-checked)** |
| Lean bulk | ~0.25-0.5 % BW/month for intermediates (≈ +200-300 kcal/day) | common coaching practice **(unverified, no single primary source)** |

**Minimum intake guard:** warn (do not block) below ~1,200 kcal/day for women and ~1,500 kcal/day for men without medical supervision (NIH/NHLBI guidance level), and never set a target below BMR without an explicit warning. Clamp the goal rate to ≤ 1 % BW/week.

### 3.6 MET-based workout calories (Compendium of Physical Activities)

Formula: `kcal = MET * 3.5 * W_kg / 200 * minutes` (equivalently `kcal ≈ MET * W_kg * hours`, the second form slightly higher).
Net (to avoid double counting resting burn already in TDEE): use `(MET - 1)`.
1 MET = 3.5 mL O2/kg/min. 2024 Adult Compendium: 1,114 activities, adults 19-59 (separate older-adult compendium); [pacompendium.com](https://pacompendium.com/) ([Herrmann et al. 2024, JSHS](https://pubmed.ncbi.nlm.nih.gov/38242596/)).

| Code | Activity | MET |
|---|---|---|
| 02054 | Resistance training, multiple exercises, 8-15 reps, varied resistance | 3.5 |
| 02052 | Squats/deadlifts, slow or explosive | 5.0 |
| 02050 | Free weight/machine/powerlifting/bodybuilding, vigorous | 6.0 |
| 02034 / 02035 | Circuit training light / moderate | 3.5 / 5.0 |
| 02040 | Circuit incl. kettlebells, vigorous | 7.5 |
| 02210 / 02214 | HIIT moderate / vigorous (burpees, Tabata) | 7.0 / 11.0 |
| 02048 / 02049 | Elliptical moderate / vigorous | 5.0 / 9.0 |
| 02071 / 02070 | Rowing ergometer <100 W / general vigorous | 5.0 / 7.3 |
| 02101 | Stretching, mild | 2.3 |
| 02175 | Yoga, general | 2.3 |
| - | Walking ~5.6 km/h (3.5 mph), level | ~4.3 **(2011 value, unverified for 2024)** |
| - | Running ~9.7 km/h (6 mph) | ~9.3-9.8 **(unverified)** |
| - | Stationary cycling, moderate | ~6.8-7.0 **(unverified)** |

Values from the [pacompendium conditioning-exercise page](https://pacompendium.com/conditioning-exercise/). The Compendium is published research; reusing individual MET numbers in an app is standard practice (facts with citation). Better still: read active energy from HealthKit (Apple Watch) when available, and use MET only as a fallback. For strength training, a duration-based MET (3.5-6.0) is all the science supports; per-set/tonnage-based calorie estimates are not validated.

### 3.7 1RM estimation

| Formula | Equation (w = weight, r = reps) | Note |
|---|---|---|
| **Epley** | `1RM = w * (1 + r/30)` | Common default; slightly high at low reps. For r = 1 return w. |
| **Brzycki** | `1RM = w * 36 / (37 - r)` | Good for r ≤ 10; breaks down as r → 37. |
| Lombardi | `1RM = w * r^0.10` | |
| O'Conner | `1RM = w * (1 + 0.025 * r)` | |
| Inverse (load for target reps), Epley | `w = 1RM / (1 + r/30)` | Use for "suggest weight for 8 reps". |
| With RIR | Use `r_eff = r + RIR` in the formula | |

All are accurate within a few % only for ≤ 10 reps; cap input at 12 reps and display "estimated". Sources: Epley 1985 (Boyd Epley Workout), Brzycki 1993 JOPERD; review: LeSuer et al. 1997 JSCR ([PubMed](https://pubmed.ncbi.nlm.nih.gov/9466469/)) **(citations from memory, links not opened)**.

### 3.8 Program structures (for the data model)

**Generic model:** Program -> Weeks/Cycle -> Days -> Exercise slots -> Set schemes (sets x reps @ load rule) + Progression rule (on success / on failure) + Deload rule. Load rules: fixed weight, % of 1RM, % of Training Max, RPE/RIR target, "AMRAP last set".

| Program | Structure | Progression rule |
|---|---|---|
| **Linear progression (e.g. Starting Strength / StrongLifts 5x5)** | 3 d/week, A/B alternating, compound lifts 3x5 or 5x5 | +2.5 kg upper / +5 kg lower each successful session; after 3 failures deload 10 %. |
| **PPL (Push/Pull/Legs)** | 3 or 6 d/week: Push (chest, shoulders, triceps), Pull (back, biceps, rear delts), Legs. Typical 3-4 sets of 6-12 reps. | Double progression: hit top of rep range on all sets -> increase load (+2.5 kg), reset to bottom of range. |
| **Upper/Lower** | 4 d/week U/L/-/U/L | Double progression or % based. |
| **5/3/1 (Wendler)** | 4 main lifts (squat, bench, deadlift, OHP), 1 per day, 4-week cycle. TM = 90 % of 1RM. Week 1: 65/75/85 % x 5/5/5+; Week 2: 70/80/90 % x 3/3/3+; Week 3: 75/85/95 % x 5/3/1+; Week 4 deload: 40/50/60 % x 5. "+" = AMRAP. Plus assistance (e.g. Boring But Big 5x10 @ 50-60 % TM). | Each cycle TM +2.5 kg (upper) / +5 kg (lower). If AMRAP fails the minimum, reduce TM 10 %. |
| **GZCLP** | 4 days, each day: T1 (heavy compound), T2 (secondary compound), T3 (accessory). T1: 5x3+ (last set AMRAP) ~85 % ; T2: 3x10 ; T3: 3x15+ (last AMRAP). | T1 add weight each session; on failure 5x3 -> 6x2 -> 10x1 -> then retest 5RM, set new base at 85 %. T2 3x10 -> 3x8 -> 3x6 -> reset with +weight. T3 add weight when last set hits 25 reps. |

Sources: Wendler, *5/3/1* (2nd ed.) **(details from memory)**; [GZCLP reference (r/Fitness wiki / Cody LeFever)](https://thefitness.wiki/routines/gzclp/) **(link not opened)**.

---

## 4. Photo food recognition

### 4.1 Options

| Option | Cost | Quality for TR food | Notes |
|---|---|---|---|
| Apple Vision `VNClassifyImageRequest` | Free, on-device | Low: generic taxonomy (~1,300 labels incl. some food words) **(unverified count)**, no portion size | Useful only as "is this food?" pre-check or rough label. |
| Core ML Food-101 classifier (e.g. MobileNetV2/EfficientNet fine-tunes) | Free, on-device | 101 Western-ish classes (has baklava, hummus, falafel; no mercimek çorbası, pilav, lahmacun). Reported accuracy ~82 % (MobileNetV2) to ~96 % (EfficientNetV2-S) top-1 on Food-101 **(model cards, not verified)** | Food-101 images come from foodspotting.com, research use; model licenses often "other" -> **commercial/App Store use unclear**. Gives a label only, user still enters portion. Training a TR-specific model = big data-collection project. |
| **LLM vision (Gemini / Claude / OpenAI)** | Fractions of a cent per photo (below) | Best: recognizes Turkish dishes and estimates portions; can return JSON (items, grams, kcal, P/C/F) | Portion/kcal estimates are rough (often ±20-40 % **(unverified, depends on study)**). Always show as editable draft, then match items to your local DB. |
| Dedicated APIs: LogMeal, Passio Nutrition-AI, Calorie Mama | No public prices; "depends on project"/sales contact | Varies | Not zero-budget. Passio has an iOS SDK with on-device models; pricing by contract **(unverified)**. |

### 4.2 LLM vision pricing (official pages, 2026-11-03)

| Model | Input / 1M tok | Output / 1M tok | Free tier | Est. cost per photo* |
|---|---|---|---|---|
| Gemini 3.1 Flash-Lite | $0.25 | $1.50 | Yes | ~$0.0007 |
| Gemini 3.5 Flash-Lite | $0.30 | $2.50 | Yes | ~$0.001 |
| Gemini 3.8 Flash | $0.75 (-> $1.50 from 2027-01-01) | $3.75 (-> $7.50) | Yes | ~$0.002-0.004 |
| Claude Haiku 5.5 (≤100k prompt) | $0.10 | $0.50 | No | ~$0.0003 |
| Claude Haiku 4.5 | $1.00 | $5.00 | No | ~$0.003 |
| OpenAI gpt-5-nano | $0.05 | $0.40 | No | ~$0.0002 (vision support not confirmed on the pricing page) |
| OpenAI gpt-4o-mini | $0.15 | $0.60 | No | image tokens billed at an inflated rate for this model **(unverified)** |

*Assumes ~1,000-1,500 input tokens for a ~1 MP photo + prompt and ~300 output tokens. Claude image tokens ≈ `width*height/750`; resize to ≤ ~1,000 px long edge before upload. Gemini tokens per image not stated on the pricing page **(unverified; historically 258 tokens per tile)**. Even at paid rates, 10 photos/day for one user = **< $0.30/month**.

Sources: [Gemini pricing](https://aistudio.google.com/docs/pricing), [Gemini rate limits](https://aistudio.google.com/docs/rate-limits), [Claude pricing](https://platform.claude.com/docs/en/about-claude/pricing), [OpenAI pricing](https://developers.openai.com/api/docs/pricing).

### 4.3 Gemini free tier: terms that matter

- Free-tier content **is used to improve Google products; human reviewers may read inputs/outputs**. Terms: "Do not submit sensitive, confidential, or personal information to the Unpaid Services". Food photos are generally fine; warn users not to include faces/documents.
- **If the app is available to users in the EEA, UK or Switzerland, only Paid Services may be used.** So: free tier = restrict App Store availability to Turkey (and other non-EEA countries), or switch to paid (tiny cost) / BYO key for those regions.
- Users must be **18+**; app must not be aimed at or likely used by minors -> set App Store age rating accordingly or gate the AI feature.
- No clinical use / medical advice -> wording: "estimate", not "diagnosis".
- Free-tier rate limits are per project (not per key) and are currently shown only in the AI Studio dashboard; third-party 2026 figures range from ~100 to 1,500 requests/day for Flash-Lite **(unverified)**. Fine for one personal user, a risk if the app gets many users on one shared project.
- Source: [Gemini API Additional Terms](https://aistudio.google.com/docs/terms).

### 4.4 Key handling without a backend

| Approach | Key exposure | Cost | Verdict |
|---|---|---|---|
| Embed raw API key in the app | Extractable from the IPA in minutes; abuse burns quota/bill | - | **Never.** |
| **Firebase AI Logic** (Swift SDK) + **App Check (App Attest)** | Gemini key stays in Firebase's proxy; App Check lets only genuine app installs call it; per-user rate limits configurable | Works on free **Spark** plan with Gemini Developer API free tier (no billing account) | **Recommended.** Zero own backend, zero cost. Firebase project config (GoogleService-Info.plist) is not a secret. |
| Cloudflare Worker proxy (free plan) | Key in Worker secret; but without App Attest verification anyone can call your Worker URL | Free: 100k req/day, 10 ms CPU/request (waiting on fetch does not count as CPU), 50 subrequests | Good fallback; add App Attest verification or a per-device token + rate limit (KV/Durable Objects) to be safe. Needed if using Claude/OpenAI. |
| **Bring your own key** (user pastes their own Gemini/Claude key, stored in Keychain) | Only the user's own key, on their own device | User's own free tier/bill | Good as an "advanced" option; zero risk for you. Not friendly for non-technical users. |

**Recommended flow:** photo -> resize to ~1,000 px, strip EXIF/GPS -> explicit consent screen (App Store 5.1.2(i): disclose that the photo is sent to Google's AI) -> Gemini Flash-Lite via Firebase AI Logic with a JSON schema response (`items[{name_tr, name_en, grams, kcal, protein, carbs, fat, confidence}]`) -> fuzzy-match each item to the local DB (prefer DB values over LLM kcal) -> user edits portions -> log.

---

## 5. App Store review rules relevant to a calorie/workout app (brief)

| Guideline | What it means for UnFat |
|---|---|
| **1.4.1** Medical | Health-related accuracy claims must disclose data and methodology; apps "should remind users to check with a doctor". Do not call TDEE/photo kcal "accurate"; show "estimate" and a methodology page (formulas above + data sources). |
| **1.4 / 1.4.5** Physical harm | Avoid encouraging extreme deficits; add minimum-calorie warnings and a goal-rate clamp (section 3.5). |
| **1.1.6** False information | Inaccurate data presented as fact can be a rejection reason; label AI estimates clearly. |
| **2.5.1** HealthKit | Use HealthKit only for health/fitness and integrate with the Health app (write nutrition, weight, workouts; read weight, active energy). |
| **5.1.1** Privacy | Privacy policy link in App Store Connect **and** in-app; explain deletion. If accounts exist, in-app account deletion. |
| **5.1.2(i)** Third-party AI | Must disclose sharing personal data with third-party AI and get **explicit permission** first (photo feature consent screen). |
| **5.1.3(i)** Health data | Health/fitness data must not be used for ads/marketing/data mining; disclose which health data you collect. |
| **5.1.3(ii)** | "Must not write false or inaccurate data into HealthKit ... and **may not store personal health information in iCloud**." **Risk for the iCloud plan:** this is usually read as applying to HealthKit-derived data. Safe design: do not sync HealthKit-read data to iCloud/CloudKit (re-read it from HealthKit on each device); sync only user-entered logs (foods, workouts, own weight entries). Whether user-entered weight/food logs count as "personal health information" is not stated **(unverified interpretation; common calorie apps do use CloudKit)**. |
| **3.1.1** | Any paid unlock must use IAP (relevant only if monetized later). |
| **4.2** | Minimum functionality: fine for a real tracker. |

Recommended disclaimer text (onboarding + settings): "UnFat provides estimates for general fitness purposes and is not medical advice. Consult a doctor before starting a diet or exercise program, especially if you are pregnant, under 18, or have a medical condition."

Source: [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

---

## 6. Open questions for the orchestrator/user

1. TürKomp licensing: send a permission email? (Free, but slow; the app works without it.)
2. Photo recognition: Firebase AI Logic (Google account + Firebase project) vs. BYO key only. The free-tier route implies limiting availability to non-EEA storefronts and an 18+ rating.
3. iCloud + 5.1.3(ii): confirm the design choice of not syncing HealthKit-sourced data.
4. Exercise images: ship without images in v1, or accept wger images with attribution?
