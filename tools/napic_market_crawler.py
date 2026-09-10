#!/usr/bin/env python3
"""Crawl official NAPIC XLSX publications and upsert district market snapshots.

Required environment variables:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY

The crawler never invents missing values. A source or district that cannot be
parsed is reported and skipped without discarding successful districts.
"""

from __future__ import annotations

import io
import json
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Iterable
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup
from openpyxl import load_workbook

PUBLICATIONS_URL = "https://napic.jpph.gov.my/en/latest-publication"
ARCHIVED_PRICE_URLS = (
    "https://napic.jpph.gov.my/storage/app/media//3-penerbitan/Shahrul/"
    "Bahagian%20Pasaran%20Harta%20Tanah/Harga%20Kediaman%20Sukuan/"
    "Q3%202025/Jadual%20Harga%20Kediaman%20Sukuan%20Tahunan%20Q3_2025.xlsx",
    "https://napic.jpph.gov.my/storage/app/media//3-penerbitan/Shahrul/"
    "Bahagian%20Pasaran%20Harta%20Tanah/Harga%20Kediaman%20Sukuan/"
    "Q4%202025/Jadual%20Harga%20Kediaman%20Sukuan%20Tahunan%20Q4%202025.xlsx",
)
SUPPORTED_DISTRICTS = {
    "Selangor": (
        "Petaling", "Klang", "Gombak", "Ulu Langat", "Ulu Selangor",
        "Kuala Langat", "Kuala Selangor", "Sabak Bernam", "Sepang",
    ),
    "Johor": (
        "Batu Pahat", "Johor Bahru", "Kluang", "Kota Tinggi", "Kulai",
        "Mersing", "Muar", "Pontian", "Segamat", "Tangkak",
    ),
    "Pulau Pinang": (
        "Barat Daya", "Seberang Perai Selatan", "Seberang Perai Tengah",
        "Seberang Perai Utara", "Timur Laut",
    ),
    "Perak": (
        "Bagan Datuk", "Batang Padang", "Hilir Perak", "Hulu Perak",
        "Kampar", "Kerian", "Kinta", "Kuala Kangsar",
        "Larut Dan Matang", "Manjung", "Muallim", "Perak Tengah", "Selama",
    ),
    "Negeri Sembilan": (
        "Jelebu", "Jempol", "Kuala Pilah", "Port Dickson", "Rembau",
        "Seremban", "Tampin",
    ),
    "Melaka": ("Alor Gajah", "Jasin", "Melaka Tengah"),
    "Kedah": (
        "Baling", "Bandar Baharu", "Kota Setar", "Kuala Muda",
        "Kubang Pasu", "Kulim", "Langkawi", "Padang Terap", "Pendang",
        "Pokok Sena", "Sik", "Yan",
    ),
    "Pahang": (
        "Bentong", "Bera", "Cameron Highlands", "Jerantut", "Kuantan",
        "Lipis", "Maran", "Pekan", "Raub", "Rompin", "Temerloh",
    ),
    "Terengganu": (
        "Besut", "Dungun", "Hulu Terengganu", "Kemaman", "Kuala Nerus",
        "Kuala Terengganu", "Marang", "Setiu",
    ),
    "Kelantan": (
        "Bachok", "Gua Musang", "Jeli", "Kota Bharu", "Kuala Krai",
        "Machang", "Pasir Mas", "Pasir Puteh", "Tanah Merah", "Tumpat",
    ),
    "Perlis": ("Perlis",),
    "Sabah": (
        "Beaufort", "Keningau", "Kinabatangan", "Kota Belud",
        "Kota Kinabalu", "Kota Marudu", "Kudat", "Kunak", "Lahad Datu",
        "Papar", "Penampang", "Pitas", "Putatan", "Ranau", "Sandakan",
        "Semporna", "Sipitang", "Tambunan", "Tawau", "Tenom", "Tuaran",
    ),
    "Sarawak": (
        "Betong", "Bintulu", "Kapit", "Kuching", "Limbang", "Miri",
        "Mukah", "Samarahan", "Sarikei", "Serian", "Sibu", "Sri Aman",
    ),
    "W.P. Kuala Lumpur": ("W.P. Kuala Lumpur",),
    "W.P. Putrajaya": ("W.P. Putrajaya",),
    "W.P. Labuan": ("W.P. Labuan",),
}
TARGETS = tuple(
    (state, district)
    for state, districts in SUPPORTED_DISTRICTS.items()
    for district in districts
)
PUBLICATION_STATE_NAMES = {
    "Pulau Pinang": "Penang",
    "W.P. Kuala Lumpur": "WP Kuala Lumpur",
    "W.P. Putrajaya": "WP Putrajaya",
    "W.P. Labuan": "WP Labuan",
}
WORKBOOK_SHEETS = {
    "Pulau Pinang": "PPinang",
    "W.P. Kuala Lumpur": "WP Kuala Lumpur",
    "W.P. Putrajaya": "WP Putrajaya",
    "W.P. Labuan": "WP Labuan",
}
DISTRICT_ALIASES = {
    "Ulu Langat": "Hulu Langat",
    "Ulu Selangor": "Hulu Selangor",
    "Larut Dan Matang": "Larut Matang",
    "W.P. Kuala Lumpur": "WP Kuala Lumpur",
    "W.P. Putrajaya": "WP Putrajaya",
    "W.P. Labuan": "WP Labuan",
}
MARKET_AREAS_BY_DISTRICT = {
    ("W.P. Kuala Lumpur", "W.P. Kuala Lumpur"): (
        "Ampang",
        "Batu",
        "Cheras",
        "Kuala Lumpur Town Centre",
        "Petaling",
        "Setapak",
        "Ulu Kelang",
    ),
}
TIMEOUT = 90


