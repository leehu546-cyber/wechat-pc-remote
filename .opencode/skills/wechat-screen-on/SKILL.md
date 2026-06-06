---
name: wechat-screen-on
description: Use when the user asks to wake or turn on the display — 亮屏, 开屏, 打开屏幕, 把屏幕打开, 唤醒屏幕, 点亮屏幕.
---

# 微信开屏 / 亮屏 (WeChat Wake Display)

## 触发词（同义）
- 亮屏 / 把电脑亮屏 / 唤醒屏幕 / 点亮屏幕
- 开屏 / 打开屏幕 / 把屏幕打开
- 「你把屏幕打开」等口语表达

## 执行协议（强制，单回合）

**你是大脑，由你选本 skill 并执行；桥接层不做 keyword 路由。**

1. 输出一行：`WECHAT_PROGRESS: 正在唤醒显示器`
2. **唯一**工具调用（bash）：
   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/wake-screen.ps1
   ```
3. **禁止**：read、list、grep、探索仓库、自写 PowerShell/bash、多轮试探。
4. 看到 `WECHAT_OK: 已唤醒显示器` 后，用一句中文回复（≤120 字）。

## 注意
- 用户说「打开某个应用窗口」不是本 skill；仅「点亮/唤醒显示器」时用本 skill。
