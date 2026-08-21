import argparse
import json
import os
import urllib.error
import urllib.request
from pathlib import Path


AREA_COLUMNS = [
    "area_id",
    "state",
    "district",
    "population",
    "population_year",
    "median_household_income",
    "income_year",
    "crime_count",
    "crime_year",
    "education_institution_count",
    "education_year",
    "transport_stop_count",
    "transport_year",
    "data_year",
    "source",
    "source_url",
    "retrieved_at",
]

PROPERTY_COLUMNS = [
    "source_id",
    "project_name",
    "state",
    "district",
    "scheme",
    "price_min",
    "price_max",
    "property_type",
    "developer_name",
    "latitude",
    "longitude",
    "total_units",
    "available_units",
    "source",
    "source_url",
    "retrieved_at",
]


def load_records(path, columns, defaults=None):
    defaults = defaults or {}
    raw = json.loads(Path(path).read_text(encoding="utf-8"))
    return [
        {
            column: record.get(column, defaults.get(column))
            for column in columns
            if record.get(column, defaults.get(column)) is not None
        }
        for record in raw
    ]


def upsert(table, records, conflict_column, batch_size):
    url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        raise RuntimeError(
            "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before importing."
        )

    endpoint = f"{url}/rest/v1/{table}?on_conflict={conflict_column}"
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }

    for start in range(0, len(records), batch_size):
        batch = records[start : start + batch_size]
        request = urllib.request.Request(
            endpoint,
            data=json.dumps(batch).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                response.read()
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Supabase upsert failed for {table}: {body}") from error
        print(f"[Supabase] Upserted {len(batch)} rows into {table}")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Upsert processed Malaysian open-data JSON into Supabase."
    )
    parser.add_argument("--area-profiles", default="data/processed/area_profiles.json")
    parser.add_argument("--teduh-projects", default="data/processed/teduh_projects.json")
    parser.add_argument("--skip-area-profiles", action="store_true")
    parser.add_argument("--skip-properties", action="store_true")
    parser.add_argument("--batch-size", type=int, default=100)
    return parser.parse_args()


def main():
    args = parse_args()

    if not args.skip_area_profiles:
        area_profiles = load_records(args.area_profiles, AREA_COLUMNS)
        upsert("area_profiles", area_profiles, "area_id", args.batch_size)

    if not args.skip_properties:
        properties = load_records(
            args.teduh_projects,
            PROPERTY_COLUMNS,
            defaults={"source": "TEDUH - Jabatan Perumahan Negara, KPKT"},
        )
        upsert("properties", properties, "source_id", args.batch_size)


if __name__ == "__main__":
    main()