@dataclass(frozen=True)
class TransactionSnapshot:
    period: str
    count: int
    previous_count: int
    value_million: float
    previous_value_million: float


def normalise(value: object) -> str:
    return re.sub(r"[^a-z0-9]+", " ", str(value or "").lower()).strip()


def area_id(state: str, district: str) -> str:
    return f"{normalise(state).replace(' ', '_')}_{normalise(district).replace(' ', '_')}"


def get_bytes(session: requests.Session, url: str) -> bytes:
    response = session.get(url, timeout=TIMEOUT)
    response.raise_for_status()
    return response.content


def discover_workbooks(session: requests.Session) -> tuple[str, dict[str, str]]:
    response = session.get(PUBLICATIONS_URL, timeout=TIMEOUT)
    response.raise_for_status()
    soup = BeautifulSoup(response.text, "html.parser")
    links = {
        " ".join(link.get_text(" ", strip=True).split()): urljoin(
            PUBLICATIONS_URL, link.get("href", "")
        )
        for link in soup.select("a[href]")
    }
    price_url = next(
        (url for text, url in links.items() if "Quarterly Residential Price Tables" in text),
        None,
    )
    if not price_url:
        raise RuntimeError("NAPIC quarterly residential price workbook was not found.")

    transaction_urls: dict[str, str] = {}
    for state, _ in TARGETS:
        publication_state = normalise(
            PUBLICATION_STATE_NAMES.get(state, state)
        )
        pattern = re.compile(
            rf"\\bjadual transaksi harta tanah "
            rf"{re.escape(publication_state)} q[1-4] \\d{{4}}\\b",
        )
        url = next(
            (
                url
                for text, url in links.items()
                if pattern.search(normalise(text))
            ),
            None,
        )
        if url:
            transaction_urls[state] = url
    return price_url, transaction_urls


def workbook(content: bytes):
    return load_workbook(io.BytesIO(content), read_only=True, data_only=True)


def publication_period(ws) -> str:
    for row in ws.iter_rows(min_row=1, max_row=4, values_only=True):
        text = " ".join(str(value) for value in row if value is not None)
        match = re.search(r"Q([1-4])\s+(20\d{2})", text, re.IGNORECASE)
        if match:
            return f"{match.group(2)}-Q{match.group(1)}"
    raise RuntimeError(f"Cannot determine publication period from {ws.title}.")


