#!/usr/bin/env python3
"""Build district government-data snapshots and upsert them to Supabase."""

from __future__ import annotations

import csv
import io
import json
import math
import os
import re
import zipfile
from datetime import datetime, timezone

import requests

API_BASE = "https://api.data.gov.my/data-catalogue"
POPULATION_CSV = "https://storage.dosm.gov.my/population/population_district.csv"
BOUNDARIES_URL = (
    "https://raw.githubusercontent.com/dosm-malaysia/kawasanku-front/main/"
    "geojson/district_mobile.json"
)
GTFS_FEEDS = (
    "https://api.data.gov.my/gtfs-static/ktmb",
    "https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl",
    "https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-mrtfeeder",
    "https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl",
)
SOURCE_URLS = (
    "https://open.dosm.gov.my/data-catalogue/population_district;"
    "https://open.dosm.gov.my/data-catalogue/hh_income_district;"
    "https://data.gov.my/data-catalogue/crime_district;"
    "https://data.gov.my/data-catalogue/schools_district;"
    "https://data.gov.my/data-catalogue/hospital_beds;"
    "https://developer.data.gov.my/realtime-api/gtfs-static"
)
TIMEOUT = 120

STATE_ALIASES = {
    "pulau pinang": "penang",
    "p pinang": "penang",
    "w p kuala lumpur": "kuala lumpur",
    "wp kuala lumpur": "kuala lumpur",
    "wilayah persekutuan kuala lumpur": "kuala lumpur",
    "w p putrajaya": "putrajaya",
    "wp putrajaya": "putrajaya",
    "w p labuan": "labuan",
    "wp labuan": "labuan",
}
DISPLAY_STATES = {
    "penang": "Pulau Pinang",
    "kuala lumpur": "W.P. Kuala Lumpur",
    "putrajaya": "W.P. Putrajaya",
    "labuan": "W.P. Labuan",
}
CRIME_DISTRICT_ALIASES = {
    ("selangor", "petaling"): (
        "Petaling Jaya", "Shah Alam", "Subang Jaya", "Sungai Buloh", "Serdang",
    ),
    ("selangor", "gombak"): ("Gombak",),
    ("selangor", "ulu langat"): ("Kajang", "Ampang Jaya"),
    ("selangor", "ulu selangor"): ("Hulu Selangor",),
    ("selangor", "klang"): ("Klang Selatan", "Klang Utara"),
    ("johor", "johor bahru"): ("Johor Bahru Selatan", "Johor Bahru Utara"),
    ("johor", "kulai"): ("Kulaijaya",),
    ("johor", "tangkak"): ("Ledang",),
    ("penang", "timur laut"): ("Timur Laut",),
    ("kuala lumpur", "kuala lumpur"): ("All",),
}
HOSPITAL_DISTRICT_ALIASES = {
    ("selangor", "petaling"): ("Petaling (Subang Jaya)",),
    ("selangor", "gombak"): ("Gombak (Rawang)",),
    ("selangor", "ulu langat"): ("Hulu Langat (Bangi)",),
    ("johor", "johor bahru"): ("Johor Bahru",),
    ("penang", "timur laut"): ("Timur Laut (Georgetown)",),
}


def normalise(value: object) -> str:
    text = re.sub(r"[^a-z0-9]+", " ", str(value or "").lower()).strip()
    return STATE_ALIASES.get(text, text)


def title(value: object) -> str:
    key = normalise(value)
    return DISPLAY_STATES.get(key, " ".join(part.capitalize() for part in key.split()))


def area_id(state: str, district: str) -> str:
    def slug(value: str) -> str:
        return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return f"{slug(state)}_{slug(district)}"


def number(value: object) -> float | None:
    if value is None or value == "":
        return None
    try:
        parsed = float(str(value).replace(",", "").strip())
        return parsed if math.isfinite(parsed) else None
    except (TypeError, ValueError):
        return None


def year(records: list[dict]) -> int | None:
    for record in records:
        match = re.match(r"(20\d{2})", str(record.get("date") or ""))
        if match:
            return int(match.group(1))
    return None


def newest(records: list[dict]) -> list[dict]:
    dated = [row for row in records if row.get("date")]
    if not dated:
        return records
    latest = max(str(row["date"]) for row in dated)
    return [row for row in dated if str(row["date"]) == latest]


def fetch_dataset(session: requests.Session, dataset_id: str) -> list[dict]:
    response = session.get(
        API_BASE,
        params={"id": dataset_id, "limit": "100000"},
        timeout=TIMEOUT,
    )
    response.raise_for_status()
    payload = response.json()
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        for key in ("data", "results", "records"):
            if isinstance(payload.get(key), list):
                return payload[key]
    raise RuntimeError(f"{dataset_id} returned no records")


def fetch_population(session: requests.Session) -> list[dict]:
    api_error: Exception | None = None
    try:
        rows = fetch_dataset(session, "population_district")
        if rows:
            return rows
    except Exception as error:
        api_error = error
    response = session.get(POPULATION_CSV, timeout=TIMEOUT)
    response.raise_for_status()
    rows = list(csv.DictReader(io.StringIO(response.text)))
    if not rows:
        raise RuntimeError(f"population API failed: {api_error}")
    return rows


