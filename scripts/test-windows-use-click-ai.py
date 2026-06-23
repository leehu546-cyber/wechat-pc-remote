"""One-shot Windows-Use test: focus Cursor and click the AI chat input box."""
from __future__ import annotations

import os
import sys

from windows_use import Agent
from windows_use.cli.config import get_active_config
from windows_use.providers.deepseek import ChatDeepSeek


def main() -> int:
    os.environ.setdefault("ANONYMIZED_TELEMETRY", "false")

    cfg = get_active_config()
    if not cfg or not cfg.get("api_key"):
        print("WECHAT_FAIL: windows-use not configured. Run scripts/setup-windows-use-deepseek.ps1")
        return 1

    llm = ChatDeepSeek(
        model=cfg.get("llm") or "deepseek-chat",
        api_key=cfg["api_key"],
    )

    task = (
        "任务：在 Windows 桌面上找到 Cursor 编辑器窗口（进程名 Cursor）。"
        "若 Cursor 未打开，从开始菜单或任务栏启动它。"
        "将 Cursor 窗口置于前台，然后点击底部 Agent/AI 聊天输入框一次（左键单击），"
        "让输入框获得焦点。不要输入任何文字，不要发送消息。"
        "完成后用 done_tool 回复：已点击 Cursor AI 输入框。"
    )

    agent = Agent(
        llm=llm,
        max_steps=20,
        max_consecutive_failures=3,
        log_to_console=True,
        use_accessibility=True,
        auto_minimize=False,
    )

    print("WECHAT_PROGRESS: Windows-Use 正在查找并点击 Cursor AI 输入框")
    result = agent.invoke(task=task)
    answer = getattr(result, "content", None) or str(result)
    print(f"WECHAT_OK: {answer[:200]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
