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

STATE_ALIASES = {
    "pulau pinang": "penang",
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


def normalise_text(value):
    text = str(value or "").strip().lower()
    text = " ".join(text.replace("-", " ").replace("_", " ").split())
    return STATE_ALIASES.get(text, text)


def title_text(value):
    return " ".join(part.capitalize() for part in normalise_text(value).split())


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


def newest(records):
    dated = [record for record in records if record.get("date")]
    if dated:
        dated.sort(key=lambda item: str(item.get("date") or ""), reverse=True)
        latest_date = dated[0].get("date")
        return [record for record in dated if record.get("date") == latest_date]
    return records


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
    population = newest(
        fetch_dataset(
            "population_district",
            state=state,
            district=district,
            sex="both",
            age="overall",
            ethnicity="overall",
        )
    )
    income = newest(fetch_dataset("hh_income_district", state=state, district=district))
    schools = newest(fetch_dataset("schools_district", state=state, district=district))
    crime = newest(fetch_dataset("crime_district", state=state, district=district))
    latest_population = first_field(filter_location(population, state, district), "population")
    population_value = int(latest_population * 1000) if latest_population is not None else None
    school_count = sum_field(filter_location(schools, state, district), "schools")
    crime_count = sum_field(filter_location(crime, state, district), "crimes")
    income_records = filter_location(income, state, district)
    return {
        "areaId": f"{normalise_text(state).replace(' ', '_')}_{normalise_text(district).replace(' ', '_')}",
        "state": title_text(state),
        "district": title_text(district),
        "population": population_value,
        "medianHouseholdIncome": first_field(income_records, "income_median"),
        "meanHouseholdIncome": first_field(income_records, "income_mean"),
        "educationInstitutionCount": school_count,
        "crimeCount": crime_count,
        "dataYear": str((population or income or schools or crime or [{}])[0].get("date", ""))[:4],
        "retrievedAt": datetime.now(timezone.utc).isoformat(),
        "sources": [
            "population_district",
            "hh_income_district",
            "schools_district",
            "crime_district",
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
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


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
        default=["Selangor,Petaling", "Selangor,Gombak", "Selangor,Ulu Langat"],
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
