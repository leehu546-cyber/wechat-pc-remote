---
name: weclaw-router
description: JSON planner reference — implemented as WeClaw agents.planner (DeepSeek HTTP). Do NOT load in Specialist unless debugging planner output.
---

# WeClaw Planner（真 Router · DeepSeek HTTP）

## 实现方式

| 步骤 | 谁做 |
|------|------|
| 1 | WeClaw 调 `agents.planner`（HTTP deepseek-chat，**只输出 JSON，无工具**） |
| 2 | WeClaw Go 解析 JSON，机械跑脚本 / 分步 / Windows-Use GUI |
| 3 | 无法机械完成的步 → `agents.opencode`（Specialist，带 `[PLANNER:…]` 前缀） |

Planner system_prompt 在 `scripts/init-weclaw-opencode.ps1` 写入 config。

## JSON 输出格式

```json
{
  "domain": "screen|file|browser|doc|sys|info|compound|chat",
  "action": "screenshot|ocr|wake|off|unlock|open_file|music|desktop_typing|stock|gui|orchestrate|chat",
  "compound": false,
  "params": {"goal": "打开 RustDesk 主窗口"},
  "steps": [
    {"action": "unlock"},
    {"action": "gui", "goal": "打开 RustDesk 并置于前台"},
    {"action": "screenshot"}
  ]
}
```

## 易混语义

| 用户说法 | 正确规划 |
|----------|----------|
| 检索 / 看屏幕文字 / 网盘下载多少 | `ocr` 或 `steps: [gui, ocr]` — **不是** 单独 screenshot |
| 截图 | `screenshot` |
| 关屏 | `off` |
| 解锁 / 进桌面 | `unlock` |
| 锁屏（无「解」） | `chat` |
| 打开 RustDesk + 截图 | `steps: [gui, screenshot]` |
| 复合任务 | `compound` + `steps`（最多 5 步） |

## Specialist 侧

收到 `[PLANNER:domain/action]` 后 load 对应专家 skill；**每步最多 1 次 bash**；禁止向微信泄露英文 tool 标题或 skill 名。
