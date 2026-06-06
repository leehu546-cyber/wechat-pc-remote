---
name: wechat-screen-off
description: Use when the user asks to turn off the display — 关屏, 熄屏, 关闭屏幕, 把屏幕关闭, 屏幕关闭, 关显示器.
---

# 微信关屏 (WeChat Turn Off Display)

## 触发词（同义）
- 关屏 / 熄屏 / 关闭屏幕 / 把屏幕关闭 / 屏幕关闭
- 关显示器 / 关闭显示器
- 「你把屏幕关闭」等口语表达

## 执行协议（强制，单回合）

**你是大脑，由你选本 skill 并执行；桥接层不做 keyword 路由。**

1. 输出一行：`WECHAT_PROGRESS: 正在关闭显示器`
2. **唯一**工具调用（bash）：
   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/turn-off-screen.ps1
   ```
3. **禁止**：read、list、grep、探索仓库、自写 PowerShell/bash、多轮试探。
4. 看到 `WECHAT_OK: 已关闭显示器` 后，用一句中文回复（≤120 字）。

## 与锁屏区分
- 用户明确说「锁屏」→ 可用 `rundll32.exe user32.dll,LockWorkStation`（若项目有 lock 脚本则优先脚本）。
- 用户说「关屏/熄屏/关闭屏幕」→ **只用本 skill**，不要锁屏。

## 技术说明
- 脚本在关屏前会 `SetThreadExecutionState`，避免同机 Agent 因显示器断电挂死；仍须一步执行、立即收尾。
