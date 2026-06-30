---
name: wechat-task-orchestrator
description: Specialist fallback for compound tasks when WeClaw Planner could not split into mechanical steps. Brain-only protocol; max 3 tool calls per turn.
---

# WeChat Task Orchestrator (Specialist fallback)

## When to use

- User message has `[PLANNER:compound]` prefix from WeClaw
- Planner parse failed and Specialist must handle the full chain
- **Not** for simple atomic tasks (Planner runs scripts directly)

## Protocol

1. Plan: choose ≤3 bash steps total for this turn
2. Act: one skill/script per step; `WECHAT_PROGRESS: 正在执行第N步`
3. Verify: screenshot or OCR only if user asked to see/confirm
4. Report: `已完成：…` or `没做成：…` (≤120 chars)

## Hard Rules

- **Max 3 tool calls** then stop and reply (avoid brain stall)
- Do not leak English tool titles or `Loaded skill:` to WeChat
- Do not use screenshot when user wants **read text** — use `wechat-screen-ocr`
- Unknown apps: if Windows-Use unavailable, say `没做成：暂不支持该应用界面操作`
- Unlock: only `WECLAW_DELEGATE: openclaw-unlocker` — no bash unlock
