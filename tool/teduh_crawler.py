import argparse
import csv
import hashlib
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


BASE_URL = "https://teduh.kpkt.gov.my"
PROJECTS_ENDPOINT = f"{BASE_URL}/api/portal/projects"
FILTERS_ENDPOINT = f"{BASE_URL}/api/portal/projects/filters"
PROJECTS_PAGE = f"{BASE_URL}/projek"
CRAWLER_VERSION = "teduh-crawler-0.1"

TARGET_STATES = [
    "Johor",
    "Kedah",
    "Kelantan",
    "Melaka",
    "Negeri Sembilan",
    "Pahang",
    "Pulau Pinang",
    "Perak",
    "Perlis",
    "Sabah",
    "Sarawak",
    "Selangor",
    "Terengganu",
]

CSV_FIELDS = [
    "source_id",
    "project_name",
    "state",
    "district",
    "scheme",
    "price_min",
    "price_max",
    "property_type",
    "project_status",
    "developer_name",
    "address",
    "source_url",
    "retrieved_at",
    "latitude",
    "longitude",
    "total_units",
    "available_units",
    "unit_types",
    "external_project_url",
    "developer_address",
    "raw_location",
]


def clean_text(value):
    if value is None:
        return None
    text = re.sub(r"\s+", " ", str(value)).strip()
    if text in {"", "-", "N/A", "n/a", "null", "None"}:
        return None
    return text


def title_case(value):
    text = clean_text(value)
    if text is None:
        return None
    return " ".join(part.capitalize() for part in text.lower().split())


def parse_number(value):
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return int(value) if float(value).is_integer() else float(value)
    text = clean_text(value)
    if text is None:
        return None
    text = re.sub(r"[^\d.]", "", text)
    if not text:
        return None
    try:
        number = float(text)
    except ValueError:
        return None
    return int(number) if number.is_integer() else number


def request_json(url, params=None, retries=3, timeout=30):
    query = urllib.parse.urlencode(params or {})
    target = f"{url}?{query}" if query else url
    headers = {
        "Accept": "application/json",
        "User-Agent": "SmartPropertyAdvisorTEDUHCrawler/0.1",
    }
    request = urllib.request.Request(target, headers=headers)
    last_error = None

    for attempt in range(retries):
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                charset = response.headers.get_content_charset() or "utf-8"
                return json.loads(response.read().decode(charset))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            last_error = error
            if attempt + 1 < retries:
                time.sleep(1.2 * (attempt + 1))

    raise RuntimeError(f"Unable to fetch {target}: {last_error}")


def source_url(params):
    visible_params = {
        "source": "Perumahan Awam",
    }
    if params.get("scheme"):
        visible_params["skim"] = params["scheme"]
    query = urllib.parse.urlencode(visible_params)
    return f"{PROJECTS_PAGE}?{query}" if query else PROJECTS_PAGE


def normalise_scheme(record):
    raw = clean_text(record.get("scheme_name"))
    if raw:
        return raw

    source_id = clean_text(record.get("id")) or ""
    prefix = source_id.split("_", 1)[0].upper()
    mapping = {
        "PPR": "Program Perumahan Rakyat (PPR)",
        "PPAM": "Perumahan Penjawat Awam Malaysia (PPAM)",
        "PR1MA": "PR1MA Homes",
        "RESIDENSIWILAYAH": "Residensi Wilayah",
        "SPNB": "Syarikat Perumahan Negara Berhad (SPNB)",
    }
    if prefix in mapping:
        return mapping[prefix]

    logo = clean_text(record.get("scheme_logo_url")) or ""
    for key, label in mapping.items():
        if key.lower() in logo.lower():
            return label
    return None


def build_state_lookup(filters_payload):
    states = filters_payload.get("states", []) if isinstance(filters_payload, dict) else []
    lookup = {}
    for state in states:
        name = clean_text(state.get("name")) if isinstance(state, dict) else None
        if name:
            lookup[name.upper()] = title_case(name)
    return lookup


