---
name: wechat-script-runner
description: ScriptRunner — compose and RUN one-off PowerShell scripts for WeChat PC tasks (write + execute, not沉淀).
---

# WeChat ScriptRunner

## When to use

- Message has `[PLANNER:script_task]` prefix from WeClaw
- User explicitly asks **用脚本 / 脚本方式 / 跑脚本** for a task
- **Not** for沉淀/固定脚本 (use `wechat-scriptsmith` instead)
- **Not** for GUI open/focus only (Planner uses `windows-use-task.ps1`)

## Workflow

1. Read `config/script-manifest.json` — if an existing script fits (e.g. `news-to-word.ps1`), **run it** instead of rewriting
2. Otherwise write `scripts/wechat-run-<topic>.ps1` (UTF-8 BOM + `utf8-console.ps1`)
3. **Run** via bash (one call):

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/wechat-run-<topic>.ps1
```

Or with args:

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/news-to-word.ps1
```

4. Parse stdout for `WECHAT_USER_REPLY:` / `WECHAT_FAIL:` and echo that as your final reply

## Script template

```powershell
. (Join-Path $PSScriptRoot "utf8-console.ps1")
try {
    # task logic (Invoke-WebRequest, Word COM, file I/O, etc.)
    Write-Host "WECHAT_USER_REPLY: 已完成：…"
} catch {
    Write-Host "WECHAT_FAIL: $($_.Exception.Message)"
    exit 1
}
```

## Rules

- **Max 3 bash** calls per turn (write → run → optional fix)
- Prefer **PowerShell**; Python only inside the script if needed
- Do **not** use GUI/windows-use here — scripts + terminal only
- Do **not** register manifest unless user also asked to沉淀 (ScriptSmith handles that)
- Reply via `WECHAT_USER_REPLY:` only; ≤120 chars unless stock-style card
- Chinese scripts = UTF-8 BOM + `utf8-console.ps1`

## Examples

| User | Action |
|------|--------|
| 用脚本搜索新闻写在 Word 里 | Run or extend `scripts/news-to-word.ps1` |
| 用脚本统计桌面文件数 | New short ps1, run, report count |
