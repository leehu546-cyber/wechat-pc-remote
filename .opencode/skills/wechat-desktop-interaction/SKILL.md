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

## Canonical Command

Use only the fixed script:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/desktop-interact.ps1 -App <App> -Target <Target> -Text "<text>" [-Send] [-Verify]
```

Known profiles: `Codex/chat_input`, `Cursor/chat_input`, `WPS/document_body`

## Rules

- Do not improvise mouse coordinates. Use `scripts/desktop-interact.ps1`.
- Do not use this for lock-screen password entry.
- Default is type only. Add `-Send` only if the user explicitly asks to send/submit.
- 收尾回复：
  - 成功：`已完成：已在{App}输入文字`
  - 失败：`没做成：{脚本原因}`
  - 若 stdout 含 `WECHAT_USER_REPLY:`，原样转发

## Examples

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/desktop-interact.ps1 -App Cursor -Target chat_input -Text "你好" -Verify
```
