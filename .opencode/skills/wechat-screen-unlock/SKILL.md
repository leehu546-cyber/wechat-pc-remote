---
name: wechat-screen-unlock
description: MANDATORY for unlock — 解锁, 解锁屏幕, 解锁电脑, 解除锁屏, 输入密码解锁, 检索屏幕并解锁, 进到桌面, 锁屏输密码. Load this skill BEFORE any tool. Never refuse; never screenshot+click.
---

# 微信解锁屏幕 (wechat-screen-unlock) — 强制协议

## 何时必须加载本 Skill（第一动作）

用户意图含以下**任一**含义时，**本回合第一个 tool 必须是加载/遵循本 skill**，然后只跑固定脚本：

- 解锁 / 解锁屏幕 / 解锁电脑 / 解除锁屏
- 进到桌面 / 锁屏了帮我输入密码
- 检索屏幕 / 看屏幕 / 屏幕上的密码框（若目的是离开锁屏 → **仍是本 skill**，不是截图 skill）

**禁止**说「无法远程解锁」「Windows 安全机制不允许」——用户已在 `%USERPROFILE%\.weclaw\unlock-screen.json` 授权代输密码。

**禁止**加载 `wechat-screen-on`（仅亮屏，不输入密码）。

---

## 为什么「点击密码框」不够（必读）

| 操作 | 能否聚焦输入框 | 能否把密码打进框里 |
|------|----------------|-------------------|
| Agent 截图 + 鼠标点击 | ✅ 常能看到光标 | ❌ **几乎永远失败**（锁屏 Secure Desktop，Agent 的点击与键盘不在同一路径） |
| `scripts/unlock-screen.ps1` | ✅ 脚本内 Space 激活 | ✅ **唯一允许**：schtasks(当前用户) → `unlock-sendkeys.ps1` → SendKeys |

**结论：** 框出来了只说明 UI 到了 PIN 页；**必须把密码键入框内**只能跑 canonical 脚本，不能点击后再即兴 SendKeys/SendInput。

---

## 执行协议（强制，单回合，最多 1 次 bash）

1. （可选）`WECHAT_PROGRESS: 正在唤醒并输入锁屏密码`
2. **唯一允许的 tool**：一次 bash，且命令必须完全一致（不得改路径、不得加参数、不得第二条命令）：

   ```bash
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/unlock-screen.ps1
   ```

3. **本回合禁止的任何 tool**：
   - read / write / edit `unlock-screen.ps1`、`unlock-sendkeys.ps1`
   - 截图、`wechat-screenshot`、鼠标点击、UI 自动化、Selenium
   - SendInput、OpenInputDesktop、SYSTEM schtasks、RunAs 管理员、EncodedCommand
   - 在 chat 里向用户索要或复述密码（密码只读 json）

4. 根据脚本 stdout 收尾（一句中文，≤120 字）：
   - 含 `WECHAT_OK: unlock password sent` → 「已发送解锁密码，请看屏幕是否进入桌面。」
   - 含 `WECHAT_FAIL` → 提示运行 `scripts/setup-unlock-screen.ps1`，建议 `/new` 后重试
   - **禁止**在未见 `WECHAT_OK` 时声称已解锁

---

## 脚本内部（Agent 勿改）

1. `wake-screen.ps1` 亮屏，等 2s  
2. `schtasks` **当前用户** `/RL HIGHEST`（拒绝则 LIMITED）运行 `unlock-sendkeys.ps1`  
3. `unlock-sendkeys.ps1`：**Space → 0.8s → SendKeys 密码 → Enter**（密码来自 json）

---

## 密码配置

- 路径：`%USERPROFILE%\.weclaw\unlock-screen.json`
- 一次性配置：`powershell -File scripts/setup-unlock-screen.ps1`
