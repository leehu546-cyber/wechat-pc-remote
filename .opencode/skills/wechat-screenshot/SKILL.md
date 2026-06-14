---
name: wechat-screenshot
description: Use when the user says 截图 or 截屏 to take a screenshot and send it via WeChat.
---

# 微信截图发送 (WeChat Screenshot)

## 触发词
- 截图 / 截屏 / 屏幕截图 / 发截图

## 执行协议（强制，单回合）

1. 输出一行：`WECHAT_PROGRESS: 正在截图并发送`
2. **唯一**工具调用（bash）：
   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/screenshot.ps1
   ```
3. **禁止**：read、list、自写截屏命令、多轮试探。
4. 收尾回复（固定一句）：`截图已发到微信。`
   - 若 stdout 含 `WECHAT_USER_REPLY:`，原样转发该行内容。

## 注意事项
- 脚本会自动唤醒显示器 → 截屏 → 经 weclaw 发图 → 清理（最长 90 秒）。
- 失败时回复：`没做成：截图发送失败。`
- 关屏/开屏见 `wechat-screen-off` / `wechat-screen-on`，不要混用即兴 bash。
