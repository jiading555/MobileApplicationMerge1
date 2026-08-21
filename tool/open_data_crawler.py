import argparse
import csv
import io
import json
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path


API_BASE = "https://api.data.gov.my/data-catalogue"
GTFS_BASE = "https://api.data.gov.my/gtfs-static"
POPULATION_DISTRICT_CSV = "https://storage.dosm.gov.my/population/population_district.csv"
CRIME_DISTRICT_CSV = "https://storage.data.gov.my/publicsafety/crime_district.csv"
DATASET_CACHE = {}

STATE_ALIASES = {
    "pulau pinang": "penang",
    "p pinang": "penang",
    "w.p. kuala lumpur": "kuala lumpur",
    "wp kuala lumpur": "kuala lumpur",
    "wilayah persekutuan kuala lumpur": "kuala lumpur",
    "w.p. putrajaya": "putrajaya",
    "wp putrajaya": "putrajaya",
    "w.p. labuan": "labuan",
    "wp labuan": "labuan",
}

SOURCE_REFERENCES = {
    "population_district": "https://open.dosm.gov.my/data-catalogue/population_district",
    "hh_income_district": "https://open.dosm.gov.my/data-catalogue/hh_income_district",
    "crime_district": "https://data.gov.my/data-catalogue/crime_district",
    "schools_district": "https://data.gov.my/data-catalogue/schools_district",
    "hh_profile": "https://data.gov.my/data-catalogue/hh_profile",
    "gtfs_static": "https://developer.data.gov.my/realtime-api/gtfs-static",
}

DISPLAY_NAMES = {
    "penang": "Pulau Pinang",
}

CRIME_DISTRICT_ALIASES = {
    ("selangor", "petaling"): [
        "Petaling Jaya",
        "Shah Alam",
        "Subang Jaya",
        "Sungai Buloh",
        "Serdang",
    ],
    ("selangor", "gombak"): ["Gombak"],
    ("selangor", "ulu langat"): ["Kajang", "Ampang Jaya"],
    ("johor", "johor bahru"): ["Johor Bahru Selatan", "Johor Bahru Utara"],
    ("penang", "timur laut"): ["Timur Laut"],
}

SOURCE_LABELS = {
    "population_district": "OpenDOSM",
    "hh_income_district": "OpenDOSM",
    "crime_district": "data.gov.my",
    "schools_district": "data.gov.my",
    "gtfs_static": "data.gov.my GTFS Static",
}


def normalise_text(value):
    text = str(value or "").strip().lower()
    text = " ".join(text.replace("-", " ").replace("_", " ").split())
    return STATE_ALIASES.get(text, text)


def title_text(value):
    normalised = normalise_text(value)
    return DISPLAY_NAMES.get(
        normalised,
        " ".join(part.capitalize() for part in normalised.split()),
    )


def parse_number(value):
    if value is None or value == "":
        return None
    if isinstance(value, (int, float)):
        return value
    text = str(value).replace(",", "").strip()
    try:
        number = float(text)
    except ValueError:
        return None
    return int(number) if number.is_integer() else number


def request_json(url, params=None, retries=3, timeout=30):
    query = urllib.parse.urlencode(params or {})
    target = f"{url}?{query}" if query else url
    last_error = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(target, timeout=timeout) as response:
                return json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            last_error = error
            if attempt + 1 < retries:
                time.sleep(1.2 * (attempt + 1))
    raise RuntimeError(f"Unable to fetch {target}: {last_error}")


def records_from_response(payload):
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        for key in ("data", "results", "records"):
            value = payload.get(key)
            if isinstance(value, list):
                return value
    return []


def fetch_dataset(dataset_id, limit=5000, **filters):
    params = {"id": dataset_id, "limit": limit}
    for key, value in filters.items():
        if value not in (None, ""):
            params[key] = value
    payload = request_json(API_BASE, params=params)
    return records_from_response(payload)


def fetch_csv_dataset(url):
    if url in DATASET_CACHE:
        return DATASET_CACHE[url]
    with urllib.request.urlopen(url, timeout=60) as response:
        text = response.read().decode("utf-8-sig")
    records = list(csv.DictReader(io.StringIO(text)))
    DATASET_CACHE[url] = records
    return records


def newest(records):
    dated = [record for record in records if record.get("date")]
    if dated:
        dated.sort(key=lambda item: str(item.get("date") or ""), reverse=True)
        latest_date = dated[0].get("date")
        return [record for record in dated if record.get("date") == latest_date]
    return records


def record_year(records):
    for record in records:
        date = str(record.get("date") or "").strip()
        if len(date) >= 4 and date[:4].isdigit():
            return int(date[:4])
    return None


def filter_location(records, state, district):
    state_key = normalise_text(state)
    district_key = normalise_text(district)
    matched = []
    for record in records:
        record_state = normalise_text(record.get("state"))
        record_district = normalise_text(record.get("district"))
        if state_key and record_state != state_key:
            continue
        if district_key and record_district != district_key:
            continue
        matched.append(record)
    return matched


def filter_crime_location(records, state, district):
    state_key = normalise_text(state)
    district_key = normalise_text(district)
    aliases = CRIME_DISTRICT_ALIASES.get((state_key, district_key), [district])
    alias_keys = {normalise_text(alias) for alias in aliases}
    matched = []
    for record in records:
        if normalise_text(record.get("state")) != state_key:
            continue
        if normalise_text(record.get("district")) not in alias_keys:
            continue
        if normalise_text(record.get("type")) != "all":
            continue
        matched.append(record)
    return matched


