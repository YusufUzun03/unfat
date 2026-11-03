"""Extract per-100 g nutrient values for the ingredients in fdc_ingredients.py
from the USDA FoodData Central SR Legacy bulk CSV and write fdc_ingredients.json.

Usage:  python tools/seed/extract_fdc.py
The zip (~6 MB) is downloaded once into tools/seed/cache/ (gitignored).
The resulting fdc_ingredients.json is committed, so generate.py never needs
the network.
"""
from __future__ import annotations

import csv
import io
import json
import sys
import urllib.request
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from fdc_ingredients import INGREDIENTS  # noqa: E402

ZIP_URL = "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip"
CACHE = HERE / "cache"
ZIP_PATH = CACHE / "sr_legacy_2018-04.zip"
OUT = HERE / "fdc_ingredients.json"

# FDC nutrient ids
NUTRIENTS = {"1008": "kcal", "1003": "protein", "1005": "carbs", "1004": "fat", "1079": "fiber"}


def ensure_zip() -> None:
    if ZIP_PATH.exists():
        return
    CACHE.mkdir(parents=True, exist_ok=True)
    print(f"downloading {ZIP_URL}")
    urllib.request.urlretrieve(ZIP_URL, ZIP_PATH)


def read_csv(zf: zipfile.ZipFile, name: str):
    member = next(n for n in zf.namelist() if n.endswith("/" + name))
    with zf.open(member) as fh:
        yield from csv.DictReader(io.TextIOWrapper(fh, encoding="utf-8"))


def main() -> int:
    ensure_zip()
    wanted = {str(v) for v in INGREDIENTS.values()}
    desc: dict[str, str] = {}
    values: dict[str, dict[str, float]] = {}
    with zipfile.ZipFile(ZIP_PATH) as zf:
        for row in read_csv(zf, "food.csv"):
            if row["fdc_id"] in wanted:
                desc[row["fdc_id"]] = row["description"]
        for row in read_csv(zf, "food_nutrient.csv"):
            fid = row["fdc_id"]
            if fid in wanted and row["nutrient_id"] in NUTRIENTS:
                values.setdefault(fid, {})[NUTRIENTS[row["nutrient_id"]]] = float(row["amount"])

    missing = sorted(wanted - desc.keys())
    if missing:
        print("missing FDC ids:", missing)
        return 1

    out = {}
    for key in sorted(INGREDIENTS):
        fid = str(INGREDIENTS[key])
        v = values.get(fid, {})
        out[key] = {
            "fdcId": int(fid),
            "description": desc[fid],
            # Fiber is not reported for a few SR items; treat as 0.
            **{n: round(v.get(n, 0.0), 2) for n in NUTRIENTS.values()},
        }
    OUT.write_text(json.dumps({"source": "USDA FoodData Central, SR Legacy (2018-04), public domain",
                               "ingredients": out}, ensure_ascii=False, indent=2) + "\n",
                   encoding="utf-8")
    print(f"wrote {len(out)} ingredients to {OUT.relative_to(HERE.parent.parent)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
