"""Configure Windows-Use CLI with DeepSeek from OpenCode auth or env."""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from windows_use.cli.config import get_active_config, upsert_provider


def main() -> int:
    key = os.environ.get("DEEPSEEK_API_KEY", "").strip()
    if not key:
        auth_path = Path.home() / ".local" / "share" / "opencode" / "auth.json"
        if auth_path.is_file():
            data = json.loads(auth_path.read_text(encoding="utf-8"))
            key = (data.get("deepseek") or {}).get("key", "").strip()

    if not key:
        print("WECHAT_FAIL: no DeepSeek API key")
        return 1

    upsert_provider("deepseek", "deepseek-chat", api_key=key, set_active=True)
    active = get_active_config() or {}
    print(
        f"WECHAT_OK: windows-use provider={active.get('provider')} "
        f"model={active.get('llm')}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