def sum_field(records, field):
    total = 0
    found = False
    for record in records:
        value = parse_number(record.get(field))
        if value is not None:
            total += value
            found = True
    return total if found else None


def first_field(records, field):
    for record in records:
        value = parse_number(record.get(field))
        if value is not None:
            return value
    return None


def clean_area_profile(state, district):
    population_rows = fetch_csv_dataset(POPULATION_DISTRICT_CSV)
    population = newest(
        [
            record
            for record in filter_location(population_rows, state, district)
            if normalise_text(record.get("sex")) == "both"
            and normalise_text(record.get("age")) == "overall"
            and normalise_text(record.get("ethnicity")) == "overall"
        ]
    )
    income = newest(fetch_dataset("hh_income_district", state=state, district=district))
    schools = newest(fetch_dataset("schools_district", state=state, district=district))
    crime = newest(fetch_csv_dataset(CRIME_DISTRICT_CSV))
    latest_population = first_field(population, "population")
    population_value = int(latest_population * 1000) if latest_population is not None else None
    school_count = sum_field(filter_location(schools, state, district), "schools")
    crime_count = sum_field(filter_crime_location(crime, state, district), "crimes")
    income_records = filter_location(income, state, district)
    population_year = record_year(population)
    income_year = record_year(income)
    school_year = record_year(schools)
    crime_year = record_year(crime)
    years = [
        year
        for year in [population_year, income_year, school_year, crime_year]
        if year is not None
    ]
    sources = [
        "population_district",
        "hh_income_district",
        "schools_district",
        "crime_district",
    ]
    return {
        "area_id": f"{normalise_text(state).replace(' ', '_')}_{normalise_text(district).replace(' ', '_')}",
        "state": title_text(state),
        "district": title_text(district),
        "population": population_value,
        "population_year": population_year,
        "median_household_income": first_field(income_records, "income_median"),
        "mean_household_income": first_field(income_records, "income_mean"),
        "income_year": income_year,
        "crime_count": crime_count,
        "crime_year": crime_year,
        "education_institution_count": school_count,
        "education_year": school_year,
        "transport_stop_count": None,
        "transport_year": None,
        "data_year": max(years) if years else None,
        "source": "OpenDOSM; data.gov.my",
        "source_url": "; ".join(SOURCE_REFERENCES[source] for source in sources),
        "retrieved_at": datetime.now(timezone.utc).isoformat(),
        "sources": sources,
        "source_details": [
            {
                "source": SOURCE_LABELS[source],
                "dataset": source,
                "url": SOURCE_REFERENCES[source],
            }
            for source in sources
        ],
    }


def fetch_gtfs_stops(agency, category=None, limit=200):
    params = {"category": category} if category else None
    query = urllib.parse.urlencode(params or {})
    target = f"{GTFS_BASE}/{agency}?{query}" if query else f"{GTFS_BASE}/{agency}"
    with urllib.request.urlopen(target, timeout=60) as response:
        archive = zipfile.ZipFile(io.BytesIO(response.read()))
    with archive.open("stops.txt") as file:
        text = io.TextIOWrapper(file, encoding="utf-8-sig")
        rows = csv.DictReader(text)
        stops = []
        for row in rows:
            stops.append(
                {
                    "stopId": row.get("stop_id"),
                    "name": row.get("stop_name"),
                    "latitude": parse_number(row.get("stop_lat")),
                    "longitude": parse_number(row.get("stop_lon")),
                    "agency": agency,
                    "category": category,
                    "source": "gtfs_static",
                }
            )
            if len(stops) >= limit:
                break
        return stops


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=True), encoding="utf-8")


def write_csv(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fieldnames = [
        "area_id",
        "state",
        "district",
        "population",
        "population_year",
        "median_household_income",
        "mean_household_income",
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
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field) for field in fieldnames})


def parse_targets(raw_targets):
    targets = []
    for item in raw_targets:
        if "," not in item:
            raise ValueError("Use State,District format such as Selangor,Gombak")
        state, district = item.split(",", 1)
        targets.append((state.strip(), district.strip()))
    return targets


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--target",
        action="append",
        default=[
            "Selangor,Petaling",
            "Selangor,Gombak",
            "Selangor,Ulu Langat",
            "Johor,Johor Bahru",
            "Pulau Pinang,Timur Laut",
        ],
    )
    parser.add_argument("--output", default="data/processed")
    parser.add_argument("--include-gtfs", action="store_true")
    parser.add_argument("--gtfs-agency", default="prasarana")
    parser.add_argument("--gtfs-category", default="rapid-rail-kl")
    args = parser.parse_args()

    output = Path(args.output)
    profiles = [clean_area_profile(state, district) for state, district in parse_targets(args.target)]
    write_json(output / "area_profiles.json", profiles)
    write_csv(output / "area_profiles.csv", profiles)
    write_json(
        output / "data_sources.json",
        {
            "retrievedAt": datetime.now(timezone.utc).isoformat(),
            "references": SOURCE_REFERENCES,
        },
    )

    if args.include_gtfs:
        stops = fetch_gtfs_stops(args.gtfs_agency, args.gtfs_category)
        write_json(output / "transport_stops.json", stops)
        write_csv(output / "transport_stops.csv", stops)

    print(f"Saved {len(profiles)} area profiles to {output}")


if __name__ == "__main__":
    main()
