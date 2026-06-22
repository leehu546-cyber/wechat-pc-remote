---
name: wechat-screen-unlock
description: MANDATORY for unlock only — 解锁, 解锁屏幕, 解锁电脑, 解除锁屏, 进到桌面, 锁屏输密码. NOT for 截图/关屏/看屏幕内容/OCR.
---

# 微信解锁屏幕 (wechat-screen-unlock)

## 何时加载

用户明确要 **离开锁屏、进入桌面、输入锁屏密码**：

- 解锁 / 解锁屏幕 / 解锁电脑 / 解除锁屏
- 进到桌面 / 锁屏输密码 / 给我解锁

**不是解锁（禁止加载本 skill）：**

- 关屏 / 关屏幕 / 关闭显示器 → `wechat-screen-off`
- 截图 / 截屏 → `wechat-screenshot`
- 看屏幕文字 / 检索屏幕内容 / OCR → `wechat-screen-ocr`（读内容，不解锁）
- 亮屏 → `wechat-screen-on`

---

## 执行协议（强制，单回合，禁止 bash）

1. （可选）`WECHAT_PROGRESS: 正在唤醒并输入锁屏密码`
2. **唯一动作**：输出 exactly one line：

   ```text
   WECLAW_DELEGATE: openclaw-unlocker
   ```

3. **禁止**在本回合调用任何 tool（含 `unlock-screen.ps1`、截图、亮屏脚本）。
4. WeClaw 桥会调用本地 `scripts/unlock-screen.ps1`，并按脚本 `WECHAT_USER_REPLY` 生成最终微信回复（**你输出的 delegate 行用户看不到**）。
5. 你**无需**再写收尾句；若误写了也会被桥侧脚本结果覆盖。

---

## 禁止

- 直接 bash `unlock-screen.ps1`（只能委派）
- 截图 + 点击密码框
- 把「截图」「关屏」「检索屏幕内容」当成解锁

密码配置：`%USERPROFILE%\.weclaw\unlock-screen.json`
