# WeChat Bridge — 微信 ClawBot 桥接项目

通过微信 ClawBot（腾讯 iLink 官方 API）与本机服务对话。

## 当前阶段：本地模型纯对话

```
手机微信 ClawBot  ↔  wechat-local-chat  ↔  Ollama (qwen2.5:7b)
```

后续可扩展为微信 → Codex / Claude Code CLI。

## 快速开始

### 1. 依赖

- Node.js >= 18
- Ollama（已拉取 `qwen2.5:7b`）
- 微信 8.0.70+，开启 ClawBot 插件

### 2. 安装 iLink 协议层（一次性）

```powershell
cd D:\cursor\61
git clone --depth 1 https://github.com/sgaofen/cli-in-wechat.git
cd cli-in-wechat
npm install
npm run build
```

### 3. 启动本地对话

```powershell
D:\cursor\61\scripts\start-wechat-local-chat.ps1
```

扫码登录后，在微信 ClawBot 里直接发消息即可。

## 项目结构

```
├── wechat-local-chat/     # 阶段一：微信 ↔ Ollama 纯对话（本项目代码）
├── scripts/               # 启动与配置脚本
├── docs/                  # 文档与操作日志
├── README.md
└── .gitignore
```

## 文档

| 文件 | 说明 |
|------|------|
| [docs/操作日志.md](docs/操作日志.md) | **关键操作记录（按时间）** |
| [微信本地对话使用指南.md](微信本地对话使用指南.md) | 本地对话用法 |
| [微信转发CLI使用指南.md](微信转发CLI使用指南.md) | 微信 → CLI（下一阶段） |
| [微信ClawBot实施指南.md](微信ClawBot实施指南.md) | 整体调研与方案 |

## 操作日志

所有关键步骤记录在 **[docs/操作日志.md](docs/操作日志.md)**，每做一步应追加一条记录。