def _district_price_snapshot(ws, source_district: str):
    weighted_sum = 0.0
    sample_sum = 0
    property_type = None
    type_weighted_sums: dict[str, float] = {}
    type_sample_sums: dict[str, int] = {}
    for row in ws.iter_rows(min_row=6, values_only=True):
        if row[0]:
            property_type = str(row[0]).strip()
        district = normalise(row[1] if len(row) > 1 else None)
        if district != normalise(source_district) or not property_type:
            continue
        median = row[5] if len(row) > 5 else None
        sample = row[8] if len(row) > 8 else None
        if (
            isinstance(median, (int, float))
            and isinstance(sample, (int, float))
            and sample > 0
        ):
            sample_count = int(sample)
            weighted_sum += float(median) * sample_count
            sample_sum += sample_count
            type_weighted_sums[property_type] = (
                type_weighted_sums.get(property_type, 0.0)
                + float(median) * sample_count
            )
            type_sample_sums[property_type] = (
                type_sample_sums.get(property_type, 0) + sample_count
            )
    if not sample_sum:
        return None
    prices_by_type = {
        property_type: round(weighted / type_sample_sums[property_type], 2)
        for property_type, weighted in type_weighted_sums.items()
        if type_sample_sums[property_type] > 0
    }
    aggregate = round(weighted_sum / sample_sum, 2)
    return aggregate, prices_by_type, sample_sum, type_sample_sums


def price_indicators(content: bytes, targets: Iterable[tuple[str, str]]):
    book = workbook(content)
    results = {}
    for state, display_district in targets:
        sheet_name = WORKBOOK_SHEETS.get(state, state)
        if sheet_name not in book.sheetnames:
            continue
        ws = book[sheet_name]
        period = publication_period(ws)
        source_district = DISTRICT_ALIASES.get(display_district, display_district)
        overall = _district_price_snapshot(ws, source_district)
        prices_by_market_area = {}
        market_snapshots = []
        for market_area in MARKET_AREAS_BY_DISTRICT.get(
            (state, display_district), ()
        ):
            market_snapshot = _district_price_snapshot(ws, market_area)
            if market_snapshot is None:
                continue
            (
                market_aggregate,
                market_types,
                market_sample_count,
                market_type_samples,
            ) = market_snapshot
            prices_by_market_area[market_area] = {
                "All residential": market_aggregate,
                **market_types,
            }
            market_snapshots.append(
                (
                    market_aggregate,
                    market_types,
                    market_sample_count,
                    market_type_samples,
                )
            )

        if overall is not None:
            aggregate, prices_by_type, _, _ = overall
        elif market_snapshots:
            total_samples = sum(
                sample_count
                for _, _, sample_count, _ in market_snapshots
            )
            aggregate = round(
                sum(
                    value * sample_count
                    for value, _, sample_count, _ in market_snapshots
                )
                / total_samples,
                2,
            )
            type_weighted_sums = {}
            type_sample_sums = {}
            for _, market_types, _, market_type_samples in market_snapshots:
                for property_type, value in market_types.items():
                    sample_count = market_type_samples.get(property_type, 0)
                    if sample_count <= 0:
                        continue
                    type_weighted_sums[property_type] = (
                        type_weighted_sums.get(property_type, 0.0)
                        + value * sample_count
                    )
                    type_sample_sums[property_type] = (
                        type_sample_sums.get(property_type, 0)
                        + sample_count
                    )
            prices_by_type = {
                property_type: round(
                    weighted_sum / type_sample_sums[property_type],
                    2,
                )
                for property_type, weighted_sum
                in type_weighted_sums.items()
                if type_sample_sums[property_type] > 0
            }
        else:
            continue

        results[(state, display_district)] = (
            period,
            aggregate,
            prices_by_type,
            prices_by_market_area,
        )
    return results


