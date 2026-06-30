#!/usr/bin/env python3
"""List registry DB contents."""

from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "data" / "registry.sqlite"


def main() -> None:
    parser = argparse.ArgumentParser(description="List project registry")
    parser.add_argument("--scripts", action="store_true")
    parser.add_argument("--skills", action="store_true")
    parser.add_argument("--ops", action="store_true", help="Recent op_log sections")
    parser.add_argument("--routing", action="store_true")
    parser.add_argument("--lessons", action="store_true")
    parser.add_argument("--limit", type=int, default=30)
    args = parser.parse_args()

    if not DB_PATH.exists():
        print(f"Missing {DB_PATH}; run: python scripts/init-registry-db.py")
        return

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    show_all = not (args.scripts or args.skills or args.ops or args.routing or args.lessons)

    if show_all or args.scripts:
        print("=== scripts (active) ===")
        for row in conn.execute(
            "SELECT name, path, category, status FROM scripts WHERE status='active' ORDER BY category, name LIMIT ?",
            (args.limit,),
        ):
            print(f"  [{row['category']}] {row['name']} -> {row['path']}")
    if show_all or args.skills:
        print("=== skills ===")
        for row in conn.execute(
            "SELECT name, source, path FROM skills ORDER BY source, name LIMIT ?",
            (args.limit,),
        ):
            print(f"  ({row['source']}) {row['name']}")
    if show_all or args.ops:
        print("=== op_log (latest) ===")
        for row in conn.execute(
            "SELECT section_no, category, title, log_date FROM op_log ORDER BY section_no DESC LIMIT ?",
            (args.limit,),
        ):
            print(f"  §{row['section_no']} | {row['category']} | {row['title']} ({row['log_date']})")
    if show_all or args.routing:
        print("=== routing ===")
        for row in conn.execute(
            "SELECT priority, rule_name, channel, status, action_text FROM routing_rules ORDER BY priority"
        ):
            print(f"  {row['priority']:>3} {row['rule_name']} [{row['status']}] -> {row['action_text']}")
    if show_all or args.lessons:
        print("=== lessons ===")
        for row in conn.execute("SELECT decision, title, rationale FROM lessons ORDER BY lesson_key"):
            print(f"  [{row['decision']}] {row['title']}: {row['rationale'][:80]}...")
    conn.close()


if __name__ == "__main__":
    main()
