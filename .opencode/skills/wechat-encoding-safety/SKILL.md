---
name: wechat-encoding-safety
description: MANDATORY when writing/editing PowerShell that outputs Chinese to WeChat, or when user reports 乱码/garbled text. Prevents GBK/UTF-8 mismatch and Agent re-typing corruption.
---

# 微信中文防乱码 (wechat-encoding-safety)

## 何时必须加载

- 编写或修改会 `Write-Host` 中文的 `scripts/*.ps1`
- 用户反馈微信回复出现 **乱码**、``、`Դһ` 等
- 股票卡片、固定回复、`WECHAT_STOCK_CARD` / `WECHAT_USER_REPLY`
- 保存含中文的 JSON 配置（如 `stock-portfolio.json`）

---

## 乱码根因（本机已踩坑）

| 现象 | 根因 |
|------|------|
| `沪深300` → `` | PowerShell 在中文 Windows 默认 **GBK(CP936)** 输出 stdout，OpenCode/WeClaw 按 **UTF-8** 读 → 字节错位 |
| `源一致` → `Դһ` | UTF-8 三字节被当成 Latin-1 单字节显示（典型 mojibake） |
| `━━━━` 整段乱码 | 全角符号 `━` + 错误编码叠加 |
| Agent 回复正常数字、中文全花 | **Agent 凭记忆重打中文**，未原样转发 tool stdout |
| `Set-Content -Encoding UTF8` 仍乱 | PS 5.1 写 JSON 无 BOM 或读端编码不一致 |

**链路：** `stock-info.ps1` → bash tool stdout → Agent → WeClaw → 微信。任一环节编码不一致即乱码。

---

## 脚本硬性规范（Agent 改 ps1 时必须遵守）

### 1. 文件编码

- 含中文**字面量**的 `.ps1`：**UTF-8 with BOM**（`EF BB BF` 开头）
- 禁止：无 BOM 的 UTF-8、GBK 保存的 ps1

### 2. 强制 UTF-8 控制台输出（每条用户可见脚本开头）

在 `param()` 之后**第一行** dot-source：

```powershell
. (Join-Path $PSScriptRoot "utf8-console.ps1")
```

适用：`stock-info.ps1`、`wake-screen.ps1`、`screenshot.ps1`、`unlock-screen.ps1` 等所有会输出中文的脚本。

### 3. JSON 含中文

用 .NET 显式 UTF-8 BOM 写入：

```powershell
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($path, $json, $utf8Bom)
```

禁止：仅靠 `Set-Content -Encoding UTF8` 写用户配置（易乱码）。

### 4. 用户可见文本字符集

- **允许**：中文、ASCII 数字/标点、换行 `\n`
- **禁止**：`━` `──` 等装饰线（微信/日志易花）
- **禁止**：在 stdout 混用 GBK 与 UTF-8

### 5. 机器块前缀（保持不变）

```
WECHAT_DATA:
WECHAT_STOCK_CARD:
WECHAT_USER_REPLY:
WECHAT_OK:
WECHAT_FAIL:
```

---

## Agent 硬性规范（微信回复）

1. **禁止凭记忆重打中文** — 必须从 tool stdout **逐字复制** `WECHAT_STOCK_CARD:` 后正文（保留换行）。
2. **禁止**在卡片外加解释、改字、把多行合并成一行。
3. 若 stdout 已是乱码 → 不要自行「翻译修复」；检查脚本是否已 dot-source `utf8-console.ps1`，修脚本后让用户重发。
4. 股票回复：**只转发卡片**，不经过 Agent「润色」。

---

## 自检清单（改完必做）

```powershell
# 1) 脚本有 BOM
Format-Hex -Path scripts\stock-info.ps1 -Count 3

# 2) 本地 stdout 中文正常
powershell -NoProfile -File scripts\stock-info.ps1 | Select-String "沪深|现价|建议"

# 3) 微信发「股票」后 chat-log UTF-8 可读
Get-Content "$env:USERPROFILE\.weclaw\chat-log\*.jsonl" -Tail 2 -Encoding UTF8
```

chat-log 里 assistant 一行应能直接读出「沪深300ETF」「现价」「建议」，不能是 `` 或 `Դһ`。

---

## 相关文件

| 文件 | 作用 |
|------|------|
| `scripts/utf8-console.ps1` | 统一 UTF-8 stdout |
| `scripts/stock-info.ps1` | 股票卡片（须 BOM + utf8-console） |
| `wechat-stock-info` skill | 只转发 CARD，禁止改写字 |
| WeClaw `reply_normalize.go` | 提取 CARD；不能修复已乱码的字节 |

---

## 禁止

- 用 GBK/ANSI 保存含中文的 ps1
- 在 Agent 回复里重写脚本已算好的中文数字
- 用全角装饰线 `━` 做微信排版
- 看到乱码仍让用户 `/new` 而不修编码根因