def _transaction_table(ws, district: str) -> tuple[list[str], list[float]]:
    header_row = None
    district_column = None
    for row_index, row in enumerate(ws.iter_rows(values_only=True), 1):
        values = [normalise(value) for value in row]
        if "quarter" in values and normalise(district) in values:
            header_row = row_index
            district_column = values.index(normalise(district)) + 1
            break
    if header_row is None or district_column is None:
        raise RuntimeError(f"{district} column is missing from sheet {ws.title}.")

    periods = []
    for row_index in range(header_row + 1, min(ws.max_row, header_row + 10) + 1):
        value = ws.cell(row_index, 2).value
        if value:
            periods.append(str(value).strip())
        if len(periods) == 3:
            break
    if len(periods) != 3:
        raise RuntimeError(f"Quarter labels are missing from sheet {ws.title}.")

    total_row = next(
        (
            row_index
            for row_index in range(header_row + 1, ws.max_row + 1)
            if normalise(ws.cell(row_index, 1).value) == "total"
        ),
        None,
    )
    if total_row is None:
        raise RuntimeError(f"Total rows are missing from sheet {ws.title}.")
    values = [
        float(ws.cell(total_row + offset, district_column).value)
        for offset in range(3)
    ]
    return periods, values


def transaction_indicators(content: bytes, targets: Iterable[str]):
    book = workbook(content)
    count_sheet = next((book[name] for name in book.sheetnames if name.endswith(".5")), None)
    value_sheet = next((book[name] for name in book.sheetnames if name.endswith(".6")), None)
    if count_sheet is None or value_sheet is None:
        raise RuntimeError("Residential transaction count/value sheets were not found.")

    results = {}
    for display_district in targets:
        source_district = DISTRICT_ALIASES.get(display_district, display_district)
        try:
            count_periods, counts = _transaction_table(count_sheet, source_district)
            value_periods, values = _transaction_table(value_sheet, source_district)
            if count_periods != value_periods:
                raise RuntimeError("Count and value periods do not match.")
            latest_label = count_periods[-1]
            latest_match = re.search(r"Q([1-4])\s+(20\d{2})", latest_label)
            if not latest_match:
                raise RuntimeError(f"Unsupported quarter label: {latest_label}")
            previous_label = f"Q{latest_match.group(1)} {int(latest_match.group(2)) - 1}"
            previous_index = next(
                (
                    index
                    for index, label in enumerate(count_periods)
                    if normalise(label).startswith(normalise(previous_label))
                ),
                None,
            )
            if previous_index is None:
                raise RuntimeError(f"Previous-year period {previous_label} is missing.")
            results[display_district] = TransactionSnapshot(
                period=f"{latest_match.group(2)}-Q{latest_match.group(1)}",
                count=round(counts[-1]),
                previous_count=round(counts[previous_index]),
                value_million=round(values[-1], 6),
                previous_value_million=round(values[previous_index], 6),
            )
        except Exception as error:
            print(f"warning: transaction data skipped for {display_district}: {error}", file=sys.stderr)
    return results


def existing_history(
    session: requests.Session,
    state: str,
    district: str,
    supabase_headers: dict[str, str],
):
    url = f"{os.environ['SUPABASE_URL'].rstrip('/')}/rest/v1/area_profiles"
    response = session.get(
        url,
        params={
            "area_id": f"eq.{area_id(state, district)}",
            "select": (
                "market_price_periods,market_price_history,"
                "market_price_periods_by_type,market_price_history_by_type,"
                "market_area_price_periods_by_type,"
                "market_area_price_history_by_type"
            ),
            "limit": "1",
        },
        headers=supabase_headers,
        timeout=TIMEOUT,
    )
    response.raise_for_status()
    rows = response.json()
    if not rows:
        return [], [], {}, {}, {}, {}
    row = rows[0]
    periods_by_type = {
        str(key): [str(period) for period in value]
        for key, value in (row.get("market_price_periods_by_type") or {}).items()
        if isinstance(value, list)
    }
    history_by_type = {
        str(key): [float(number) for number in value]
        for key, value in (row.get("market_price_history_by_type") or {}).items()
        if isinstance(value, list)
    }
    market_area_periods = {
        str(market_area): {
            str(property_type): [str(period) for period in values]
            for property_type, values in property_types.items()
            if isinstance(values, list)
        }
        for market_area, property_types in (
            row.get("market_area_price_periods_by_type") or {}
        ).items()
        if isinstance(property_types, dict)
    }
    market_area_history = {
        str(market_area): {
            str(property_type): [float(number) for number in values]
            for property_type, values in property_types.items()
            if isinstance(values, list)
        }
        for market_area, property_types in (
            row.get("market_area_price_history_by_type") or {}
        ).items()
        if isinstance(property_types, dict)
    }
    return (
        list(row.get("market_price_periods") or []),
        [float(value) for value in row.get("market_price_history") or []],
        periods_by_type,
        history_by_type,
        market_area_periods,
        market_area_history,
    )


