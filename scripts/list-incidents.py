#!/usr/bin/env python3
"""Query incidents database."""

from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "data" / "incidents.sqlite"


def main() -> int:
    parser = argparse.ArgumentParser(description="List incidents from data/incidents.sqlite")
    parser.add_argument("--key", help="Filter by incident_key")
    parser.add_argument("--status", help="Filter by status (open/partial/resolved)")
    parser.add_argument("--events", action="store_true", help="Show timeline events")
    args = parser.parse_args()

    if not DB_PATH.is_file():
        print(f"DB not found: {DB_PATH}. Run scripts/init-incidents-db.py first.")
        return 1

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    query = "SELECT * FROM incidents WHERE 1=1"
    params: list[str] = []
    if args.key:
        query += " AND incident_key = ?"
        params.append(args.key)
    if args.status:
        query += " AND status = ?"
        params.append(args.status)
    query += " ORDER BY updated_at DESC"

    rows = conn.execute(query, params).fetchall()
    if not rows:
        print("No incidents found.")
        return 0

    for row in rows:
        print(f"\n[{row['id']}] {row['incident_key']} ({row['status']})")
        print(f"  title: {row['title']}")
        print(f"  component: {row['component']}  severity: {row['severity']}")
        print(f"  updated: {row['updated_at']}")
        if args.events:
            events = conn.execute(
                "SELECT event_at, event_type, detail FROM incident_events WHERE incident_id = ? ORDER BY event_at",
                (row["id"],),
            ).fetchall()
            for ev in events:
                print(f"    - {ev['event_at']} [{ev['event_type']}] {ev['detail']}")

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
