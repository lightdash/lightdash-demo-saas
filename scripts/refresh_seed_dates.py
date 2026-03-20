#!/usr/bin/env python3
"""
Shift all dates in seed CSV files forward so the most recent data is near today.

Usage:
    python scripts/refresh_seed_dates.py              # shift so newest data ≈ today
    python scripts/refresh_seed_dates.py --target-date 2026-09-20  # shift to a specific date
    python scripts/refresh_seed_dates.py --dry-run     # preview without writing

The script finds the global maximum date across all seed files, computes the
offset needed to move it to the target date, and applies that same offset to
every date/timestamp in every file. This preserves all relative timing between
records.
"""

from __future__ import annotations

import argparse
import csv
import os
import re
from datetime import datetime, timedelta
from pathlib import Path

SEEDS_DIR = Path(__file__).resolve().parent.parent / "seeds"

# Map of filename -> list of date/timestamp columns
FILE_DATE_COLUMNS = {
    "deals_raw.csv": ["created_date"],
    "activities_raw.csv": ["activity_timestamp"],
    "marketing_leads.csv": ["created_at", "converted_at"],
    "users_raw.csv": ["created_at", "first_logged_in_at", "latest_logged_in_at"],
    "tracks_raw.csv": ["event_timestamp"],
}

# Supported datetime formats (tried in order)
DATETIME_FORMATS = [
    "%Y-%m-%d %H:%M:%S.%f",
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d",
]


def parse_dt(value: str) -> datetime | None:
    """Parse a datetime string, returning None for empty/null values."""
    if not value or value.strip() == "":
        return None
    for fmt in DATETIME_FORMATS:
        try:
            return datetime.strptime(value.strip(), fmt)
        except ValueError:
            continue
    return None


def format_dt(dt: datetime, original: str) -> str:
    """Format a datetime back to the same format as the original string."""
    original = original.strip()
    if "." in original:
        return dt.strftime("%Y-%m-%d %H:%M:%S.%f")
    elif " " in original:
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    else:
        return dt.strftime("%Y-%m-%d")


def find_global_max_date() -> datetime:
    """Find the maximum date across all seed files."""
    global_max = datetime.min
    for filename, columns in FILE_DATE_COLUMNS.items():
        filepath = SEEDS_DIR / filename
        if not filepath.exists():
            print(f"  WARNING: {filename} not found, skipping")
            continue
        with open(filepath, "r") as f:
            reader = csv.DictReader(f)
            for row in reader:
                for col in columns:
                    dt = parse_dt(row.get(col, ""))
                    if dt and dt > global_max:
                        global_max = dt
    return global_max


def shift_file(filename: str, columns: list[str], offset: timedelta, dry_run: bool):
    """Shift all date columns in a file by the given offset."""
    filepath = SEEDS_DIR / filename
    if not filepath.exists():
        print(f"  SKIP: {filename} not found")
        return

    # Read all rows
    with open(filepath, "r") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)

    dates_shifted = 0
    for row in rows:
        for col in columns:
            original = row.get(col, "")
            dt = parse_dt(original)
            if dt:
                new_dt = dt + offset
                row[col] = format_dt(new_dt, original)
                dates_shifted += 1

        # Also update 'year' column if it exists (marketing_leads.csv)
        if "year" in row and row["year"]:
            for col in columns:
                dt = parse_dt(row.get(col, ""))
                if dt:
                    row["year"] = str(dt.year)
                    break

    if dry_run:
        print(f"  {filename}: would shift {dates_shifted} date values")
    else:
        with open(filepath, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)
        print(f"  {filename}: shifted {dates_shifted} date values")


def main():
    parser = argparse.ArgumentParser(description="Refresh seed data dates")
    parser.add_argument(
        "--target-date",
        type=str,
        default=None,
        help="Target date for the newest data (YYYY-MM-DD). Defaults to today.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview changes without writing files.",
    )
    args = parser.parse_args()

    target = datetime.strptime(args.target_date, "%Y-%m-%d") if args.target_date else datetime.now()
    # Set target to end of day so data feels current
    target = target.replace(hour=23, minute=59, second=59)

    print("Finding global max date across all seed files...")
    global_max = find_global_max_date()
    print(f"  Global max date: {global_max}")
    print(f"  Target date:     {target}")

    offset = target - global_max
    print(f"  Offset to apply: {offset.days} days")

    if offset.days <= 0:
        print("\nData is already current (or ahead of target). Nothing to do.")
        return

    print(f"\n{'DRY RUN - ' if args.dry_run else ''}Shifting dates in seed files...")
    for filename, columns in FILE_DATE_COLUMNS.items():
        shift_file(filename, columns, offset, args.dry_run)

    print("\nDone!" + (" (dry run, no files changed)" if args.dry_run else ""))
    if not args.dry_run:
        print(f"\nNext steps:")
        print(f"  1. Review changes: git diff seeds/")
        print(f"  2. Run dbt seed to load updated data")
        print(f"  3. Commit and push")


if __name__ == "__main__":
    main()
