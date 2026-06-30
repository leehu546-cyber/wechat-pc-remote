"""Run one Windows-Use GUI task for WeClaw planner step runner."""
from __future__ import annotations

import os
import sys

from windows_use import Agent
from windows_use.cli.config import get_active_config
from windows_use.providers.deepseek import ChatDeepSeek


def main() -> int:
    os.environ.setdefault("ANONYMIZED_TELEMETRY", "false")

    goal = " ".join(sys.argv[1:]).strip()
    if not goal:
        goal = os.environ.get("WECLAW_GUI_TASK", "").strip()
    if not goal:
        print("WECHAT_FAIL: gui_goal_missing")
        return 1

    cfg = get_active_config()
    if not cfg or not cfg.get("api_key"):
        print("WECHAT_FAIL: windows_use_not_configured")
        return 1

    llm = ChatDeepSeek(
        model=cfg.get("llm") or "deepseek-chat",
        api_key=cfg["api_key"],
    )

    task = (
        "你是微信远程控制的桌面操作员。任务：" + goal + "。"
        "在 Windows 上完成用户要求，必要时从开始菜单或任务栏打开应用。"
        "完成后用 done_tool 回复一句中文结果（不超过 40 字）。"
    )

    agent = Agent(
        llm=llm,
        max_steps=25,
        max_consecutive_failures=3,
        log_to_console=False,
        use_accessibility=True,
        auto_minimize=False,
    )

    print("WECHAT_PROGRESS: 正在操作桌面界面")
    result = agent.invoke(task=task)
    answer = getattr(result, "content", None) or str(result)
    answer = " ".join(str(answer).split())
    if not answer:
        answer = "桌面操作已完成"
    if len(answer) > 80:
        answer = answer[:79] + "…"
    print(f"WECHAT_OK: {answer}")
    print(f"WECHAT_USER_REPLY: 已完成：{answer}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