def location_rows(rows: list[dict], state: str, district: str) -> list[dict]:
    state_key, district_key = normalise(state), normalise(district)
    return [
        row for row in rows
        if normalise(row.get("state")) == state_key
        and normalise(row.get("district")) == district_key
    ]


def sum_field(rows: list[dict], field: str) -> int | None:
    values = [number(row.get(field)) for row in rows]
    found = [value for value in values if value is not None]
    return round(sum(found)) if found else None


def first_field(rows: list[dict], field: str) -> float | None:
    for row in rows:
        value = number(row.get(field))
        if value is not None:
            return value
    return None


def crime_rows(rows: list[dict], state: str, district: str) -> list[dict]:
    state_key, district_key = normalise(state), normalise(district)
    aliases = CRIME_DISTRICT_ALIASES.get(
        (state_key, district_key), (district,)
    )
    alias_keys = {normalise(alias) for alias in aliases}
    state_rows = [
        row for row in rows
        if normalise(row.get("state")) == state_key
    ]
    matched = [
        row for row in state_rows
        if normalise(row.get("district")) in alias_keys
    ]

    # "All" is a catalogue/UI aggregate and is not guaranteed to be a
    # physical row. For a state-level target such as W.P. Kuala Lumpur,
    # aggregate every police district when that row is absent.
    if alias_keys == {"all"} and not matched:
        matched = state_rows

    aggregate_rows = [
        row for row in matched
        if normalise(row.get("type")) == "all"
    ]
    return aggregate_rows or matched


def hospital_rows(rows: list[dict], state: str, district: str) -> list[dict]:
    state_key, district_key = normalise(state), normalise(district)
    aliases = HOSPITAL_DISTRICT_ALIASES.get(
        (state_key, district_key), (district,)
    )
    alias_keys = {normalise(alias) for alias in aliases}
    return [
        row for row in rows
        if normalise(row.get("state")) == state_key
        and normalise(row.get("district")) in alias_keys
        and normalise(row.get("type")) == "all"
    ]


def location_key(state: str, district: str) -> str:
    state_key, district_key = normalise(state), normalise(district)
    if district_key == "ulu langat":
        district_key = "hulu langat"
    return f"{state_key}|{district_key}"


def read_polygons(geometry: dict) -> list[list[list[tuple[float, float]]]]:
    coordinates = geometry.get("coordinates")
    if not isinstance(coordinates, list):
        return []

    def polygon(value):
        output = []
        for ring in value:
            if not isinstance(ring, list):
                continue
            points = [
                (float(point[0]), float(point[1]))
                for point in ring
                if isinstance(point, list) and len(point) >= 2
            ]
            if len(points) >= 3:
                output.append(points)
        return output

    if geometry.get("type") == "Polygon":
        value = polygon(coordinates)
        return [value] if value else []
    if geometry.get("type") == "MultiPolygon":
        return [value for item in coordinates if (value := polygon(item))]
    return []


def inside_ring(ring: list[tuple[float, float]], x: float, y: float) -> bool:
    inside = False
    previous = len(ring) - 1
    for current, (xi, yi) in enumerate(ring):
        xj, yj = ring[previous]
        if (yi > y) != (yj > y):
            crossing = (xj - xi) * (y - yi) / (yj - yi) + xi
            if x < crossing:
                inside = not inside
        previous = current
    return inside


def inside(polygons, longitude: float, latitude: float) -> bool:
    for polygon in polygons:
        if not polygon or not inside_ring(polygon[0], longitude, latitude):
            continue
        if not any(inside_ring(hole, longitude, latitude) for hole in polygon[1:]):
            return True
    return False


def transport_counts(
    session: requests.Session,
    targets: list[tuple[str, str]],
) -> dict[str, int]:
    try:
        response = session.get(BOUNDARIES_URL, timeout=TIMEOUT)
        response.raise_for_status()
    except Exception as error:
        print(f"warning: district boundary feed skipped: {error}")
        return {}
    target_keys = {location_key(*target) for target in targets}
    boundaries = {}
    for feature in response.json().get("features", []):
        properties = feature.get("properties") or {}
        key = location_key(
            str(properties.get("state") or ""),
            str(properties.get("district") or ""),
        )
        if key in target_keys:
            polygons = read_polygons(feature.get("geometry") or {})
            if polygons:
                boundaries[key] = polygons
    if not boundaries:
        print("warning: no district boundaries matched; transport is unavailable")
        return {}

    stops: dict[tuple[float, float], tuple[float, float]] = {}
    successful_feeds = 0
    for feed in GTFS_FEEDS:
        try:
            feed_response = session.get(feed, timeout=TIMEOUT)
            feed_response.raise_for_status()
            with zipfile.ZipFile(io.BytesIO(feed_response.content)) as archive:
                with archive.open("stops.txt") as file:
                    reader = csv.DictReader(io.TextIOWrapper(file, encoding="utf-8-sig"))
                    for row in reader:
                        if row.get("location_type") not in (None, "", "0"):
                            continue
                        try:
                            latitude = float(row["stop_lat"])
                            longitude = float(row["stop_lon"])
                        except (KeyError, TypeError, ValueError):
                            continue
                        stops[(round(latitude, 5), round(longitude, 5))] = (
                            latitude, longitude
                        )
            successful_feeds += 1
        except Exception as error:
            print(f"warning: GTFS feed skipped: {feed}: {error}")
    if successful_feeds == 0:
        print("warning: all official GTFS feeds failed; transport is unavailable")
        return {}

    counts = {key: 0 for key in boundaries}
    boxes = {}
    for key, polygons in boundaries.items():
        points = [
            point
            for polygon in polygons
            for ring in polygon
            for point in ring
        ]
        boxes[key] = (
            min(point[0] for point in points),
            min(point[1] for point in points),
            max(point[0] for point in points),
            max(point[1] for point in points),
        )
    for latitude, longitude in stops.values():
        for key, polygons in boundaries.items():
            minimum_x, minimum_y, maximum_x, maximum_y = boxes[key]
            if not (
                minimum_x <= longitude <= maximum_x
                and minimum_y <= latitude <= maximum_y
            ):
                continue
            if inside(polygons, longitude, latitude):
                counts[key] += 1
                break
    return counts


