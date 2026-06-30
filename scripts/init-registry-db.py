#!/usr/bin/env python3
"""Initialize project registry DB: scripts, skills, op-log, routing lessons."""

from __future__ import annotations

import json
import re
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "data" / "registry.sqlite"
MANIFEST = ROOT / "config" / "script-manifest.json"
OP_LOG = ROOT / "docs" / "操作日志.md"
SKILLS_DIR = ROOT / ".opencode" / "skills"
SCRIPTS_DIR = ROOT / "scripts"
VENDOR_SKILLS = ROOT / "vendor"

SCHEMA = """
CREATE TABLE IF NOT EXISTS scripts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    path TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'utility',
    triggers TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    source TEXT NOT NULL DEFAULT 'local',
    notes TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS skills (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    path TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    source TEXT NOT NULL DEFAULT 'local',
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS op_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    section_no INTEGER,
    category TEXT,
    title TEXT NOT NULL,
    log_date TEXT,
    body TEXT,
    imported_at TEXT NOT NULL,
    UNIQUE(section_no, title)
);

CREATE TABLE IF NOT EXISTS routing_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    priority INTEGER NOT NULL DEFAULT 100,
    rule_name TEXT NOT NULL UNIQUE,
    channel TEXT NOT NULL,
    condition_text TEXT,
    action_text TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    notes TEXT
);

CREATE TABLE IF NOT EXISTS lessons (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lesson_key TEXT NOT NULL UNIQUE,
    decision TEXT NOT NULL,
    title TEXT NOT NULL,
    rationale TEXT NOT NULL,
    related_sections TEXT,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_scripts_status ON scripts(status);
CREATE INDEX IF NOT EXISTS idx_skills_status ON skills(status);
CREATE INDEX IF NOT EXISTS idx_op_log_section ON op_log(section_no);
"""


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def connect() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA)
    return conn


def upsert_script(conn: sqlite3.Connection, row: dict) -> None:
    ts = now_iso()
    conn.execute(
        """
        INSERT INTO scripts (name, path, category, triggers, status, source, notes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(name) DO UPDATE SET
            path=excluded.path, category=excluded.category, triggers=excluded.triggers,
            status=excluded.status, source=excluded.source, notes=excluded.notes, updated_at=excluded.updated_at
        """,
        (
            row["name"],
            row["path"],
            row.get("category", "utility"),
            json.dumps(row.get("triggers", []), ensure_ascii=False),
            row.get("status", "active"),
            row.get("source", "local"),
            row.get("notes", ""),
            ts,
            ts,
        ),
    )


def import_manifest(conn: sqlite3.Connection) -> int:
    if not MANIFEST.exists():
        return 0
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    count = 0
    for item in data.get("scripts", []):
        upsert_script(conn, item)
        count += 1
    for ps1 in SCRIPTS_DIR.glob("*.ps1"):
        rel = ps1.relative_to(ROOT).as_posix()
        name = ps1.stem
        existing = conn.execute("SELECT id FROM scripts WHERE name = ?", (name,)).fetchone()
        if existing:
            continue
        upsert_script(
            conn,
            {
                "name": name,
                "path": rel,
                "category": "utility",
                "triggers": [],
                "source": "local",
            },
        )
        count += 1
    archive = SCRIPTS_DIR / "archive" / "cursor-worker"
    if archive.exists():
        for ps1 in archive.glob("*.ps1"):
            upsert_script(
                conn,
                {
                    "name": f"archived/{ps1.stem}",
                    "path": ps1.relative_to(ROOT).as_posix(),
                    "category": "deprecated",
                    "triggers": [],
                    "status": "archived",
                    "source": "local",
                    "notes": "Cursor Worker §80-81, disabled §82",
                },
            )
            count += 1
    return count


def parse_skill_description(skill_md: Path) -> str:
    text = skill_md.read_text(encoding="utf-8", errors="replace")
    m = re.search(r"^description:\s*(.+)$", text, re.MULTILINE)
    if m:
        return m.group(1).strip()
    m = re.search(r"^name:\s*(.+)$", text, re.MULTILINE)
    return m.group(1).strip() if m else skill_md.parent.name


def import_skills(conn: sqlite3.Connection) -> int:
    count = 0
    ts = now_iso()
    for skill_md in SKILLS_DIR.glob("*/SKILL.md"):
        name = skill_md.parent.name
        conn.execute(
            """
            INSERT INTO skills (name, path, description, status, source, created_at)
            VALUES (?, ?, ?, 'active', 'local', ?)
            ON CONFLICT(name) DO UPDATE SET path=excluded.path, description=excluded.description
            """,
            (name, skill_md.relative_to(ROOT).as_posix(), parse_skill_description(skill_md), ts),
        )
        count += 1
    if VENDOR_SKILLS.exists():
        for skill_md in VENDOR_SKILLS.rglob("SKILL.md"):
            name = f"vendor/{skill_md.parent.name}"
            conn.execute(
                """
                INSERT INTO skills (name, path, description, status, source, created_at)
                VALUES (?, ?, ?, 'active', 'vendor', ?)
                ON CONFLICT(name) DO UPDATE SET path=excluded.path, description=excluded.description, source='vendor'
                """,
                (name, skill_md.relative_to(ROOT).as_posix(), parse_skill_description(skill_md), ts),
            )
            count += 1
    return count


