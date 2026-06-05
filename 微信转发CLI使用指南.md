# 微信消息转发给 CLI — 使用指南

你要的形式就是：**手机微信发消息 → 本机桥接服务 → Claude Code / Codex 等 CLI 执行 → 结果回微信**。

本项目已选用 [cli-in-wechat](https://github.com/sgaofen/cli-in-wechat)，架构如下：

```
微信 ClawBot（手机）
    ↕  腾讯 iLink API（官方，不封号）
cli-in-wechat（本机桥接，D:\cursor\61\cli-in-wechat）
    ↕  spawn / Agent SDK
claude -p  /  codex exec  （本机已检测到两者）
    ↕
你的项目目录 + 终端
```

---

## 一、一次性准备

### 1. 微信侧

- 微信 8.0.70+
- 开启 ClawBot 插件：**我 → 设置 → 插件 → ClawBot**

### 2. 本机 CLI（已就绪）

| 工具 | 状态 |
|------|------|
| Claude Code | 已检测到 |
| Codex CLI | 已检测到 |

首次使用前请在本机终端完成各自登录（`claude` / `codex` 按提示认证）。

### 3. 桥接配置

配置文件：`C:\Users\你的用户名\.wx-ai-bridge\config.json`

已为你生成默认配置（工作目录 `D:\cursor\61`，默认工具 `codex`）。可改：

```json
{
  "defaultTool": "codex",
  "workDir": "D:\\cursor\\61",
  "cliTimeout": 300000,
  "allowedUsers": []
}
```

- `defaultTool`：`claude` 或 `codex`
- `workDir`：CLI 默认在哪个目录干活
- `allowedUsers`：留空表示仅你自己用；填微信 user id 可限制发送者

---

## 二、启动桥接（每次使用前）

在 PowerShell 执行：

```powershell
D:\cursor\61\scripts\start-cli-in-wechat.ps1
```

或：

```powershell
cd D:\cursor\61\cli-in-wechat
npm start
```

**首次启动**会显示二维码 → 用微信 ClawBot **扫码并确认**。登录凭证保存在 `~\.wx-ai-bridge\credentials.json`，之后无需重复扫码（除非 token 过期）。

保持该窗口/进程运行，不要关。关掉就收不到微信消息了。

---

## 三、微信里怎么用

### 基本对话

| 你发 | 效果 |
|------|------|
| `列出当前目录文件` | 发给默认 CLI（codex）执行 |
| `@claude 解释 router.ts` | 指定 Claude Code |
| `@codex 修复这个 bug` | 指定 Codex |
| `@cc 写单元测试` | `@cc` 是 claude 别名 |
| `@cx 跑一下测试` | `@cx` 是 codex 别名 |

切换 `@claude` / `@codex` 后，后续不带前缀的消息会默认发给刚选的工具。

### 工作目录

```
/cwd D:\cursor\61
/cwd                    ← 查看当前目录
```

### 会话管理

```
/new                    ← 新对话，清空上下文
/resume                 ← 列出历史会话
/resume 2               ← 恢复第 2 个会话
/sessions               ← 查看当前会话信息
```

### 工具接力

```
@claude 分析项目结构
>> 根据上面结果写测试    ← 把上条 CLI 输出当下文继续
@claude>codex 先分析再改  ← 链式：claude 输出 → codex
```

### 引用消息

在微信里**引用**某条 Bot 回复再打字，会自动路由到当时用的那个 CLI，无需再打 `@`。

### 帮助

```
/help
```

完整命令见 [cli-in-wechat README](D:\cursor\61\cli-in-wechat\README.md)。

---

## 四、验证是否打通

1. 启动 `start-cli-in-wechat.ps1`，扫码登录
2. 在微信 ClawBot 里发：`列出当前目录的文件`
3. 应收到包含 `D:\cursor\61` 下真实文件名的回复

若只回复空话、没有真实路径，说明 CLI 未正确执行，检查终端里是否有报错。

---

## 五、和 weclaw 的区别（你为什么选这个形式）

| | cli-in-wechat | weclaw |
|--|---------------|--------|
| 形态 | 明确「微信 → CLI spawn」 | 同样桥接，偏 Go 单二进制 |
| 路由 | `@claude` / `@codex` + 40+ `/` 命令 | `/cc` `/cx` 等别名 |
| 定制 | TypeScript 源码清晰，易改 | 适合不想碰 Node |
| 本机状态 | 已 build，可直接用 | `weclaw.exe` 也已构建 |

**你选「转发给 CLI」→ 用 cli-in-wechat 最合适。**

---

## 六、公司电脑（可选扩展）

微信只能连到**跑着桥接的那台机器**。

| 方案 | 做法 |
|------|------|
| 公司机直连 | 在公司电脑同样安装 cli-in-wechat，扫码，设 `workDir` 为公司项目路径 |
| 家里桥接 + SSH | 家里跑桥接，在微信里让 CLI 通过 SSH 操作公司机（需你先配好 [Codex公司电脑SSH远程连接操作.md](Codex公司电脑SSH远程连接操作.md)） |
| 多机 | 以后可用 [ClawCenter](https://github.com/ruihanglix/clawcenter) 做中央路由 |

要看公司电脑桌面画面，仍用 RDP / RustDesk，与微信 CLI 互补。

---

## 七、常见问题

**Q：发消息没反应？**  
桥接进程是否在跑；是否已扫码登录；看终端有无报错。

**Q：提示 session 过期？**  
删除 `~\.wx-ai-bridge\credentials.json`，重启后重新扫码。

**Q：回复很慢？**  
CLI 在执行命令，复杂任务可能几分钟；微信会显示「正在输入」。

**Q：想默认用 Claude 而不是 Codex？**  
改 `config.json` 里 `"defaultTool": "claude"`，重启桥接。

**Q：想后台常驻？**  
可用 Windows 任务计划程序，开机运行 `node D:\cursor\61\cli-in-wechat\dist\index.js`，或开一个最小化 PowerShell 窗口。

---

## 八、相关文件

| 路径 | 说明 |
|------|------|
| `D:\cursor\61\cli-in-wechat\` | 桥接源码与构建产物 |
| `D:\cursor\61\scripts\start-cli-in-wechat.ps1` | 一键启动 |
| `D:\cursor\61\架构笔记-cli-in-wechat.md` | 三层架构说明 |
| `~\.wx-ai-bridge\` | 登录凭证、会话、配置 |
