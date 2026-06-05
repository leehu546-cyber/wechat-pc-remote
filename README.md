# WeChat Bridge

通过微信 ClawBot（腾讯 iLink 官方 API）把消息转给本机 WeClaw，再由 OpenCode ACP 在当前电脑上处理任务、读写文件和运行命令。

## 当前主方案

```text
手机微信 ClawBot -> weclaw.exe -> opencode acp -> D:\cursor\61
```

- **WeClaw**：微信桥接进程，负责接收 ClawBot 消息并转发给 Agent。
- **OpenCode ACP**：默认 Agent，模型为 `opencode/deepseek-v4-flash-free`。
- **工作目录**：`D:\cursor\61`。
- **微信命令**：`/info`、`/cwd`、`/new`、`/help`；可用 `/claude`、`/codex` 切换 Agent。
- **回复风格**：默认只发一条最终结果；处理期间显示微信「正在输入」，不推送「已收到/处理中」等进度文字（`progress.enabled: false`）。
- **新消息打断**：`routing.cancel_previous: true`（需本地 `weclaw.exe` 含 `session/cancel` 补丁，见 `weclaw/` 子仓库）。
- **本地快路由**：`你好`、`状态`、`打开/关闭 Edge` 不经过 Agent；发 `停止` 可取消当前任务。
- **自愈**：`scripts/weclaw-watchdog.ps1`（`setup-always-on.ps1` 可注册每 5 分钟检查）。

## 快速开始

### 1. 依赖

- Node.js >= 18
- OpenCode CLI：`npm install -g opencode-ai`
- 微信 8.0.70+，开启 ClawBot 插件
- 本机已构建 `weclaw.exe`

### 2. 配置

```powershell
D:\cursor\61\scripts\setup-gemini-opencode.ps1
D:\cursor\61\scripts\init-weclaw-opencode.ps1
```

### 3. 启动

```powershell
D:\cursor\61\scripts\start-weclaw.ps1
```

首次运行会显示二维码，用微信 ClawBot 扫码。之后直接在微信里发消息即可。

### 4. 开机自启（可选）

```powershell
D:\cursor\61\scripts\setup-always-on.ps1
```

### 5. 查看状态

```powershell
D:\cursor\61\scripts\status.ps1
```

## 卡死恢复

如果电脑已经执行任务，但微信一直没有最终回复，通常是 Agent 任务还没有结束，例如脚本里有长驻循环。

```powershell
D:\cursor\61\scripts\restart-weclaw.ps1
```

然后在微信里发送 `/new` 清空当前会话。日常使用建议一次只发一条任务，等待 2 分钟仍无回复再恢复。

也可手动运行 `scripts/weclaw-watchdog.ps1` 检查并重启桥接。

**注意：** `init-weclaw-opencode.ps1` 仅合并缺失配置项，不会覆盖你已改的 `progress` / `routing`。

## 构建 WeClaw

如果本地还没有 `weclaw\weclaw.exe`：

```powershell
cd D:\cursor\61
git clone --depth 1 https://github.com/fastclaw-ai/weclaw.git
cd weclaw
go build -o weclaw.exe .
```

`weclaw/` 是本地 fork（含 `session/cancel` 等补丁），已被 `.gitignore` 忽略；修改后必须 `go build` 并 `restart-weclaw.ps1`。

## 项目结构

```text
├── .opencode/AGENTS.md            # OpenCode 微信控制规则
├── docs/                          # 项目记录与补充说明
├── scripts/                       # 配置、启动、状态、恢复脚本
├── wechat-local-chat/             # 遗留自研桥接，仅作历史参考
└── README.md                      # 当前主方案入口
```

## 相关文档

### 主项目

| 文件 | 说明 |
|------|------|
| [docs/操作日志.md](docs/操作日志.md) | 关键操作记录 |
| [微信ClawBot实施指南.md](微信ClawBot实施指南.md) | ClawBot 与主方案调研记录 |
| [微信转发CLI使用指南.md](微信转发CLI使用指南.md) | cli-in-wechat 备选方案 |
| [docs/legacy-wechat-local-chat.md](docs/legacy-wechat-local-chat.md) | 遗留 Ollama + OpenCode serve 自研桥接 |

### 其他主题

以下文档不是微信桥接主方案，只是同一目录下的远程控制笔记：

| 文件 | 说明 |
|------|------|
| [Codex公司电脑SSH远程连接操作.md](Codex公司电脑SSH远程连接操作.md) | Codex/SSH 远程项目控制 |
| [公司电脑桌面远程控制方案.md](公司电脑桌面远程控制方案.md) | 远程桌面接管公司电脑 |
| [微信本地对话使用指南.md](微信本地对话使用指南.md) | 早期本地对话说明 |
