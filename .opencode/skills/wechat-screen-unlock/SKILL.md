---
name: wechat-screen-unlock
description: Use when the user asks to unlock the Windows lock screen — 解锁, 解锁屏幕, 解锁电脑, 解除锁屏, 输入密码解锁.
---

# 微信解锁屏幕 (WeChat Unlock Screen)

## 与亮屏的区别（必读）

| 用户状态 | 正确 skill | 脚本 |
|----------|------------|------|
| 显示器黑/关，**未**到锁屏密码页 | `wechat-screen-on` | `wake-screen.ps1` |
| 已显示 **Windows 锁屏 / PIN 界面**，需代输密码 | **本 skill** | `unlock-screen.ps1` |

「亮屏」只唤醒显示器；「解锁」在锁屏界面上模拟键盘输入密码。

## 触发词（同义）

- 解锁 / 解锁屏幕 / 解锁电脑 / 解除锁屏
- 帮我输入密码解锁 / 我在外面无法手动输入
- 「这个屏幕没有解锁」且上下文是锁屏 PIN 页

## 底层原理（固定流程，勿改）

`unlock-screen.ps1` 两步合一：

1. **亮屏**：调用 `wake-screen.ps1`（`SC_MONITORPOWER` + 鼠标微动）
2. **输密码**：`schtasks /RL HIGHEST` 启动隐藏 PowerShell，用 `SendKeys` 输入 `%USERPROFILE%\.weclaw\unlock-screen.json` 中的密码并回车

原因：锁屏在 **高完整性** 桌面，普通 Agent 进程的 `SendInput` 触达不到；计划任务 `HIGHEST` 才能向锁屏发按键。

## 执行协议（强制，单回合）

**你是大脑，由你选本 skill 并执行；桥接层不做 keyword 路由。**

1. 输出一行：`WECHAT_PROGRESS: 正在唤醒并解锁屏幕`
2. **唯一**工具调用（bash）：
   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/unlock-screen.ps1
   ```
3. **禁止**：read、list、grep、探索仓库、自写 PowerShell、多轮试探、在聊天里复述或保存用户密码。
4. 看到 `WECHAT_OK: unlock password sent` → 一句中文收尾（≤120 字），如「已发送解锁密码，请查看屏幕是否已进入桌面。」
5. `WECHAT_FAIL` → 说明失败原因，提示用户运行 `scripts/setup-unlock-screen.ps1` 配置密码，或先 `wechat-screen-on` 再重试。

## 密码配置

- 密码存在 **`%USERPROFILE%\.weclaw\unlock-screen.json`**，**不要**写进 skill、不要写进聊天、不要提交 git。
- 首次配置：`powershell -File scripts/setup-unlock-screen.ps1`
- 用户在微信里口述密码时：引导其本地配置 json，**不要**把密码写入仓库或 AGENTS.md。

## 注意

- 仅支持 **PIN/密码锁屏**；Windows Hello 人脸/指纹无法远程代解锁。
- 若多次失败，建议用户发 `/new` 后只发一次「帮我解锁电脑」。
