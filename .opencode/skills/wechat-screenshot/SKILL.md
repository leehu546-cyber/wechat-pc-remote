---
name: wechat-screenshot
description: Use when the user says 截图 or 截屏 to take a screenshot and send it via WeChat.
---

# 微信截图发送 (WeChat Screenshot)

## 触发词
- 截图 / 截屏 / 屏幕截图 / 发截图

## 硬性规则
- **禁止**自写 PowerShell/bash 截屏（显示器关闭时易挂死）。
- **必须**只运行固定脚本：`scripts/screenshot.ps1`
- 命令形式：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/screenshot.ps1`
- 脚本须在 **90 秒内**退出（含唤醒显示器与发图）。

## 实现步骤
1. 运行 `scripts/screenshot.ps1`。
2. 脚本会自动唤醒显示器 → 截屏 → 经 weclaw 发图 → 清理。
3. 等待输出 `WECHAT_OK:` 后，用一句中文回复（≤120 字）；图片已发则不必描述画面细节。

## 注意事项
- 发送成功后不要再用长文描述图片内容。
- 用户说「没收到」→ 再运行一次脚本即可。
- 关屏/开屏类指令见 `wechat-screen-off` / `wechat-screen-on` skill，不要混用 bash。
