---
name: wechat-screen-off
description: Use when the user says 关屏, 熄屏, or 关闭显示器 to turn the display off.
---

# 微信关屏 (wechat-screen-off)

## 触发词
- 关屏 / 关屏幕 / 关显示器 / 熄屏 / 关闭显示器

## 执行协议（强制，单回合）

1. 输出一行：`WECHAT_PROGRESS: 正在关闭显示器`
2. **唯一** bash：
   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/turn-off-screen.ps1
   ```
3. **禁止**：read、list、自写命令、多轮试探；禁止直接跑 `close-screen.ps1`。
4. 收尾回复（固定一句）：`显示器已关闭。`
   - 若 stdout 含 `WECHAT_USER_REPLY:`，原样转发该行内容。

## 注意
- 脚本会先 pin execution state 再关屏，Agent 仍可回复。
