---
name: wechat-screen-ocr
description: Use when the user wants to read or understand on-screen text without vision — 看下屏幕, 屏幕上有什么, 读取屏幕文字, 检索屏幕内容, OCR, 屏幕识别. Not for unlock (use wechat-screen-unlock).
---

# 微信屏幕 OCR (wechat-screen-ocr)

DeepSeek **无视觉**，不能分析截图图片。本 skill 用 Windows 内置 OCR 把屏幕文字提取出来，由你阅读并回复用户。

## 与截图 / 解锁的区别

| 意图 | Skill | 脚本 |
|------|-------|------|
| **发图片**到微信 | `wechat-screenshot` | `screenshot.ps1` |
| **读文字**给你分析 | **本 skill** | `screen-ocr.ps1` |
| **离开锁屏**输密码 | `wechat-screen-unlock` | 委派 unlocker |

## 执行协议（强制，单回合）

1. `WECHAT_PROGRESS: 正在识别屏幕文字`
2. **唯一** bash：
   ```bash
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/screen-ocr.ps1
   ```
3. **禁止**：截图 skill、自写 OCR、Tesseract 安装、多轮 read/list。
4. 读 tool 输出中 `--- OCR ---` 后的文字，收尾回复（固定模板）：
   `屏幕上主要是：{≤40字总结}`
5. `WECHAT_FAIL` → `没做成：{原因}`

## 注意

- 脚本会先 `wake-screen.ps1` 再截全屏 OCR。
- OCR 含屏幕上所有可见文字，回复时勿复述敏感信息（密码、令牌等）。
