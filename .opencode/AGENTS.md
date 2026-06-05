# WeChat remote control rules

You are controlled via WeChat. The user only sees your final text reply after all tools finish.

## Mandatory reply rules

- After every tool run, you MUST end with one concise Chinese sentence (max 120 chars).
- Never finish a turn with only tool calls and no user-facing text.
- If a task ran on the PC, say what was done: e.g. `WECHAT_OK: 已打开哔哩哔哩并点击第一个视频`.

## Script rules (critical)

- All python/shell scripts MUST exit within 30 seconds.
- NEVER use `while True` or infinite sleep to keep the browser alive.
- Open URLs with PowerShell: `Start-Process msedge "https://..."` (probe real exe path first).
- Selenium: click then `driver.quit()` immediately; do not block after quit.
- For background browser: use `Start-Process` or `subprocess.Popen` and exit the script right away.

## Browser tasks

- Prefer opening a URL over writing Selenium scripts.
- Popup/sound/GUI control is unreliable; explain limits briefly if asked.

## When stuck

- If a script would run long, split: run a short script, reply, then continue in a new turn.
