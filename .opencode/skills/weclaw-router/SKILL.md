---
name: weclaw-router
description: Brain-only entry for every natural-language WeChat message. Load FIRST to classify intent, then load exactly one domain expert skill. NOT used by WeClaw bridge — only by the DeepSeek brain in the same API session.
---

# WeClaw Router（大脑内总路由 · 单 API）

## 核心原则

**所有自然语言的语义理解，必须在本 skill 加载后的同一次 DeepSeek 对话里完成。**

- WeClaw 桥 **不会** 替你做分类，也 **没有** 第二套 LLM。
- 本 skill 不是 Go 路由程序，只是给 **同一个大脑** 用的「先分类、再派活」检查表。
- 「专家 Agent」（ScreenAgent、FileAgent…）= **同一会话里再 load 的一个 skill**，不是另一个 API 调用。

## 每次收到用户自然语言时的固定顺序

1. **理解**（DeepSeek）：用户要什么？简单任务还是复合任务？
2. **分类**（DeepSeek）：选一个域（见下表）；复合任务 → load `wechat-task-orchestrator`。
3. **委派专家**（DeepSeek）：load 对应 **专家 skill**（或 atomic skill），**禁止**跳过本步直接 bash。
4. **执行**（DeepSeek 调 tool）：专家 skill 规定 **唯一** 脚本 / 委派行。
5. **回复**（DeepSeek）：固定模板或原样 `WECHAT_USER_REPLY` / `WECHAT_STOCK_CARD`。

可选进度（仍由 DeepSeek 输出，桥只转发）：

```text
WECHAT_PROGRESS: [ScreenAgent] 正在截图
```

## 域 → 专家 skill → 动作

| 域 | 先 load 的专家 skill | 再 load 的 atomic skill / 动作 |
|----|----------------------|--------------------------------|
| screen | `weclaw-screen-agent` | screenshot / ocr / wake / off 四选一 |
| file | `weclaw-file-agent` | `open-file-fast.ps1` 等 |
| browser | `weclaw-browser-agent` | `bilibili-music` |
| doc | `weclaw-doc-agent` | desktop-interact / 文档脚本 |
| sys | `weclaw-sys-agent` | **仅** `WECLAW_DELEGATE: openclaw-unlocker` |
| info | `weclaw-info-agent` | `wechat-stock-info` |
| compound | `wechat-task-orchestrator` | 按步 load 上表专家 |

**简单任务：** 本表只走 **一行域** → 一个专家 → **一次** bash（解锁除外）。  
**复合任务：** 只 load orchestrator；orchestrator 按步 load 专家，每步仍遵守上表。

## 易混语义（必须由 DeepSeek 裁决，桥不介入）

| 用户说法 | 域 | 禁止 |
|----------|-----|------|
| 检索 / 看屏幕上有什么 | screen → **OCR** | sys 解锁 |
| 截图 / 截屏 | screen → screenshot | 解锁 |
| 关屏 | screen → off | 解锁 |
| 解锁 / 进桌面 | sys → delegate | bash unlock、OCR |
| 锁屏（无「解」） | 非解锁 | openclaw-unlocker |

## 禁止

- 假设 WeClaw 会按关键词选脚本（`simple_bypass` 已废弃）。
- 为「省事」跳过专家 skill 直接 bash（简单任务除外：专家 skill 内已写明唯一脚本时可一次 bash）。
- 在桥层增加第二套意图分类或本地 NLU。
- 解锁由 Agent bash `unlock-screen.ps1`（只能 `WECLAW_DELEGATE`，由 **大脑输出** 后桥 **仅执行**）。

## 与 `WECLAW_DELEGATE` 的关系

| 步骤 | 谁做 | 是否调用 DeepSeek API |
|------|------|------------------------|
| 理解「用户要解锁」 | DeepSeek + 本 router + sys 专家 | **是** |
| 输出 `WECLAW_DELEGATE: openclaw-unlocker` | DeepSeek | **是**（同一会话） |
| 运行 `unlock-screen.ps1` | WeClaw Go | **否**（纯执行，无语义） |
| 把 `WECHAT_USER_REPLY` 发微信 | WeClaw 规范化 | **否** |

**委派 = 大脑已决策后的机械执行，不是绕过大脑的语义路由。**
