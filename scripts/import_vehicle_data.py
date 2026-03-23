#!/usr/bin/env python3
import csv
import sys
from pathlib import Path
from collections import defaultdict

OUTPUT_SQL = Path(__file__).parent.parent / "supabase" / "migrations" / "20250225120001_vehicle_data_seed.sql"


def _norm(s: str) -> str:
    return ' '.join(s.strip().split())


def parse_csv(content: str) -> list[tuple[int, str, str, str]]:
    rows = []
    for row in csv.reader(content.strip().split("\n"), quotechar='"'):
        if len(row) >= 4:
            try:
                year = int(row[0].strip())
                maker = _norm(row[1])
                model = _norm(row[2])
                fullmodel = _norm(row[3])
                if maker and model and fullmodel:
                    rows.append((year, maker, model, fullmodel))
            except (ValueError, IndexError):
                pass
    return rows


def generate_sql(rows: list[tuple[int, str, str, str]]) -> str:
    makes = sorted(set(r[1] for r in rows))
    models_set = set((r[1], r[2]) for r in rows)
    models = sorted(models_set, key=lambda x: (x[0], x[1]))
    styles_set = set((r[1], r[2], r[3]) for r in rows)
    styles = sorted(styles_set, key=lambda x: (x[0], x[1], x[2]))

    lines = [
        "UPDATE public.listings SET make_id = NULL, model_id = NULL, style_id = NULL, model_year_id = NULL WHERE make_id IS NOT NULL OR model_id IS NOT NULL OR style_id IS NOT NULL OR model_year_id IS NOT NULL;",
        "TRUNCATE public.model_years, public.styles, public.models, public.makes;",
        "",
        "INSERT INTO public.makes (name) VALUES",
    ]
    make_vals = [f"  ('{m.replace(chr(39), chr(39)+chr(39))}')" for m in makes]
    lines.append(",\n".join(make_vals) + " ON CONFLICT (name) DO NOTHING;")
    lines.append("")

    lines.append("INSERT INTO public.models (make_id, name)")
    lines.append("SELECT m.id, v.name FROM (VALUES")
    model_vals = [f"  ('{maker.replace(chr(39), chr(39)+chr(39))}', '{model.replace(chr(39), chr(39)+chr(39))}')" for maker, model in models]
    lines.append(",\n".join(model_vals))
    lines.append(") AS v(maker_name, name)")
    lines.append("JOIN makes m ON m.name = v.maker_name")
    lines.append("ON CONFLICT (name, make_id) DO NOTHING;")
    lines.append("")

    lines.append("INSERT INTO public.styles (model_id, style_name)")
    lines.append("SELECT mo.id, v.style_name FROM (VALUES")
    style_vals = [f"  ('{m.replace(chr(39), chr(39)+chr(39))}', '{mo.replace(chr(39), chr(39)+chr(39))}', '{s.replace(chr(39), chr(39)+chr(39))}')" for m, mo, s in styles]
    lines.append(",\n".join(style_vals))
    lines.append(") AS v(maker_name, model_name, style_name)")
    lines.append("JOIN makes ma ON ma.name = v.maker_name")
    lines.append("JOIN models mo ON mo.make_id = ma.id AND mo.name = v.model_name")
    lines.append("ON CONFLICT (style_name, model_id) DO NOTHING;")
    lines.append("")

    lines.append("INSERT INTO public.model_years (style_id, year)")
    lines.append("SELECT st.id, v.year FROM (VALUES")
    year_vals = [f"  ('{m.replace(chr(39), chr(39)+chr(39))}', '{mo.replace(chr(39), chr(39)+chr(39))}', '{s.replace(chr(39), chr(39)+chr(39))}', {y})" for y, m, mo, s in rows]
    lines.append(",\n".join(year_vals))
    lines.append(") AS v(maker_name, model_name, style_name, year)")
    lines.append("JOIN makes ma ON ma.name = v.maker_name")
    lines.append("JOIN models mo ON mo.make_id = ma.id AND mo.name = v.model_name")
    lines.append("JOIN styles st ON st.model_id = mo.id AND st.style_name = v.style_name")
    lines.append("ON CONFLICT (year, style_id) DO NOTHING;")

    return "\n".join(lines)


def main():
    csv_path = Path(__file__).parent.parent / "data" / "csvdata.csv"
    if not csv_path.exists():
        print(f"Download csvdata.csv from https://github.com/ElyesDer/Vehicle-data-DB and save to {csv_path}")
        sys.exit(1)

    content = csv_path.read_text(encoding="utf-8", errors="replace")
    rows = parse_csv(content)
    print(f"Parsed {len(rows)} rows, {len(set(r[1] for r in rows))} makes")

    sql = generate_sql(rows)
    OUTPUT_SQL.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_SQL.write_text(sql, encoding="utf-8")
    print(f"Written to {OUTPUT_SQL}")


if __name__ == "__main__":
    main()
