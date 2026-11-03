"""Generate UnFat seed data deterministically.

    python tools/seed/generate.py

Inputs (all committed):
  fdc_ingredients.json  per-100 g USDA FDC values (built by extract_fdc.py)
  foods_recipes.py      recipe table (own compositions)
  exercises_table.py    exercise selection + Turkish names + MET
  fedb_subset.json      the free-exercise-db entries used by exercises_table.py
                        (refreshed automatically when cache/fedb/exercises.json exists)
  id_lock.json          name -> stable id map; new entries get the next free id

Outputs:
  ios/UnFat/Resources/seed/foods_tr.json
  ios/UnFat/Resources/seed/exercises.json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))

import exercises_table  # noqa: E402
import foods_recipes  # noqa: E402

SEED_DIR = ROOT / "ios" / "UnFat" / "Resources" / "seed"
FDC_JSON = HERE / "fdc_ingredients.json"
FEDB_CACHE = HERE / "cache" / "fedb" / "exercises.json"
FEDB_SUBSET = HERE / "fedb_subset.json"
ID_LOCK = HERE / "id_lock.json"

MACROS = ("kcal", "protein", "carbs", "fat", "fiber")

MUSCLE_MAP = {
    "abdominals": "core", "abductors": "glutes", "adductors": "quads", "biceps": "biceps",
    "calves": "calves", "chest": "chest", "forearms": "forearms", "glutes": "glutes",
    "hamstrings": "hamstrings", "lats": "back", "lower back": "back", "middle back": "back",
    "neck": "shoulders", "quadriceps": "quads", "shoulders": "shoulders", "traps": "back",
    "triceps": "triceps",
}
EQUIPMENT_MAP = {
    "barbell": "barbell", "e-z curl bar": "barbell", "dumbbell": "dumbbell", "machine": "machine",
    "cable": "cable", "body only": "bodyweight", None: "bodyweight", "kettlebells": "kettlebell",
    "bands": "band",
}


def dump(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


# ---------------------------------------------------------------- foods
def parse_pairs(spec: str) -> list[tuple[str, float]]:
    out = []
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        label, grams = part.rsplit(" ", 1)
        out.append((label.strip(), float(grams)))
    return out


class FoodBuilder:
    def __init__(self, ingredients: dict):
        self.ing = ingredients
        self.bases = {b.key: b for b in foods_recipes.BASES}
        self.base_cache: dict[str, dict[str, float]] = {}

    def per100(self, key: str) -> dict[str, float]:
        if key.startswith("@"):
            name = key[1:]
            if name not in self.base_cache:
                b = self.bases[name]
                self.base_cache[name] = self.compose(b.ingredients, b.yield_)
            return self.base_cache[name]
        if key not in self.ing:
            raise KeyError(f"unknown ingredient '{key}'")
        return {m: self.ing[key][m] for m in MACROS}

    def compose(self, spec: str, yield_: float) -> dict[str, float]:
        totals = dict.fromkeys(MACROS, 0.0)
        mass = 0.0
        for key, grams in parse_pairs(spec):
            v = self.per100(key)
            for m in MACROS:
                totals[m] += v[m] * grams / 100.0
            mass += grams
        cooked = mass * yield_
        return {m: totals[m] / cooked * 100.0 for m in MACROS}

    def fdc_ids(self, key: str) -> list[int]:
        if key.startswith("@"):
            ids: list[int] = []
            for k, _ in parse_pairs(self.bases[key[1:]].ingredients):
                for i in self.fdc_ids(k):
                    if i not in ids:
                        ids.append(i)
            return ids
        return [self.ing[key]["fdcId"]]

    def source(self, r) -> str:
        pairs = parse_pairs(r.ingredients)
        if len(pairs) == 1 and not pairs[0][0].startswith("@") and r.yield_ == 1.0:
            key = pairs[0][0]
            s = f"USDA FDC SR Legacy {self.ing[key]['fdcId']}: {self.ing[key]['description']}"
        else:
            parts = []
            for key, grams in pairs:
                g = f"{grams:g} g"
                if key.startswith("@"):
                    ids = ", ".join(str(i) for i in self.fdc_ids(key))
                    parts.append(f"{key[1:]} base {g} [{ids}]")
                else:
                    parts.append(f"{key} {g} [{self.ing[key]['fdcId']}]")
            s = (f"USDA FDC SR Legacy derived, UnFat recipe (cooked yield {r.yield_:g}): "
                 + "; ".join(parts))
        if r.note:
            s += f". Note: {r.note}"
        return s


def lock_ids(lock: dict[str, str], names: list[str], prefix: str) -> dict[str, str]:
    used = [int(v.split("-")[1]) for v in lock.values() if v.startswith(prefix + "-")]
    nxt = max(used, default=0) + 1
    for n in names:
        if n not in lock:
            lock[n] = f"{prefix}-{nxt:04d}"
            nxt += 1
    return lock


def build_foods(lock: dict) -> list[dict]:
    ing = json.loads(FDC_JSON.read_text(encoding="utf-8"))["ingredients"]
    fb = FoodBuilder(ing)
    names = [r.name for r in foods_recipes.RECIPES]
    dupes = {n for n in names if names.count(n) > 1}
    if dupes:
        raise SystemExit(f"duplicate food names: {sorted(dupes)}")
    lock_ids(lock.setdefault("foods", {}), names, "tr")
    foods = []
    for r in foods_recipes.RECIPES:
        v = fb.compose(r.ingredients, r.yield_)
        servings = []
        for label, grams in parse_pairs(r.servings):
            servings.append({"label": label, "grams": int(grams) if grams == int(grams) else grams})
        foods.append({
            "id": lock["foods"][r.name],
            "name": r.name,
            "aliases": [a for a in r.aliases if a.lower() != r.name.lower()],
            "category": r.category,
            "per100g": {
                "kcal": int(round(v["kcal"])),
                "protein": round(v["protein"], 1),
                "carbs": round(v["carbs"], 1),
                "fat": round(v["fat"], 1),
                "fiber": round(v["fiber"], 1),
            },
            "servings": servings,
            "source": fb.source(r),
        })
    foods.sort(key=lambda f: f["id"])
    return foods


# ---------------------------------------------------------------- exercises
def load_fedb() -> dict[str, dict]:
    wanted = {row[0] for row in exercises_table.STRENGTH}
    wanted |= {row[0] for row in exercises_table.CARDIO if row[0]}
    if FEDB_CACHE.exists():
        full = {e["id"]: e for e in json.loads(FEDB_CACHE.read_text(encoding="utf-8"))}
        missing = sorted(wanted - full.keys())
        if missing:
            raise SystemExit(f"free-exercise-db ids not found: {missing}")
        subset = {
            k: {f: full[k].get(f) for f in ("id", "name", "primaryMuscles", "secondaryMuscles",
                                           "equipment", "category")}
            for k in sorted(wanted)
        }
        dump(FEDB_SUBSET, {"source": "yuhonas/free-exercise-db dist/exercises.json (Unlicense)",
                           "exercises": subset})
    subset = json.loads(FEDB_SUBSET.read_text(encoding="utf-8"))["exercises"]
    missing = sorted(wanted - subset.keys())
    if missing:
        raise SystemExit(f"fedb_subset.json lacks: {missing}")
    return subset


def map_muscles(names: list[str]) -> list[str]:
    out: list[str] = []
    for n in names:
        m = MUSCLE_MAP[n]
        if m not in out:
            out.append(m)
    return out


def build_exercises(lock: dict) -> list[dict]:
    fedb = load_fedb()
    rows = []
    for fid, name_tr, met, primary in exercises_table.STRENGTH:
        e = fedb[fid]
        mapped = map_muscles(e["primaryMuscles"])
        prim = primary or mapped[0]
        sec = [m for m in mapped + map_muscles(e["secondaryMuscles"]) if m != prim]
        sec = list(dict.fromkeys(sec))
        rows.append((fid, {
            "nameTr": name_tr, "nameEn": e["name"], "primaryMuscle": prim,
            "secondaryMuscles": sec, "equipment": EQUIPMENT_MAP.get(e["equipment"], "other"),
            "kind": "strength", "met": met,
        }))
    for fid, name_tr, name_en, equipment, met in exercises_table.CARDIO:
        rows.append((fid or f"cardio:{name_en}", {
            "nameTr": name_tr, "nameEn": name_en, "primaryMuscle": "cardio",
            "secondaryMuscles": [], "equipment": equipment, "kind": "cardio", "met": met,
        }))
    keys = [k for k, _ in rows]
    dupes = {k for k in keys if keys.count(k) > 1}
    if dupes:
        raise SystemExit(f"duplicate exercises: {sorted(dupes)}")
    lock_ids(lock.setdefault("exercises", {}), keys, "ex")
    out = [{"id": lock["exercises"][k], **body} for k, body in rows]
    out.sort(key=lambda e: e["id"])
    return out


def main() -> int:
    lock = json.loads(ID_LOCK.read_text(encoding="utf-8")) if ID_LOCK.exists() else {}
    foods = build_foods(lock)
    exercises = build_exercises(lock)
    lock = {k: dict(sorted(v.items(), key=lambda kv: kv[1])) for k, v in sorted(lock.items())}
    dump(ID_LOCK, lock)
    dump(SEED_DIR / "foods_tr.json", {"version": 1, "foods": foods})
    dump(SEED_DIR / "exercises.json", {"version": 1, "exercises": exercises})
    print(f"foods: {len(foods)}  exercises: {len(exercises)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