def merge_history(periods: list[str], values: list[float], period: str, value: float):
    merged = {key: number for key, number in zip(periods, values)}
    merged[period] = value
    ordered = sorted(merged)
    return ordered, [merged[key] for key in ordered]


def merge_type_history(
    periods_by_type: dict[str, list[str]],
    history_by_type: dict[str, list[float]],
    period: str,
    prices_by_type: dict[str, float],
):
    merged_periods = {key: list(value) for key, value in periods_by_type.items()}
    merged_history = {key: list(value) for key, value in history_by_type.items()}
    for property_type, price in prices_by_type.items():
        periods, history = merge_history(
            merged_periods.get(property_type, []),
            merged_history.get(property_type, []),
            period,
            price,
        )
        merged_periods[property_type] = periods
        merged_history[property_type] = history
    return merged_periods, merged_history


def merge_market_area_history(
    periods_by_area: dict[str, dict[str, list[str]]],
    history_by_area: dict[str, dict[str, list[float]]],
    period: str,
    prices_by_area: dict[str, dict[str, float]],
):
    merged_periods = {
        market_area: {
            property_type: list(values)
            for property_type, values in property_types.items()
        }
        for market_area, property_types in periods_by_area.items()
    }
    merged_history = {
        market_area: {
            property_type: list(values)
            for property_type, values in property_types.items()
        }
        for market_area, property_types in history_by_area.items()
    }
    for market_area, prices_by_type in prices_by_area.items():
        area_periods, area_history = merge_type_history(
            merged_periods.get(market_area, {}),
            merged_history.get(market_area, {}),
            period,
            prices_by_type,
        )
        merged_periods[market_area] = area_periods
        merged_history[market_area] = area_history
    return merged_periods, merged_history


def write_snapshots(
    session: requests.Session,
    rows: list[dict],
    supabase_headers: dict[str, str],
):
    if not rows:
        raise RuntimeError("No NAPIC district records were produced.")
    url = f"{os.environ['SUPABASE_URL'].rstrip('/')}/rest/v1/area_profiles"
    for row in rows:
        payload = dict(row)
        record_id = payload.pop("area_id")
        response = session.patch(
            url,
            params={"area_id": f"eq.{record_id}"},
            json=payload,
            headers={
                **supabase_headers,
                "Prefer": "return=minimal",
            },
            timeout=TIMEOUT,
        )
        if not response.ok:
            raise RuntimeError(
                f"NAPIC snapshot write failed for {record_id} "
                f"({response.status_code}): {response.text[:2000]}"
            )