def build_state_code_lookup(filters_payload):
    states = filters_payload.get("states", []) if isinstance(filters_payload, dict) else []
    lookup = {}
    for state in states:
        if not isinstance(state, dict):
            continue
        name = title_case(state.get("name"))
        code = clean_text(state.get("id")) or clean_text(state.get("value"))
        if name and code:
            lookup[name.lower()] = code
    return lookup


def split_location(location, state_lookup):
    text = clean_text(location)
    if text is None:
        return None, None

    upper = text.upper()
    if upper in state_lookup:
        return state_lookup[upper], None

    parts = [part.strip() for part in upper.split(",") if part.strip()]
    if len(parts) >= 2 and parts[-1] in state_lookup:
        district = title_case(parts[-2])
        return state_lookup[parts[-1]], district

    for official_upper, official_title in state_lookup.items():
        if upper.endswith(official_upper):
            before_state = upper[: -len(official_upper)].strip(" ,")
            district = title_case(before_state.split(",")[-1]) if before_state else None
            return official_title, district

    return title_case(text), None


def project_id(record, state):
    official_id = clean_text(record.get("id"))
    if official_id:
        return official_id

    stable_text = "|".join(
        item or ""
        for item in [
            clean_text(record.get("name")),
            clean_text(state),
            clean_text(record.get("location")),
        ]
    )
    digest = hashlib.sha1(stable_text.encode("utf-8")).hexdigest()[:10]
    slug = re.sub(r"[^a-z0-9]+", "-", stable_text.lower()).strip("-")[:60]
    return f"teduh-{slug}-{digest}"


def collect_prices(record):
    prices = []
    for unit in record.get("units") or []:
        if not isinstance(unit, dict):
            continue
        price = parse_number(unit.get("price_start")) or parse_number(unit.get("price_from_text"))
        if price is not None:
            prices.append(price)

    if not prices:
        price = parse_number(record.get("price_text"))
        if price is not None:
            prices.append(price)

    return (min(prices), max(prices)) if prices else (None, None)


def collect_unit_types(record):
    types = []
    seen = set()
    for unit in record.get("units") or []:
        if not isinstance(unit, dict):
            continue
        raw_type = clean_text(unit.get("house_type")) or clean_text(unit.get("unit_type"))
        if raw_type is None:
            continue
        key = raw_type.lower()
        if key not in seen:
            seen.add(key)
            types.append(raw_type)
    return types


def clean_project(record, state_lookup, retrieved_at, params):
    if not isinstance(record, dict):
        return None, "record is not an object"

    project_name = clean_text(record.get("name"))
    if not project_name:
        return None, "missing project name"

    state, district = split_location(record.get("location"), state_lookup)
    price_min, price_max = collect_prices(record)
    unit_types = collect_unit_types(record)
    developer = record.get("developer") if isinstance(record.get("developer"), dict) else {}
    source_id = project_id(record, state)

    return (
        {
            "source_id": source_id,
            "project_name": project_name,
            "state": state,
            "district": district,
            "scheme": normalise_scheme(record),
            "price_min": price_min,
            "price_max": price_max,
            "property_type": "; ".join(unit_types) if unit_types else None,
            "project_status": clean_text(record.get("status")),
            "developer_name": clean_text(developer.get("name")),
            "address": clean_text(record.get("address")),
            "source_url": source_url(params),
            "retrieved_at": retrieved_at,
            "latitude": parse_number(record.get("latitude")),
            "longitude": parse_number(record.get("longitude")),
            "total_units": parse_number(record.get("total_unit")),
            "available_units": parse_number(record.get("baki_unit")),
            "unit_types": unit_types,
            "external_project_url": clean_text(record.get("web_url")),
            "developer_address": clean_text(developer.get("full_address")),
            "raw_location": clean_text(record.get("location")),
        },
        None,
    )


