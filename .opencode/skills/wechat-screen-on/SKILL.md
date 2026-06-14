---
name: wechat-screen-on
description: Use when the user says 亮屏, 开屏, or 唤醒显示器 to turn the display on.
---

# 微信亮屏 (wechat-screen-on)

## 触发词
- 亮屏 / 开屏 / 打开屏幕 / 唤醒显示器

## 执行协议（强制，单回合）

1. 输出一行：`WECHAT_PROGRESS: 正在唤醒显示器`
2. **唯一** bash：
   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/wake-screen.ps1
   ```
3. **禁止**：read、list、自写命令、多轮试探。
4. 收尾回复（固定一句）：`屏幕已点亮。`
   - 若 stdout 含 `WECHAT_USER_REPLY:`，原样转发该行内容。

## 注意
- 仅亮屏，不解锁、不输入密码。解锁见 `wechat-screen-unlock`。