def main():
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not os.environ.get("SUPABASE_URL") or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.")

    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": "SmartPropertyAdvisor-NAPIC-Crawler/1.0",
        }
    )
    supabase_headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
    }
    price_url, transaction_urls = discover_workbooks(session)
    price_series: dict[tuple[str, str], dict[str, float]] = {}
    price_series_by_type: dict[
        tuple[str, str], dict[str, dict[str, float]]
    ] = {}
    price_series_by_market_area: dict[
        tuple[str, str], dict[str, dict[str, dict[str, float]]]
    ] = {}
    successful_price_urls = []
    for candidate_url in (*ARCHIVED_PRICE_URLS, price_url):
        try:
            snapshot = price_indicators(get_bytes(session, candidate_url), TARGETS)
            successful_price_urls.append(candidate_url)
            for (
                location,
                (period, value, prices_by_type, prices_by_market_area),
            ) in snapshot.items():
                price_series.setdefault(location, {})[period] = value
                location_types = price_series_by_type.setdefault(location, {})
                for property_type, type_price in prices_by_type.items():
                    location_types.setdefault(property_type, {})[period] = type_price
                location_areas = price_series_by_market_area.setdefault(
                    location, {}
                )
                for market_area, market_types in prices_by_market_area.items():
                    area_types = location_areas.setdefault(market_area, {})
                    for property_type, type_price in market_types.items():
                        area_types.setdefault(property_type, {})[period] = type_price
        except Exception as error:
            print(
                f"warning: price workbook skipped ({candidate_url}): {error}",
                file=sys.stderr,
            )
    retrieved_at = datetime.now(timezone.utc).isoformat()
    rows = []

    for state in sorted({state for state, _ in TARGETS}):
        state_targets = [
            district
            for target_state, district in TARGETS
            if target_state == state
        ]
        transaction_url = transaction_urls.get(state)
        transactions = {}
        if not transaction_url:
            print(
                f"warning: transaction workbook not found for {state}",
                file=sys.stderr,
            )
        else:
            try:
                transactions = transaction_indicators(
                    get_bytes(session, transaction_url), state_targets
                )
            except Exception as error:
                print(
                    f"warning: transaction workbook skipped for {state}: {error}",
                    file=sys.stderr,
                )

        for district in state_targets:
            price_points = price_series.get((state, district))
            transaction = transactions.get(district)
            if not price_points and not transaction:
                print(
                    f"warning: no processed NAPIC data for {district}, {state}",
                    file=sys.stderr,
                )
                continue

            row = {
                "area_id": area_id(state, district),
                "state": state,
                "district": district,
                "market_retrieved_at": retrieved_at,
            }

            if price_points:
                price_period = max(price_points)
                price_value = price_points[price_period]
                (
                    periods,
                    history,
                    periods_by_type,
                    history_by_type,
                    market_area_periods,
                    market_area_history,
                ) = existing_history(
                    session,
                    state,
                    district,
                    supabase_headers,
                )
                for historic_period, historic_value in price_points.items():
                    periods, history = merge_history(
                        periods,
                        history,
                        historic_period,
                        historic_value,
                    )
                for property_type, type_points in price_series_by_type.get(
                    (state, district), {}
                ).items():
                    for historic_period, historic_value in type_points.items():
                        periods_by_type, history_by_type = merge_type_history(
                            periods_by_type,
                            history_by_type,
                            historic_period,
                            {property_type: historic_value},
                        )
                for market_area, market_types in price_series_by_market_area.get(
                    (state, district), {}
                ).items():
                    for property_type, type_points in market_types.items():
                        for historic_period, historic_value in type_points.items():
                            (
                                market_area_periods,
                                market_area_history,
                            ) = merge_market_area_history(
                                market_area_periods,
                                market_area_history,
                                historic_period,
                                {
                                    market_area: {
                                        property_type: historic_value,
                                    },
                                },
                            )
                row.update(
                    {
                        "market_price_periods": periods,
                        "market_price_history": history,
                        "market_price_periods_by_type": periods_by_type,
                        "market_price_history_by_type": history_by_type,
                        "market_area_price_periods_by_type": market_area_periods,
                        "market_area_price_history_by_type": market_area_history,
                        "median_residential_price": price_value,
                        "market_price_year": int(price_period[:4]),
                    }
                )

            if transaction:
                row.update(
                    {
                        "transaction_count": transaction.count,
                        "previous_transaction_count": transaction.previous_count,
                        "transaction_value_million": transaction.value_million,
                        "previous_transaction_value_million": (
                            transaction.previous_value_million
                        ),
                        "market_period": transaction.period,
                    }
                )

            source_urls = list(successful_price_urls)
            if transaction_url:
                source_urls.append(transaction_url)
            row["market_source_url"] = "; ".join(source_urls)
            rows.append(row)

    write_snapshots(session, rows, supabase_headers)
    print(json.dumps({"updated": len(rows), "districts": [row["area_id"] for row in rows]}))


if __name__ == "__main__":
    main()