def import_op_log(conn: sqlite3.Connection) -> int:
    if not OP_LOG.exists():
        return 0
    text = OP_LOG.read_text(encoding="utf-8")
    pattern = re.compile(
        r"^### (\d+)\s*\|\s*([^|]+)\|\s*(.+?)\s*\n\n\*\*日期：\*\*\s*(.+?)\s*\n\n([\s\S]*?)(?=^---\s*$|^### |\Z)",
        re.MULTILINE,
    )
    count = 0
    ts = now_iso()
    for m in pattern.finditer(text):
        section_no = int(m.group(1))
        category = m.group(2).strip()
        title = m.group(3).strip()
        log_date = m.group(4).strip()
        body = m.group(5).strip()
        conn.execute(
            """
            INSERT INTO op_log (section_no, category, title, log_date, body, imported_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(section_no, title) DO UPDATE SET body=excluded.body, imported_at=excluded.imported_at
            """,
            (section_no, category, title, log_date, body, ts),
        )
        count += 1
    return count


def seed_routing(conn: sqlite3.Connection) -> None:
    rules = [
        (10, "mechanical_script", "script", "screenshot/unlock/wake/off/rustdesk/ocr/stock", "planner -> scripts/*.ps1", "active", "Go executes; no LLM fake done"),
        (20, "daily_chat", "opencode", "你好/在吗/短闲聊", "planner action=chat -> OpenCode", "active", ""),
        (30, "compound_orchestrate", "planner", "多步桌面", "orchestrate <=3 steps", "active", ""),
        (40, "fallback_specialist", "opencode", "未覆盖/复杂", "OpenCode + skills", "active", "可沉淀新脚本"),
        (99, "cursor_worker", "deprecated", "任意", "cursor-delegate", "disabled", "§82 停用：不稳定"),
    ]
    for r in rules:
        conn.execute(
            """
            INSERT INTO routing_rules (priority, rule_name, channel, condition_text, action_text, status, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(rule_name) DO UPDATE SET priority=excluded.priority, channel=excluded.channel,
                condition_text=excluded.condition_text, action_text=excluded.action_text,
                status=excluded.status, notes=excluded.notes
            """,
            r,
        )


def seed_lessons(conn: sqlite3.Connection) -> None:
    lessons = [
        (
            "reject_cursor_desktop_worker",
            "reject",
            "停用 Cursor 桌面粘贴+OCR Worker",
            "额度弹窗、坐标、假提交、换号耗时长；稳定性优先于把 Cursor 当远程手。",
            "80,81,82",
        ),
        (
            "keep_script_runner_file",
            "adopt",
            "PowerShell 用 -File 传 -Task",
            "避免中文任务绑到 TimeoutSec；buildScriptRunnerArgs 已修复。",
            "81",
        ),
        (
            "keep_inbound_attachments",
            "adopt",
            "微信附件 inbound 层",
            "文件+放到桌面必须带路径；禁止 Specialist 猜路径。",
            "78",
        ),
        (
            "script_before_agent",
            "adopt",
            "重复任务先沉淀脚本",
            "平衡智能与稳定：能脚本化就不靠 Agent 临场发挥。",
            "76,78",
        ),
    ]
    ts = now_iso()
    for key, decision, title, rationale, sections in lessons:
        conn.execute(
            """
            INSERT INTO lessons (lesson_key, decision, title, rationale, related_sections, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(lesson_key) DO UPDATE SET decision=excluded.decision, title=excluded.title,
                rationale=excluded.rationale, related_sections=excluded.related_sections
            """,
            (key, decision, title, rationale, sections, ts),
        )


def main() -> None:
    conn = connect()
    try:
        n_scripts = import_manifest(conn)
        n_skills = import_skills(conn)
        n_ops = import_op_log(conn)
        seed_routing(conn)
        seed_lessons(conn)
        conn.commit()
        print(f"Registry DB: {DB_PATH}")
        print(f"  scripts upserted/seen: {n_scripts}")
        print(f"  skills upserted/seen: {n_skills}")
        print(f"  op_log sections: {n_ops}")
        print(f"  routing_rules: {conn.execute('SELECT COUNT(*) FROM routing_rules').fetchone()[0]}")
        print(f"  lessons: {conn.execute('SELECT COUNT(*) FROM lessons').fetchone()[0]}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
