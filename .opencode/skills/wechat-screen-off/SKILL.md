---
name: wechat-screen-off
description: Use when the user asks to turn off the display — 关屏, 熄屏, 关闭屏幕, 把屏幕关闭, 屏幕关闭, 关显示器.
---

# 微信关屏 (WeChat Turn Off Display)

## 触发词（同义）
- 关屏
- 熄屏
- 关闭屏幕 / 把屏幕关闭 / 屏幕关闭
- 关显示器 / 关闭显示器
- 「你把屏幕关闭」等口语表达

## 硬性规则
- **禁止**自写 PowerShell/bash 关显示器（会挂死或超时）。
- **必须**只运行固定脚本：`scripts/turn-off-screen.ps1`
- 命令形式：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/turn-off-screen.ps1`
- 脚本须在 **30 秒内**退出。

## 实现步骤
1. 确认用户意图是「关显示器/熄屏」，不是「锁屏」或「关机」。
2. 运行 `scripts/turn-off-screen.ps1`。
3. 看到输出 `WECHAT_OK: 已关闭显示器` 后，用一句中文回复用户（≤120 字）。

## 与锁屏区分
- 用户明确说「锁屏」→ 可用 `rundll32.exe user32.dll,LockWorkStation`（若项目有 lock-workstation 脚本则优先用脚本）。
- 用户说「关屏/熄屏/关闭屏幕」→ **只用本 skill**，不要锁屏。
