---
name: wechat-screen-on
description: Use when the user asks to wake or turn on the display — 亮屏, 开屏, 打开屏幕, 把屏幕打开, 唤醒屏幕, 点亮屏幕.
---

# 微信开屏 / 亮屏 (WeChat Wake Display)

## 触发词（同义）
- 亮屏 / 把电脑亮屏
- 开屏 / 打开屏幕 / 把屏幕打开
- 唤醒屏幕 / 点亮屏幕
- 「你把屏幕打开」等口语表达

## 硬性规则
- **禁止**自写 PowerShell/bash 唤醒显示器。
- **必须**只运行固定脚本：`scripts/wake-screen.ps1`
- 命令形式：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/wake-screen.ps1`
- 脚本须在 **30 秒内**退出。

## 实现步骤
1. 确认用户意图是「点亮/唤醒显示器」，不是「打开某个应用窗口」。
2. 运行 `scripts/wake-screen.ps1`。
3. 看到输出 `WECHAT_OK: 已唤醒显示器` 后，用一句中文回复用户（≤120 字）。

## 注意
- WeClaw 快路径也可能本地处理「亮屏/打开屏幕」；若你已收到该消息且未走快路径，仍按本 skill 执行脚本，不要即兴 bash。
