---
name: wechat-desktop-interaction
description: Use when the user asks to open or switch to a desktop application and type text into a known input area, search box, chat box, or document body. Not for lock-screen password entry.
---

# WeChat Desktop Interaction

## Purpose

Use this skill for GUI input tasks such as:

- 打开 Codex，在对话框输入你好
- 打开 Cursor，在里面输入你好
- 打开 WPS 的 Word，在正文里写 Hello World
- 在某个应用的搜索框、对话框、正文区域输入文字

The main brain decides intent first. This skill is a DesktopAgent worker under the `wechat-task-orchestrator` Plan -> Act -> Verify -> Report protocol.

## Canonical Command

Use only the fixed script:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/desktop-interact.ps1 -App <App> -Target <Target> -Text "<text>" [-Send] [-Verify]
```

Known first-version profiles:

| App | Target | Meaning |
|-----|--------|---------|
| `Codex` | `chat_input` | Codex bottom composer |
| `Cursor` | `chat_input` | Cursor Agents composer |
| `WPS` | `document_body` | WPS Writer document body |

## Rules

- Do not improvise mouse coordinates in chat. Use `scripts/desktop-interact.ps1`.
- Do not use this for lock-screen password entry. For unlock, output only `WECLAW_DELEGATE: openclaw-unlocker`.
- Default is type only. Add `-Send` only if the user explicitly asks to send, submit, press Enter, or run it.
- Add `-Verify` when the user asks to see, confirm, or receive a screenshot.
- If the script returns `WECHAT_FAIL`, stop repeated attempts and report the reason.

## Examples

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/desktop-interact.ps1 -App Cursor -Target chat_input -Text "你好" -Verify
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/desktop-interact.ps1 -App WPS -Target document_body -Text "Hello World" -Verify
```