def fetch_projects(max_records, delay_seconds, params):
    projects = []
    fetched = 0
    page = 1
    last_page = None

    while len(projects) < max_records:
        request_params = dict(params)
        request_params["page"] = page
        payload = request_json(PROJECTS_ENDPOINT, request_params)
        records = payload.get("data") if isinstance(payload, dict) else None

        if not isinstance(records, list):
            raise RuntimeError("Unexpected TEDUH projects response format: missing data list")

        fetched += len(records)
        projects.extend(records)

        last_page = payload.get("last_page", page) if isinstance(payload, dict) else page
        if not records or page >= int(last_page):
            break

        page += 1
        if len(projects) < max_records and delay_seconds > 0:
            time.sleep(delay_seconds)

    return projects[:max_records], fetched, last_page


def fetch_state_sample(state_name, state_code, max_per_state, delay_seconds):
    params = {"state": state_code or state_name}
    raw_records, fetched_count, last_page = fetch_projects(
        max_per_state,
        delay_seconds,
        params,
    )
    return raw_records, fetched_count, last_page, params


def dedupe_projects(records):
    deduped = []
    seen = set()
    duplicates = 0
    for record in records:
        source_id = record["source_id"]
        if source_id in seen:
            duplicates += 1
            continue
        seen.add(source_id)
        deduped.append(record)
    return deduped, duplicates


def csv_row(record):
    row = {}
    for field in CSV_FIELDS:
        value = record.get(field)
        if isinstance(value, list):
            row[field] = "; ".join(str(item) for item in value)
        elif value is None:
            row[field] = ""
        else:
            row[field] = value
    return row


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=True), encoding="utf-8")


def write_csv(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=CSV_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow(csv_row(row))


def quality_summary(records, duplicates_removed, skipped, requested_states):
    counts = {state: 0 for state in requested_states}
    for record in records:
        state = clean_text(record.get("state"))
        if state in counts:
            counts[state] += 1

    missing_coordinates = sum(
        1
        for record in records
        if record.get("latitude") is None or record.get("longitude") is None
    )
    missing_prices = sum(
        1
        for record in records
        if record.get("price_min") is None and record.get("price_max") is None
    )

    return {
        "total_records": len(records),
        "states_covered": sum(1 for count in counts.values() if count > 0),
        "states_requested": len(requested_states),
        "records_by_state": counts,
        "duplicates_removed": duplicates_removed,
        "records_skipped": len(skipped),
        "missing_coordinates": missing_coordinates,
        "missing_price_information": missing_prices,
    }


def print_quality_summary(summary):
    print(f"[TEDUH] Total records: {summary['total_records']}")
    print(
        f"[TEDUH] States covered: "
        f"{summary['states_covered']} / {summary['states_requested']}"
    )
    for state, count in summary["records_by_state"].items():
        print(f"[TEDUH] {state}: {count}")
    print(f"[TEDUH] Duplicate source IDs: {summary['duplicates_removed']}")
    print(f"[TEDUH] Missing coordinates: {summary['missing_coordinates']}")
    print(f"[TEDUH] Missing price information: {summary['missing_price_information']}")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Fetch a small public TEDUH housing/project sample into JSON and CSV."
    )
    parser.add_argument("--output", default="data/processed")
    parser.add_argument("--max-records", type=int, default=24)
    parser.add_argument("--max-per-state", type=int, default=10)
    parser.add_argument(
        "--sample-by-state",
        action="store_true",
        help="Collect up to --max-per-state records for each target Malaysian state.",
    )
    parser.add_argument("--delay-seconds", type=float, default=0.8)
    parser.add_argument("--name", default="")
    parser.add_argument("--state", default="", help="TEDUH state code, for example 10 for Selangor.")
    parser.add_argument("--scheme", default="", help="TEDUH scheme id, for example SPNB or PR1MA.")
    parser.add_argument("--price", default="", help="TEDUH price bucket id, if needed.")
    return parser.parse_args()


