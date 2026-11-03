# Seed data

Generates the bundled databases the app ships with:

| Output | Content |
|---|---|
| `ios/UnFat/Resources/seed/foods_tr.json` | 414 Turkish dishes and staples, per 100 g + Turkish servings |
| `ios/UnFat/Resources/seed/exercises.json` | 196 gym exercises + 28 cardio activities with MET |

## Regenerate

```sh
python -B -I tools/seed/generate.py   # writes both JSON files and id_lock.json
python -B -I tools/seed/validate.py   # exits 1 on any failure
```

The output is deterministic: same inputs give byte-identical files (UTF-8, 2-space
indent, `ensure_ascii=False`, sorted by id). No network is needed: everything
generate.py reads is committed.

Only when the FDC ingredient list changes:

```sh
python -B -I tools/seed/extract_fdc.py   # downloads the SR Legacy CSV zip into cache/ once
```

`fedb_subset.json` holds just the free-exercise-db entries in use. When
`cache/fedb/exercises.json` exists (download `dist/exercises.json` from
yuhonas/free-exercise-db), generate.py refreshes the subset from it; otherwise it
uses the committed subset. `cache/` is gitignored.

## Files

| File | Role |
|---|---|
| `fdc_ingredients.py` | ingredient key -> USDA FDC id (SR Legacy) |
| `extract_fdc.py` | pulls kcal / protein / carbs / fat / fiber per 100 g into `fdc_ingredients.json` |
| `foods_recipes.py` | recipe table: ingredient grams per batch + cooked yield factor, serving sizes, aliases |
| `exercises_table.py` | exercise selection, Turkish names, MET values |
| `generate.py` | builds both seed files |
| `validate.py` | schema, enums, unique ids, kcal vs 4P+4C+9F (+/-15 %, fiber credit), servings > 0, MET 1-20 |
| `id_lock.json` | name -> id map. Ids never change once assigned; a renamed food gets a new id |

## Method

- Each dish is UnFat's own composition of common Turkish home cooking:
  `per100g = sum(ingredient nutrients) / (raw batch mass x yield) x 100`.
  Water is an ingredient; for boiled pasta / rice / legumes only the absorbed water
  counts, and fried items count only the oil they keep. kcal is the sum of the FDC
  energy values, not 4/4/9.
- Staples map to one FDC item. Turkish products without an FDC match use a
  documented approximation (kaşar = gouda, beyaz peynir = feta, sucuk = smoked beef
  sausage, rakı = 90 proof spirit, ...). The note is in each item's `source`.
- No TürKomp or other Turkish nutrient tables are used.
- Known limitation: grilled fatty meats do not subtract fat lost as drippings, so
  their values lean high.

### kcal check exceptions (validate.py)

| Food | Why kcal is outside 4P+4C+9F +/-15 % |
|---|---|
| Bira, Kırmızı şarap, Rakı | energy from alcohol |
| Limon, Limon suyu, Mantar | FDC uses food-specific Atwater factors |
| Sirke | energy from acetic acid |

### MET (2024 Adult Compendium of Physical Activities)

Isolation / machine 3.5, calisthenics 3.8, big compound lifts 5.0, Olympic lifts and
kettlebell ballistics 6.0, cardio per activity (e.g. treadmill run 9.7 km/h 9.8,
rowing machine 7.3, yoga 2.3).

## Sources and licenses

- **USDA FoodData Central**, SR Legacy (April 2018). Public domain (CC0).
  Credit: U.S. Department of Agriculture, Agricultural Research Service.
  FoodData Central. https://fdc.nal.usda.gov/
- **free-exercise-db** (github.com/yuhonas/free-exercise-db). Unlicense (public
  domain). Exercise names, muscles and equipment only; no images or instructions.
- **2024 Adult Compendium of Physical Activities** (Herrmann et al.), MET values
  cited as published reference values.
