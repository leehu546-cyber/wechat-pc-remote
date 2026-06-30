#!/usr/bin/env python3
"""Initialize incidents SQLite DB and seed known records."""

from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "data" / "incidents.sqlite"

SCHEMA = """
CREATE TABLE IF NOT EXISTS incidents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_key TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    category TEXT NOT NULL,
    component TEXT NOT NULL,
    severity TEXT NOT NULL,
    title TEXT NOT NULL,
    symptoms TEXT,
    root_cause TEXT,
    fix_actions TEXT,
    verification TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    related_paths TEXT,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS incident_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id INTEGER NOT NULL,
    event_at TEXT NOT NULL,
    event_type TEXT NOT NULL,
    detail TEXT NOT NULL,
    FOREIGN KEY (incident_id) REFERENCES incidents(id)
);

CREATE INDEX IF NOT EXISTS idx_incidents_component ON incidents(component);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status);
CREATE INDEX IF NOT EXISTS idx_incident_events_incident_id ON incident_events(incident_id);
"""


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def connect() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA)
    return conn


def upsert_incident(conn: sqlite3.Connection, row: dict, events: list[dict]) -> int:
    ts = now_iso()
    existing = conn.execute(
        "SELECT id FROM incidents WHERE incident_key = ?",
        (row["incident_key"],),
    ).fetchone()

    if existing:
        incident_id = existing["id"]
        conn.execute(
            """
            UPDATE incidents SET
                updated_at = ?,
                category = ?,
                component = ?,
                severity = ?,
                title = ?,
                symptoms = ?,
                root_cause = ?,
                fix_actions = ?,
                verification = ?,
                status = ?,
                related_paths = ?,
                notes = ?
            WHERE id = ?
            """,
            (
                ts,
                row["category"],
                row["component"],
                row["severity"],
                row["title"],
                row["symptoms"],
                row["root_cause"],
                row["fix_actions"],
                row["verification"],
                row["status"],
                json.dumps(row["related_paths"], ensure_ascii=False),
                row.get("notes"),
                incident_id,
            ),
        )
        conn.execute("DELETE FROM incident_events WHERE incident_id = ?", (incident_id,))
    else:
        cur = conn.execute(
            """
            INSERT INTO incidents (
                incident_key, created_at, updated_at, category, component, severity,
                title, symptoms, root_cause, fix_actions, verification, status,
                related_paths, notes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                row["incident_key"],
                ts,
                ts,
                row["category"],
                row["component"],
                row["severity"],
                row["title"],
                row["symptoms"],
                row["root_cause"],
                row["fix_actions"],
                row["verification"],
                row["status"],
                json.dumps(row["related_paths"], ensure_ascii=False),
                row.get("notes"),
            ),
        )
        incident_id = cur.lastrowid

    for event in events:
        conn.execute(
            """
            INSERT INTO incident_events (incident_id, event_at, event_type, detail)
            VALUES (?, ?, ?, ?)
            """,
            (incident_id, event["event_at"], event["event_type"], event["detail"]),
        )

    conn.commit()
    return incident_id


CC_SWITCH_INCIDENT = {
    "incident_key": "cc-switch-codex-deepseek-routing-20260630",
    "category": "配置",
    "component": "cc-switch",
    "severity": "high",
    "title": "CC Switch Codex 本地路由无法开启，DeepSeek 直连失败",
    "symptoms": (
        "用户通过 CC Switch 配置 DeepSeek API 给 Codex 使用，路由开关打不开或开启后 Codex 仍无法对话。"
        "config.toml 中 base_url 指向 https://api.deepseek.com；Codex 日志出现 token_expired / refresh_token_reused。"
    ),
    "root_cause": (
        "1) CC Switch 启动时恢复 Codex 代理接管失败：127.0.0.1:15721 端口被占用 (Windows error 10048)，"
        "导致 proxy_config 中 codex 路由被重置为关闭。"
        "2) Codex 要求 OpenAI Responses API，DeepSeek 官方仅支持 Chat Completions；"
        "直连 https://api.deepseek.com/responses 返回 404，必须走 CC Switch 本地路由做协议转换。"
        "3) settings.json 中 currentProviderCodex 丢失后，代理 failover 队列误用 default / OpenAI Official，"
        "二者缺少 base_url，报「Codex Provider 缺少 base_url 配置」。"
    ),
    "fix_actions": (
        "1) 结束占用 15721 端口的残留进程，重启 CC Switch。"
        "2) 恢复 ~/.cc-switch/settings.json（含 currentProviderCodex=DeepSeek provider id）。"
        "3) UPDATE proxy_config SET proxy_enabled=1, enabled=1 WHERE app_type='codex'。"
        "4) 清空 codex 的 in_failover_queue，确保当前 provider 为 DeepSeek。"
        "5) config.toml base_url 改为 http://127.0.0.1:15721/v1，重启 Codex。"
        "脚本：scripts/fix-ccswitch-routing.ps1、scripts/fix_ccswitch_db.py、scripts/fix_ccswitch_provider.py"
    ),
    "verification": (
        "CC Switch 日志应出现「代理服务器启动于 127.0.0.1:15721」和「Codex Live 配置已接管」。"
        "netstat 应显示 127.0.0.1:15721 LISTENING。"
        "对 http://127.0.0.1:15721/v1/responses 发 deepseek-v4-flash 请求应返回 200 而非 proxy_error。"
    ),
    "status": "partial",
    "related_paths": [
        "~/.cc-switch/cc-switch.db",
        "~/.cc-switch/settings.json",
        "~/.cc-switch/logs/cc-switch.log",
        "~/.codex/config.toml",
        "~/.codex/auth.json",
        "scripts/fix-ccswitch-routing.ps1",
        "scripts/fix_ccswitch_db.py",
        "scripts/fix_ccswitch_provider.py",
    ],
    "notes": "修复过程中 PowerShell ConvertTo-Json 曾误覆盖 settings.json 丢失 currentProviderCodex，已从 backups/fix-routing-* 恢复。",
}

CC_SWITCH_EVENTS = [
    {
        "event_at": "2026-06-30T11:06:39+08:00",
        "event_type": "discovered",
        "detail": "CC Switch 启动日志：恢复 codex 代理接管失败，15721 端口绑定 error 10048。",
    },
    {
        "event_at": "2026-06-30T11:06:44+08:00",
        "event_type": "discovered",
        "detail": "Codex 日志：ChatGPT 官方 token_expired / refresh_token_reused（preserveCodexOfficialAuthOnSwitch 开启时）。",
    },
    {
        "event_at": "2026-06-30T11:16:48+08:00",
        "event_type": "diagnosed",
        "detail": "DeepSeek 直连 /responses 404；/chat/completions 200。本地代理误路由到 provider default。",
    },
    {
        "event_at": "2026-06-30T14:12:49+08:00",
        "event_type": "fix_attempted",
        "detail": "释放端口并重启 CC Switch 后，代理成功监听 15721，Codex Live 配置已接管。",
    },
    {
        "event_at": "2026-06-30T14:13:43+08:00",
        "event_type": "diagnosed",
        "detail": "代理 failover 仍尝试 OpenAI Official 与 default，均报缺少 base_url；currentProviderCodex 为空。",
    },
    {
        "event_at": "2026-06-30T14:15:00+08:00",
        "event_type": "fix_attempted",
        "detail": "计划恢复 settings.json、重置 DeepSeek 为当前 provider、清空 codex failover 队列。",
    },
]


def main() -> int:
    conn = connect()
    incident_id = upsert_incident(conn, CC_SWITCH_INCIDENT, CC_SWITCH_EVENTS)
    row = conn.execute("SELECT * FROM incidents WHERE id = ?", (incident_id,)).fetchone()
    event_count = conn.execute(
        "SELECT COUNT(*) AS c FROM incident_events WHERE incident_id = ?",
        (incident_id,),
    ).fetchone()["c"]
    conn.close()
    print(f"OK: {DB_PATH}")
    print(f"incident_id={incident_id} key={row['incident_key']} status={row['status']} events={event_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