def main():
    args = parse_args()
    if args.max_records < 1:
        raise ValueError("--max-records must be at least 1")

    output = Path(args.output)
    retrieved_at = datetime.now(timezone.utc).isoformat()
    params = {
        key: value
        for key, value in {
            "name": clean_text(args.name),
            "state": clean_text(args.state),
            "scheme": clean_text(args.scheme),
            "price": clean_text(args.price),
        }.items()
        if value
    }

    print("[TEDUH] Fetching public project filters...")
    filters = request_json(FILTERS_ENDPOINT)
    state_lookup = build_state_lookup(filters)
    state_code_lookup = build_state_code_lookup(filters)

    print("[TEDUH] Fetching public project data...")
    state_fetch_report = {}
    if args.sample_by_state:
        raw_records = []
        fetched_count = 0
        last_page = None
        for state in TARGET_STATES:
            code = state_code_lookup.get(state.lower())
            print(f"[TEDUH] Fetching {state} sample...")
            state_records, state_fetched, state_last_page, state_params = fetch_state_sample(
                state,
                code,
                args.max_per_state,
                args.delay_seconds,
            )
            raw_records.extend(state_records)
            fetched_count += state_fetched
            last_page = state_last_page
            state_fetch_report[state] = {
                "state_code": code,
                "records_returned": len(state_records),
                "records_fetched_from_endpoint": state_fetched,
                "last_page_seen": state_last_page,
                "query": state_params,
            }
    else:
        raw_records, fetched_count, last_page = fetch_projects(
            args.max_records,
            args.delay_seconds,
            params,
        )
    print(f"[TEDUH] Retrieved {len(raw_records)} records from TEDUH pages")

    cleaned = []
    skipped = []
    for index, record in enumerate(raw_records, start=1):
        cleaned_record, reason = clean_project(record, state_lookup, retrieved_at, params)
        if cleaned_record is None:
            skipped.append({"index": index, "reason": reason})
            continue
        cleaned.append(cleaned_record)

    cleaned, duplicate_count = dedupe_projects(cleaned)
    cleaned.sort(
        key=lambda record: (
            clean_text(record.get("state")) or "",
            clean_text(record.get("source_id")) or "",
        )
    )
    print(f"[TEDUH] Cleaned {len(cleaned)} valid records")
    if skipped:
        print(f"[TEDUH] Skipped {len(skipped)} malformed records")
    if duplicate_count:
        print(f"[TEDUH] Removed {duplicate_count} duplicate records")

    if not cleaned:
        raise RuntimeError("TEDUH returned no usable project records")

    summary = quality_summary(
        cleaned,
        duplicate_count,
        skipped,
        TARGET_STATES if args.sample_by_state else sorted({record["state"] for record in cleaned if record.get("state")}),
    )
    print_quality_summary(summary)

    projects_json = output / "teduh_projects.json"
    projects_csv = output / "teduh_projects.csv"
    metadata_json = output / "teduh_data_source.json"

    write_json(projects_json, cleaned)
    write_csv(projects_csv, cleaned)
    write_json(
        metadata_json,
        {
            "source_name": "TEDUH - Jabatan Perumahan Negara, KPKT",
            "source_url": PROJECTS_PAGE,
            "api_endpoint": PROJECTS_ENDPOINT,
            "filters_endpoint": FILTERS_ENDPOINT,
            "method": "public JSON API used by the TEDUH /projek page",
            "authentication_required": False,
            "retrieved_at": retrieved_at,
            "record_count": len(cleaned),
            "records_requested": args.max_records,
            "records_fetched_from_endpoint": fetched_count,
            "records_skipped": len(skipped),
            "duplicates_removed": duplicate_count,
            "last_page_seen": last_page,
            "crawler_version": CRAWLER_VERSION,
            "query": params,
            "sampling": {
                "sample_by_state": args.sample_by_state,
                "max_per_state": args.max_per_state if args.sample_by_state else None,
                "target_states": TARGET_STATES if args.sample_by_state else None,
                "state_fetch_report": state_fetch_report,
            },
            "quality_summary": summary,
        },
    )

    print(f"[TEDUH] Saved {projects_json}")
    print(f"[TEDUH] Saved {projects_csv}")
    print(f"[TEDUH] Saved {metadata_json}")


if __name__ == "__main__":
    main()