def upsert(
    session: requests.Session,
    rows: list[dict],
    service_role_key: str,
) -> None:
    endpoint = f"{os.environ['SUPABASE_URL'].rstrip('/')}/rest/v1/area_profiles"
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }
    for start in range(0, len(rows), 100):
        response = session.post(
            endpoint,
            params={"on_conflict": "area_id"},
            json=rows[start:start + 100],
            headers=headers,
            timeout=TIMEOUT,
        )
        response.raise_for_status()


def main() -> None:
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not os.environ.get("SUPABASE_URL") or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required")

    session = requests.Session()
    session.headers.update({
        "User-Agent": "SmartPropertyAdvisor-Government-Crawler/1.0",
    })
    population_all = fetch_population(session)
    income_all = fetch_dataset(session, "hh_income_district")
    schools_all = fetch_dataset(session, "schools_district")
    crime_latest = newest(fetch_dataset(session, "crime_district"))
    hospitals_all = fetch_dataset(session, "hospital_beds")

    population_latest = newest([
        row for row in population_all
        if normalise(row.get("sex")) == "both"
        and normalise(row.get("age")) == "overall"
        and normalise(row.get("ethnicity")) == "overall"
    ])
    targets = sorted({
        (title(row.get("state")), title(row.get("district")))
        for row in population_latest
        if row.get("state") and row.get("district")
    })
    stops = transport_counts(session, targets)
    retrieved_at = datetime.now(timezone.utc)
    output = []

    for state, district in targets:
        population = newest(location_rows(population_latest, state, district))
        income = newest(location_rows(income_all, state, district))
        schools = newest(location_rows(schools_all, state, district))
        crimes = crime_rows(crime_latest, state, district)
        beds = newest(hospital_rows(hospitals_all, state, district))

        population_raw = first_field(population, "population")
        population_value = (
            round(population_raw * 1000) if population_raw is not None else None
        )
        transport_count = stops.get(location_key(state, district))
        if transport_count == 0:
            transport_count = None
        years = [
            value for value in (
                year(population), year(income), year(schools),
                year(crimes), year(beds),
                retrieved_at.year if transport_count is not None else None,
            )
            if value is not None
        ]
        output.append({
            "area_id": area_id(state, district),
            "state": state,
            "district": district,
            "population": population_value,
            "population_year": year(population),
            "median_household_income": first_field(income, "income_median"),
            "income_year": year(income),
            "crime_count": sum_field(crimes, "crimes"),
            "crime_year": year(crimes),
            "education_institution_count": sum_field(schools, "schools"),
            "education_year": year(schools),
            "hospital_bed_count": (
                round(value) if (value := first_field(beds, "beds")) is not None
                else None
            ),
            "hospital_year": year(beds),
            "transport_stop_count": transport_count,
            "transport_year": (
                retrieved_at.year if transport_count is not None else None
            ),
            "data_year": max(years) if years else None,
            "source": "OpenDOSM; data.gov.my",
            "source_url": SOURCE_URLS,
            "retrieved_at": retrieved_at.isoformat(),
        })

    kl_snapshot = next(
        (
            row for row in output
            if normalise(row["state"]) == "kuala lumpur"
            and normalise(row["district"]) == "kuala lumpur"
        ),
        None,
    )
    if (
        kl_snapshot is None
        or kl_snapshot["crime_count"] is None
        or kl_snapshot["crime_year"] is None
    ):
        raise RuntimeError(
            "Kuala Lumpur crime snapshot is unavailable; "
            "expected W.P. Kuala Lumpur state aggregate."
        )

    print(json.dumps({
        "kuala_lumpur_crime_count": kl_snapshot["crime_count"],
        "kuala_lumpur_crime_year": kl_snapshot["crime_year"],
    }))
    upsert(session, output, key)
    print(json.dumps({"updated": len(output), "retrieved_at": retrieved_at.isoformat()}))


if __name__ == "__main__":
    main()
