#!/usr/bin/env python3
"""
Import vehicle data from https://github.com/plowman/open-vehicle-db
Supports years 1981-2026, 65 makes, 1669 models, 9725 styles.
"""
import json
import sys
from pathlib import Path

try:
    import urllib.request
    HAS_URLLIB = True
except ImportError:
    HAS_URLLIB = False

OUTPUT_SQL = Path(__file__).parent.parent / "supabase" / "migrations" / "20251007120000_vehicle_data_open_vehicle_db.sql"
BASE_URL = "https://raw.githubusercontent.com/plowman/open-vehicle-db/master/data"


def _escape(s: str) -> str:
    return s.replace("'", "''")


def fetch_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "zeno-import"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


def load_local(base: Path) -> tuple[list, dict]:
    makes_path = base / "makes_and_models.json"
    if not makes_path.exists():
        raise FileNotFoundError(f"Clone open-vehicle-db and set data path, or run with --fetch. Expected: {makes_path}")
    makes_data = json.loads(makes_path.read_text(encoding="utf-8"))
    styles_dir = base / "styles"
    styles_cache = {}
    for f in styles_dir.glob("*.json"):
        styles_cache[f.stem] = json.loads(f.read_text(encoding="utf-8"))
    return makes_data, styles_cache


def load_remote() -> tuple[list, dict]:
    makes_data = fetch_json(f"{BASE_URL}/makes_and_models.json")
    styles_list = [
        "acura", "alfa_romeo", "am_general", "aston_martin", "audi", "bentley", "bmw", "bugatti", "buick",
        "cadillac", "chevrolet", "chrysler", "daewoo", "daihatsu", "daimler", "datsun", "delorean", "dodge",
        "ferrari", "fiat", "fisker", "ford", "geo", "gmc", "honda", "hummer", "hyundai", "infiniti", "isuzu",
        "jaguar", "jeep", "karma", "kia", "lamborghini", "land_rover", "lexus", "lincoln", "lotus", "lucid",
        "maserati", "maybach", "mazda", "mclaren", "mercedes_benz", "mercury", "mini", "mitsubishi", "nissan",
        "oldsmobile", "peterbilt", "peugeot", "plymouth", "pontiac", "porsche", "ram", "rivian", "rolls_royce",
        "saab", "saturn", "shelby", "smart", "spyker", "subaru", "suzuki", "tesla", "toyota", "triumph",
        "volvo", "yugo"
    ]
    styles_cache = {}
    for slug in styles_list:
        try:
            styles_cache[slug] = fetch_json(f"{BASE_URL}/styles/{slug}.json")
        except Exception as e:
            print(f"Warning: could not fetch {slug}.json: {e}", file=sys.stderr)
    return makes_data, styles_cache


def extract_rows(makes_data: list, styles_cache: dict) -> list[tuple[str, str, str, int]]:
    rows = []
    for make_obj in makes_data:
        make_name = make_obj.get("make_name", "")
        make_slug = make_obj.get("make_slug", "").lower().replace("-", "_")
        models = make_obj.get("models", {})
        styles_data = styles_cache.get(make_slug, {})

        for model_name, model_obj in models.items():
            if not isinstance(model_obj, dict):
                continue
            style_names = styles_data.get(model_name, {})
            if not style_names:
                years = model_obj.get("years", [])
                for y in years:
                    rows.append((make_name, model_name, model_name, y))
                continue
            for style_name, style_obj in style_names.items():
                if not isinstance(style_obj, dict):
                    continue
                years = style_obj.get("years", [])
                for y in years:
                    rows.append((make_name, model_name, style_name, y))
    return rows


def generate_sql(rows: list[tuple[str, str, str, int]]) -> str:
    makes = sorted(set(r[0] for r in rows))
    models_set = set((r[0], r[1]) for r in rows)
    models = sorted(models_set, key=lambda x: (x[0], x[1]))
    styles_set = set((r[0], r[1], r[2]) for r in rows)
    styles = sorted(styles_set, key=lambda x: (x[0], x[1], x[2]))

    lines = [
        "UPDATE public.listings SET make_id = NULL, model_id = NULL, style_id = NULL, model_year_id = NULL WHERE make_id IS NOT NULL OR model_id IS NOT NULL OR style_id IS NOT NULL OR model_year_id IS NOT NULL;",
        "DELETE FROM public.model_years;",
        "DELETE FROM public.styles;",
        "DELETE FROM public.models;",
        "DELETE FROM public.makes;",
        "",
        "INSERT INTO public.makes (name) VALUES",
    ]
    make_vals = [f"  ('{_escape(m)}')" for m in makes]
    lines.append(",\n".join(make_vals) + " ON CONFLICT (name) DO NOTHING;")
    lines.append("")

    lines.append("INSERT INTO public.models (make_id, name)")
    lines.append("SELECT m.id, v.name FROM (VALUES")
    model_vals = [f"  ('{_escape(maker)}', '{_escape(model)}')" for maker, model in models]
    lines.append(",\n".join(model_vals))
    lines.append(") AS v(maker_name, name)")
    lines.append("JOIN makes m ON m.name = v.maker_name")
    lines.append("ON CONFLICT (name, make_id) DO NOTHING;")
    lines.append("")

    lines.append("INSERT INTO public.styles (model_id, style_name)")
    lines.append("SELECT mo.id, v.style_name FROM (VALUES")
    style_vals = [f"  ('{_escape(m)}', '{_escape(mo)}', '{_escape(s)}')" for m, mo, s in styles]
    lines.append(",\n".join(style_vals))
    lines.append(") AS v(maker_name, model_name, style_name)")
    lines.append("JOIN makes ma ON ma.name = v.maker_name")
    lines.append("JOIN models mo ON mo.make_id = ma.id AND mo.name = v.model_name")
    lines.append("ON CONFLICT (style_name, model_id) DO NOTHING;")
    lines.append("")

    lines.append("INSERT INTO public.model_years (style_id, year)")
    lines.append("SELECT st.id, v.year FROM (VALUES")
    year_vals = [f"  ('{_escape(m)}', '{_escape(mo)}', '{_escape(s)}', {y})" for m, mo, s, y in rows]
    lines.append(",\n".join(year_vals))
    lines.append(") AS v(maker_name, model_name, style_name, year)")
    lines.append("JOIN makes ma ON ma.name = v.maker_name")
    lines.append("JOIN models mo ON mo.make_id = ma.id AND mo.name = v.model_name")
    lines.append("JOIN styles st ON st.model_id = mo.id AND st.style_name = v.style_name")
    lines.append("ON CONFLICT (year, style_id) DO NOTHING;")

    return "\n".join(lines)


def main():
    data_path = Path(__file__).parent.parent / "data" / "open-vehicle-db"
    if "--fetch" in sys.argv or not data_path.exists():
        print("Fetching from GitHub...")
        makes_data, styles_cache = load_remote()
    else:
        print(f"Loading from {data_path}...")
        makes_data, styles_cache = load_local(data_path)

    rows = extract_rows(makes_data, styles_cache)
    years = set(r[3] for r in rows)
    print(f"Parsed {len(rows)} model-year rows, {len(set(r[0] for r in rows))} makes, years {min(years)}-{max(years)}")

    sql = generate_sql(rows)
    OUTPUT_SQL.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_SQL.write_text(sql, encoding="utf-8")
    print(f"Written to {OUTPUT_SQL}")


if __name__ == "__main__":
    main()
