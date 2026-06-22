---
name: weclaw-screen-agent
description: Screen domain expert — loaded by the brain AFTER weclaw-router. Screenshot, OCR, wake display, turn off display. NOT unlock (use weclaw-sys-agent). Same DeepSeek session only.
---

# ScreenAgent（屏幕专家 · 大脑内角色）

由 **DeepSeek 大脑** 在 load `weclaw-router` 后 load 本 skill。**不是**独立 LLM。

## 域内互斥路由（DeepSeek 必须四选一）

| 用户语义 | load atomic skill | 唯一脚本 |
|----------|-------------------|----------|
| 截图 / 截屏 / 发图 | `wechat-screenshot` | `scripts/screenshot.ps1` |
| 看文字 / 检索 / OCR / 屏幕上有什么 | `wechat-screen-ocr` | `scripts/screen-ocr.ps1` |
| 亮屏 / 开屏 | `wechat-screen-on` | `scripts/wake-screen.ps1` |
| 关屏 / 熄屏 | `wechat-screen-off` | `scripts/turn-off-screen.ps1` |

## 禁止

- 解锁、输 PIN → **不要** load 本 skill；改 load `weclaw-sys-agent`
- 同一回合混跑多个屏幕脚本（复合任务走 orchestrator 分步）
- 即兴 PowerShell

## 回复

优先原样 `WECHAT_USER_REPLY`；OCR 成功用模板：`屏幕上主要是：{≤40字}`
