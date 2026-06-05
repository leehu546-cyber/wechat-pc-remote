# WeChat Bridge — 微信 ClawBot 桥接项目

通过微信 ClawBot（腾讯 iLink 官方 API）与本机 AI Agent 对话，控制电脑、读写文件。

## 当前方案：WeClaw + OpenCode

```
手机微信 ClawBot  ↔  weclaw.exe  ↔  opencode acp  ↔  D:\cursor\61
```

- **WeClaw**：微信桥接（单文件 `weclaw.exe`，后台守护）
- **OpenCode**：默认 Agent（ACP 长驻，模型 `opencode/deepseek-v4-flash-free`）
- 微信命令：`/info`、`/cwd`、`/new`、`/help`；切换 Agent：`/claude`、`/codex`

## 无回复 / 卡死时

**电脑已执行但微信没回？** WeClaw 要等 OpenCode 整条任务结束才发微信。长驻脚本（如 `while True`）会导致「正在输入」但永远没文字。

```powershell
D:\cursor\61\scripts\restart-weclaw.ps1
```

微信发 **`/new`** 清空会话。习惯：**一次只发一条**，等 2 分钟；没回就 restart，不要连发。

## 快速开始

### 1. 依赖

- Node.js >= 18
- OpenCode CLI：`npm install -g opencode-ai`
- 微信 8.0.70+，开启 ClawBot 插件
- 本机已构建 `weclaw.exe`（见下方）

### 2. 一次性配置

```powershell
D:\cursor\61\scripts\setup-gemini-opencode.ps1
D:\cursor\61\scripts\init-weclaw-opencode.ps1
```

### 3. 启动

```powershell
D:\cursor\61\scripts\start-weclaw.ps1
```

首次运行会弹出二维码，用微信 ClawBot 扫码。之后直接在微信发消息即可。

### 4. 开机自启（可选）

```powershell
D:\cursor\61\scripts\setup-always-on.ps1
```

### 5. 查看状态

```powershell
D:\cursor\61\scripts\status.ps1
```

## 构建 weclaw（若尚未构建）

```powershell
cd D:\cursor\61
git clone --depth 1 https://github.com/fastclaw-ai/weclaw.git
cd weclaw
go build -o weclaw.exe .
```

## 项目结构

```
├── scripts/               # 启动与配置脚本
│   ├── start-weclaw.ps1           # 主启动
│   ├── init-weclaw-opencode.ps1   # WeClaw 配置
│   ├── setup-gemini-opencode.ps1  # OpenCode 全局配置
│   ├── setup-always-on.ps1        # 开机自启
│   ├── restart-weclaw.ps1         # 卡死恢复
│   └── stop-wechat-local-chat.ps1 # 停掉旧桥接
├── .opencode/AGENTS.md            # OpenCode 微信控电脑规则
├── wechat-local-chat/     # 遗留：微信 ↔ Ollama 自研桥（不再维护）
├── docs/
└── README.md
```

## 文档

| 文件 | 说明 |
|------|------|
| [docs/操作日志.md](docs/操作日志.md) | 关键操作记录 |
| [微信ClawBot实施指南.md](微信ClawBot实施指南.md) | 整体调研与方案 |
| [微信转发CLI使用指南.md](微信转发CLI使用指南.md) | cli-in-wechat 备选 |
| [微信本地对话使用指南.md](微信本地对话使用指南.md) | 遗留 Ollama 桥接 |

## 回退到自研桥接

```powershell
D:\cursor\61\weclaw\weclaw.exe stop
D:\cursor\61\scripts\start-wechat-local-chat-background.ps1
```
