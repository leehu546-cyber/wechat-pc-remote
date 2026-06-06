# WeChat remote control rules

You are controlled via WeChat. The user only sees your final text reply after all tools finish.

## Mandatory reply rules

- After every tool run, you MUST end with one concise Chinese sentence (max 120 chars).
- Never finish a turn with only tool calls and no user-facing text.
- If a task ran on the PC, say what was done: e.g. `WECHAT_OK: 已打开哔哩哔哩并点击第一个视频`.
- For long tasks, use short tool steps and summarize progress after each meaningful step.

## Script rules (critical)

- All python/shell scripts MUST exit within 30 seconds.
- NEVER use `while True` or infinite sleep to keep the browser alive.
- Open URLs with PowerShell: `Start-Process msedge "https://..."` (probe real exe path first).
- Selenium to keep browser open: `options.add_experimental_option("detach", True)`; do NOT call `driver.quit()` in `finally` (use `pass`).
- Selenium to close browser after action: click then `driver.quit()` and exit within 30s.
- Prefer `Start-Process msedge URL` over Selenium when no DOM click is needed.

## Browser tasks

- Prefer opening a URL over writing Selenium scripts.
- Popup/sound/GUI control is unreliable; explain limits briefly if asked.

## When stuck

- If a script would run long, split: run a short script, reply, then continue in a new turn.

## Persistent user facts (read every turn)

Update this section when the user states preferences or ongoing tasks. After context compaction, rely on this file plus EverOS-injected memory in the user message.

| Key | Value |
|-----|-------|
| workspace | `D:\cursor\61` |
| control_channel | WeChat via WeClaw + OpenCode ACP |
| reply_style | One concise Chinese sentence, max 120 chars |
| browser | Prefer `Start-Process msedge URL` |
| in_progress | _(none — update when user starts a multi-step task)_ |

When the user refers to "刚才" / "上一步" / "那个任务", check this table and recent tool outcomes before asking them to repeat.

## Display control (screenshot / wake / turn off — skills only, NO ad-hoc bash)

WeClaw may handle these locally (quick path). If the message still reaches you, **must use registered skills + fixed scripts** — never improvise PowerShell/bash for display control.

| User intent | Skill | Script |
|-------------|-------|--------|
| 截图 / 截屏 | `wechat-screenshot` | `scripts/screenshot.ps1` |
| 亮屏 / 开屏 / **打开屏幕** / 把屏幕打开 | `wechat-screen-on` | `scripts/wake-screen.ps1` |
| 关屏 / 熄屏 / **关闭屏幕** / 把屏幕关闭 | `wechat-screen-off` | `scripts/turn-off-screen.ps1` |

Rules:
- **Never** write custom PowerShell/bash to wake, turn off, or capture the display; those hang when the monitor is off or run 60s+.
- Always `-File scripts/<name>.ps1` with 30s timeout (screenshot: 90s).
- Synonyms: 「打开屏幕」= 亮屏; 「关闭屏幕」「你把屏幕关闭」= 关屏 — match skill by meaning, not exact keywords.
- If quick path already handled it, reply in one short Chinese sentence; do not run duplicate scripts.
- Bash for **other** PC tasks: prefer 30s timeout or less.

## Commit & Log rules

- After every code change: git add + git commit + \scripts\log-step.ps1\
- Commit message format: 简洁中文说明改动
- Log format: 类别为 \"修复\" / \"功能\" / \"优化\" / \"整理\"
