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
TARGETS = (
    ("Selangor", "Petaling"),
    ("Selangor", "Gombak"),
    ("Selangor", "Hulu Langat"),
    ("Johor", "Johor Bahru"),
    ("Pulau Pinang", "Timur Laut"),
)
PUBLICATION_STATE_NAMES = {"Pulau Pinang": "Penang"}
WORKBOOK_SHEETS = {"Pulau Pinang": "PPinang"}
DISTRICT_ALIASES = {"Ulu Langat": "Hulu Langat"}
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
        publication_state = PUBLICATION_STATE_NAMES.get(state, state)
        pattern = re.compile(
            rf"Jadual Transaksi Harta Tanah {re.escape(publication_state)} Q[1-4] \d{{4}}",
            re.IGNORECASE,
        )
        url = next((url for text, url in links.items() if pattern.search(text)), None)
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
        weighted_sum = 0.0
        sample_sum = 0
        property_type = None
        for row in ws.iter_rows(min_row=6, values_only=True):
            if row[0]:
                property_type = str(row[0]).strip()
            district = normalise(row[1] if len(row) > 1 else None)
            if district != normalise(source_district) or not property_type:
                continue
            median = row[5] if len(row) > 5 else None
            sample = row[8] if len(row) > 8 else None
            if isinstance(median, (int, float)) and isinstance(sample, (int, float)) and sample > 0:
                weighted_sum += float(median) * int(sample)
                sample_sum += int(sample)
        if sample_sum:
            results[(state, display_district)] = (
                period,
                round(weighted_sum / sample_sum, 2),
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


def existing_history(session: requests.Session, state: str, district: str):
    url = f"{os.environ['SUPABASE_URL'].rstrip('/')}/rest/v1/area_profiles"
    response = session.get(
        url,
        params={
            "area_id": f"eq.{area_id(state, district)}",
            "select": "market_price_periods,market_price_history",
            "limit": "1",
        },
        timeout=TIMEOUT,
    )
    response.raise_for_status()
    rows = response.json()
    if not rows:
        return [], []
    return (
        list(rows[0].get("market_price_periods") or []),
        [float(value) for value in rows[0].get("market_price_history") or []],
    )


def merge_history(periods: list[str], values: list[float], period: str, value: float):
    merged = {key: number for key, number in zip(periods, values)}
    merged[period] = value
    ordered = sorted(merged)
    return ordered, [merged[key] for key in ordered]


def upsert(session: requests.Session, rows: list[dict]):
    if not rows:
        raise RuntimeError("No complete NAPIC district records were produced.")
    url = f"{os.environ['SUPABASE_URL'].rstrip('/')}/rest/v1/area_profiles"
    response = session.post(
        url,
        params={"on_conflict": "area_id"},
        json=rows,
        headers={"Prefer": "resolution=merge-duplicates,return=minimal"},
        timeout=TIMEOUT,
    )
    response.raise_for_status()


def main():
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not os.environ.get("SUPABASE_URL") or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.")

    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": "SmartPropertyAdvisor-NAPIC-Crawler/1.0",
            "apikey": key,
            "Authorization": f"Bearer {key}",
        }
    )
    price_url, transaction_urls = discover_workbooks(session)
    prices = price_indicators(get_bytes(session, price_url), TARGETS)
    retrieved_at = datetime.now(timezone.utc).isoformat()
    rows = []

    for state in sorted({state for state, _ in TARGETS}):
        state_targets = [district for target_state, district in TARGETS if target_state == state]
        transaction_url = transaction_urls.get(state)
        if not transaction_url:
            print(f"warning: transaction workbook not found for {state}", file=sys.stderr)
            continue
        try:
            transactions = transaction_indicators(
                get_bytes(session, transaction_url), state_targets
            )
        except Exception as error:
            print(f"warning: transaction workbook skipped for {state}: {error}", file=sys.stderr)
            continue

        for district in state_targets:
            price = prices.get((state, district))
            transaction = transactions.get(district)
            if not price or not transaction:
                print(f"warning: incomplete market data skipped for {district}, {state}", file=sys.stderr)
                continue
            price_period, price_value = price
            periods, history = existing_history(session, state, district)
            periods, history = merge_history(periods, history, price_period, price_value)
            rows.append(
                {
                    "area_id": area_id(state, district),
                    "state": state,
                    "district": district,
                    "market_price_periods": periods,
                    "market_price_history": history,
                    "median_residential_price": price_value,
                    "market_price_year": int(price_period[:4]),
                    "transaction_count": transaction.count,
                    "previous_transaction_count": transaction.previous_count,
                    "transaction_value_million": transaction.value_million,
                    "previous_transaction_value_million": transaction.previous_value_million,
                    "market_period": transaction.period,
                    "market_source_url": f"{price_url}; {transaction_url}",
                    "market_retrieved_at": retrieved_at,
                }
            )

    upsert(session, rows)
    print(json.dumps({"updated": len(rows), "districts": [row["area_id"] for row in rows]}))


if __name__ == "__main__":
    main()
