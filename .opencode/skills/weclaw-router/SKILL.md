---
name: weclaw-router
description: JSON-only intent classifier — implemented as agents.router ACP session. WeClaw calls it first; do NOT load this skill in Specialist unless debugging.
---

# WeClaw Router（真 Router · 独立 ACP）

## 实现方式（Plan A）

| 步骤 | 谁做 |
|------|------|
| 1 | WeClaw 调 `agents.router`（独立 ACP，只输出 JSON） |
| 2 | WeClaw Go 解析 JSON，机械跑脚本或转 Specialist |
| 3 | 复杂步骤由 `agents.opencode`（Specialist）执行 |

**本 skill 文件供人类/文档参考；Router 的 system_prompt 在 `scripts/init-weclaw-opencode.ps1` 写入 config。**

## JSON 输出格式

```json
{
  "domain": "screen|file|browser|doc|sys|info|compound|chat",
  "action": "screenshot|ocr|wake|off|unlock|open_file|music|desktop_typing|stock|orchestrate|chat",
  "compound": false,
  "params": {}
}
```

## 易混语义

| 用户说法 | domain | action |
|----------|--------|--------|
| 检索 / 看屏幕文字 | screen | ocr |
| 截图 | screen | screenshot |
| 关屏 | screen | off |
| 解锁 / 进桌面 | sys | unlock |
| 锁屏（无「解」） | chat | chat |
| 复合任务 | compound | orchestrate |

## Specialist 侧

Specialist（opencode）收到 `[ROUTER:domain/action]` 前缀后 load 对应 `weclaw-*-agent` skill，不再负责初次分类。
