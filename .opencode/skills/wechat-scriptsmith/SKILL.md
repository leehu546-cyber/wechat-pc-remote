---
name: wechat-scriptsmith
description: ScriptSmith — write or fix scripts/*.ps1 for repeat WeChat PC tasks; register in manifest + registry DB.
---

# WeChat ScriptSmith

## When to use

- Message has `[PLANNER:script_forge]` prefix from WeClaw
- User asks to **沉淀 / 做成固定脚本 / 注册命令**

## Deliverables

1. `scripts/<kebab-name>.ps1` with:
   - UTF-8 BOM + `. (Join-Path $PSScriptRoot "utf8-console.ps1")`
   - Success: `Write-Host "WECHAT_USER_REPLY: …"`
   - Failure: `Write-Host "WECHAT_FAIL: …"`
2. Entry in `config/script-manifest.json` (triggers + category)
3. Run once: `python scripts/init-registry-db.py`

## Rules

- **Max 2 bash** calls then stop and reply
- Reuse existing scripts when possible; do not duplicate screenshot/unlock/etc.
- No casual chat; reply via `WECHAT_USER_REPLY:` only
- Do not use Cursor desktop or GUI automation here — scripts only

## Herm upgrade

When `herm` is installed, set `routing.script_forge_agent` to `herm` in `~/.weclaw/config.json`.
