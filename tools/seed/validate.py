"""Validate UnFat seed JSON files. Exits non-zero on any failure.

    python tools/seed/validate.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SEED_DIR = ROOT / "ios" / "UnFat" / "Resources" / "seed"

FOOD_CATEGORIES = {"soup", "main", "side", "salad", "breakfast", "bread", "dessert", "drink",
                   "fruit", "vegetable", "dairy", "meat", "legume", "grain", "snack", "fastfood",
                   "sauce"}
SERVING_LABELS = {"kase", "kepçe", "porsiyon", "dilim", "adet", "bardak", "yemek kaşığı",
                  "tatlı kaşığı", "avuç", "tabak", "su bardağı",
                  # additions beyond the brief's list (drinks)
                  "çay bardağı", "fincan", "kadeh", "kutu", "şişe"}
MUSCLES = {"chest", "back", "shoulders", "biceps", "triceps", "forearms", "quads", "hamstrings",
           "glutes", "calves", "core", "fullBody", "cardio"}
EQUIPMENT = {"barbell", "dumbbell", "machine", "cable", "bodyweight", "kettlebell", "band", "other"}
KINDS = {"strength", "cardio"}

# Foods whose kcal legitimately exceeds 4P+4C+9F (energy from alcohol, ~7 kcal/g).
KCAL_EXCEPTIONS = {
    "Bira": "alcohol",
    "Kırmızı şarap": "alcohol",
    "Rakı": "alcohol",
    # FDC kcal uses food-specific Atwater factors; organic acids and low-energy
    # carbohydrate make these come out well below the general 4/4/9 estimate.
    "Limon": "specific Atwater factors (citric acid)",
    "Limon suyu": "specific Atwater factors (citric acid)",
    "Mantar": "specific Atwater factors (mushroom protein/carbs 2.62/3.48)",
    # Vinegar energy comes from acetic acid, which is not a 4/4/9 macro.
    "Sirke": "acetic acid energy",
}

FOOD_KEYS = {"id", "name", "aliases", "category", "per100g", "servings", "source"}
PER100_KEYS = {"kcal", "protein", "carbs", "fat", "fiber"}
EX_KEYS = {"id", "nameTr", "nameEn", "primaryMuscle", "secondaryMuscles", "equipment", "kind", "met"}


def one_decimal(x) -> bool:
    return isinstance(x, (int, float)) and not isinstance(x, bool) and abs(round(x, 1) - x) < 1e-9


def check_foods(errors: list[str]) -> int:
    data = json.loads((SEED_DIR / "foods_tr.json").read_text(encoding="utf-8"))
    if set(data) != {"version", "foods"} or data["version"] != 1:
        errors.append("foods: top level must be {version: 1, foods: [...]}")
    ids, names = set(), set()
    for f in data["foods"]:
        tag = f"food {f.get('id')}"
        if set(f) != FOOD_KEYS:
            errors.append(f"{tag}: keys {sorted(f)}")
            continue
        if not re.fullmatch(r"tr-\d{4}", f["id"]):
            errors.append(f"{tag}: bad id format")
        if f["id"] in ids:
            errors.append(f"{tag}: duplicate id")
        ids.add(f["id"])
        if not isinstance(f["name"], str) or not f["name"].strip():
            errors.append(f"{tag}: empty name")
        if f["name"] in names:
            errors.append(f"{tag}: duplicate name {f['name']}")
        names.add(f["name"])
        if not all(isinstance(a, str) and a.strip() for a in f["aliases"]):
            errors.append(f"{tag}: bad alias")
        if f["category"] not in FOOD_CATEGORIES:
            errors.append(f"{tag}: category {f['category']}")
        if not f["source"].strip():
            errors.append(f"{tag}: empty source")
        p = f["per100g"]
        if set(p) != PER100_KEYS:
            errors.append(f"{tag}: per100g keys {sorted(p)}")
            continue
        if not isinstance(p["kcal"], int) or isinstance(p["kcal"], bool) or p["kcal"] < 0:
            errors.append(f"{tag}: kcal must be a non-negative integer")
        for m in ("protein", "carbs", "fat", "fiber"):
            if not one_decimal(p[m]) or p[m] < 0 or p[m] > 100:
                errors.append(f"{tag}: {m}={p[m]} must be 0..100 with 1 decimal")
        if p["fiber"] > p["carbs"] + 0.05:
            errors.append(f"{tag}: fiber > carbs (carbs are by difference and include fiber)")
        if p["protein"] + p["carbs"] + p["fat"] > 100.5:
            errors.append(f"{tag}: macros exceed 100 g per 100 g")
        est = 4 * p["protein"] + 4 * p["carbs"] + 9 * p["fat"]
        if f["name"] not in KCAL_EXCEPTIONS:
            kcal = p["kcal"]
            if kcal < 20 and est < 20:
                ok = abs(kcal - est) <= 5
            else:
                # Fiber yields ~2 kcal/g instead of 4, so allow a lower bound with fiber credit.
                low = 0.85 * (est - 2 * p["fiber"])
                ok = low <= kcal <= 1.15 * est
            if not ok:
                errors.append(f"{tag} {f['name']}: kcal {kcal} vs 4P+4C+9F {est:.0f}")
        if not f["servings"]:
            errors.append(f"{tag}: no servings")
        for s in f["servings"]:
            if set(s) != {"label", "grams"}:
                errors.append(f"{tag}: serving keys {sorted(s)}")
                continue
            if s["label"] not in SERVING_LABELS:
                errors.append(f"{tag}: serving label '{s['label']}'")
            if s["label"] != s["label"].lower():
                errors.append(f"{tag}: serving label not lowercase")
            if not isinstance(s["grams"], (int, float)) or s["grams"] <= 0:
                errors.append(f"{tag}: serving grams must be > 0")
    return len(data["foods"])


def check_exercises(errors: list[str]) -> int:
    data = json.loads((SEED_DIR / "exercises.json").read_text(encoding="utf-8"))
    if set(data) != {"version", "exercises"} or data["version"] != 1:
        errors.append("exercises: top level must be {version: 1, exercises: [...]}")
    ids, names = set(), set()
    for e in data["exercises"]:
        tag = f"exercise {e.get('id')}"
        if set(e) != EX_KEYS:
            errors.append(f"{tag}: keys {sorted(e)}")
            continue
        if not re.fullmatch(r"ex-\d{4}", e["id"]):
            errors.append(f"{tag}: bad id format")
        if e["id"] in ids:
            errors.append(f"{tag}: duplicate id")
        ids.add(e["id"])
        for k in ("nameTr", "nameEn"):
            if not isinstance(e[k], str) or not e[k].strip():
                errors.append(f"{tag}: empty {k}")
        if e["nameTr"].lower() in names:
            errors.append(f"{tag}: duplicate nameTr {e['nameTr']}")
        names.add(e["nameTr"].lower())
        if e["primaryMuscle"] not in MUSCLES:
            errors.append(f"{tag}: primaryMuscle {e['primaryMuscle']}")
        if any(m not in MUSCLES for m in e["secondaryMuscles"]):
            errors.append(f"{tag}: secondaryMuscles {e['secondaryMuscles']}")
        if e["primaryMuscle"] in e["secondaryMuscles"]:
            errors.append(f"{tag}: primary repeated in secondary")
        if e["equipment"] not in EQUIPMENT:
            errors.append(f"{tag}: equipment {e['equipment']}")
        if e["kind"] not in KINDS:
            errors.append(f"{tag}: kind {e['kind']}")
        if (e["kind"] == "cardio") != (e["primaryMuscle"] == "cardio"):
            errors.append(f"{tag}: cardio kind and cardio muscle must go together")
        met = e["met"]
        if not isinstance(met, (int, float)) or isinstance(met, bool) or not 1 <= met <= 20:
            errors.append(f"{tag}: met {met} outside 1..20")
    return len(data["exercises"])


def main() -> int:
    errors: list[str] = []
    nf = check_foods(errors)
    ne = check_exercises(errors)
    for e in errors:
        print("FAIL", e)
    print(f"checked {nf} foods, {ne} exercises; kcal exceptions: {len(KCAL_EXCEPTIONS)}; "
          f"errors: {len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
