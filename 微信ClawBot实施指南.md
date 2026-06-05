# 微信 ClawBot 对话控制电脑 — 实施指南

本指南基于计划调研结果，在本机完成了工具构建、环境验证与架构分析，并给出公司电脑场景的部署建议与最终选型。

---

## 一、本机验证结果

### 1.1 环境检测

| 组件 | 状态 |
|------|------|
| Node.js v22.22.0 | 已安装 |
| Go 1.21.5（构建时自动拉取 1.25） | 已安装 |
| Git | 已安装 |
| Claude Code CLI | 已检测到 |
| Codex CLI | 已检测到 |
| Python | 未在 PATH 中（WeClaude 需 Python 3.11+） |

### 1.2 已克隆并构建的项目

| 项目 | 路径 | 构建结果 |
|------|------|----------|
| weclaw | `D:\cursor\61\weclaw\` | `weclaw.exe` 构建成功 |
| cli-in-wechat | `D:\cursor\61\cli-in-wechat\` | `npm install` + `npm run build` 成功 |
| WeClaude | `D:\cursor\61\WeClaude\` | 已克隆（需 Python 环境） |

### 1.3 登录与测试（需你手动完成扫码）

桥接服务启动后会显示二维码，**必须用微信 ClawBot 插件扫码确认**（AI 无法代扫）。

**前置条件：**
- 微信 8.0.70+，开启 ClawBot 插件（我 → 设置 → 插件）
- 电脑保持联网，桥接服务后台运行

**方式 A — weclaw（推荐先试）：**

```powershell
# 前台启动（首次会显示二维码）
D:\cursor\61\weclaw\weclaw.exe start

# 或使用快捷脚本
D:\cursor\61\scripts\start-weclaw.ps1
```

扫码成功后，在微信 ClawBot 对话中发送：

```
列出当前目录的文件
```

进阶命令：`/help`、`/cwd D:\cursor\61`、`/new`、`/cc 解释这段代码`

**方式 B — cli-in-wechat：**

```powershell
cd D:\cursor\61\cli-in-wechat
node dist/index.js

# 或使用快捷脚本
D:\cursor\61\scripts\start-cli-in-wechat.ps1
```

扫码成功后发送测试消息，或试 `@claude 列出当前目录`、`/help`。

**验证通过标准：**
- [ ] 微信收到 AI 回复
- [ ] 回复内容反映本机真实目录/文件（非纯聊天幻觉）
- [ ] `/cwd` 切换目录后，后续操作在新目录生效

---

## 二、cli-in-wechat 三层架构解析

这是 GitHub 上最值得借鉴的分层设计，适合自建桥接时参考。

### 2.1 整体数据流

```
手机微信 ClawBot
    ↕  iLink API (ilinkai.weixin.qq.com)
ilink/ 层 — 协议客户端
    ↕  解析后的 text / refText / media
bridge/ 层 — 路由、会话、格式化
    ↕  prompt + sessionId
adapters/ 层 — Claude / Codex / Gemini / Kimi / OpenCode
    ↕  spawn 或 Agent SDK
本机终端 + 文件系统
```

### 2.2 第一层：`ilink/` — 微信协议

| 文件 | 职责 |
|------|------|
| `auth.ts` | QR 登录：`get_bot_qrcode` → 轮询 `get_qrcode_status` → 保存 `bot_token` |
| `client.ts` | 长轮询 `getupdates`；缓存 `context_token`；`sendmessage` 分片发送；限流退避（`ret=-2`） |
| `types.ts` | iLink 协议类型定义 |

**关键设计点：**

1. **context_token 必须缓存**：用户先发消息，Bot 才能回复；按 `from_user_id` 存 Map
2. **poll cursor 持久化**：`get_updates_buf` 写入磁盘，重启不丢消息
3. **限流保护**：微信约每 10 条需用户回一条；`ret=-2` 时进入 2.5–7 分钟冷却
4. **媒体处理**：CDN AES-128-ECB 加解密；语音自动转文字；图片/文件下载后传给 Agent
5. **typing 指示器**：`getconfig` 取 ticket → `sendtyping` 每 5s 刷新

### 2.3 第二层：`bridge/` — 消息路由

| 文件 | 职责 |
|------|------|
| `router.ts` | 核心路由：`@claude` 前缀、引用消息智能路由、`/` 命令、`>>` 工具接力 |
| `session.ts` | 每用户 `sessionIds`、默认工具、工作目录等持久化到 `sessions.json` |
| `formatter.ts` | Agent 输出转微信可读纯文本（去 Markdown、截断长输出） |

**路由优先级（`getCli`）：**
1. 消息开头的 `@mention`（如 `@codex`）
2. 引用消息的 footer 解析出原工具
3. 当前 session 的 `defaultTool`

**会话管理：**
- 每个微信用户独立 `UserSettings`（workDir、model、sessionIds）
- CLI 模式用 `--resume <sessionId>` 保持上下文

### 2.4 第三层：`adapters/` — Agent 适配

| 文件 | 职责 |
|------|------|
| `base.ts` | 统一接口：`execute(prompt, settings, callbacks)` |
| `claude.ts` | Agent SDK 优先，降级 `claude -p`；支持 AskUserQuestion 转发微信 |
| `codex.ts` | `codex exec` + stdin 传参 |
| `registry.ts` | 自动检测 PATH 中已安装的 CLI |

**扩展新 Agent 只需：** 实现 `base.ts` 接口 + 在 `registry.ts` 注册，不动 `ilink/` 和 `router.ts` 核心逻辑。

### 2.5 与 weclaw 的对比

| 维度 | cli-in-wechat | weclaw |
|------|---------------|--------|
| 语言 | TypeScript | Go |
| Agent 模式 | 仅 CLI spawn | ACP + CLI + HTTP |
| 命令丰富度 | 40+ `/` 命令 | 基础 `/cwd` `/new` `/help` |
| 部署 | `node dist/index.js` | 单文件 `weclaw.exe` |
| 适合 | 学习架构、深度定制 | 开箱即用、后台守护 |

---

## 三、公司电脑场景评估

结合你已有的 [公司电脑桌面远程控制方案.md](公司电脑桌面远程控制方案.md) 和 [Codex公司电脑SSH远程连接操作.md](Codex公司电脑SSH远程连接操作.md)。

### 3.1 三种部署模式对比

| 模式 | 桥接位置 | 优点 | 缺点 | 适用条件 |
|------|----------|------|------|----------|
| **A. 公司机直连** | 公司电脑 | 最简单；手机直接控公司机；无需 VPN | 需公司 IT 允许装软件；Agent 有完整终端权限 | 公司允许个人桥接 + 7×24 开机 |
| **B. ClawCenter 多机** | 中央服务器 + Remote Worker | `#标签` 切换多机多项目；Web 管理面板 | 需额外部署 ClawCenter；架构更复杂 | 多台电脑、多项目并行 |
| **C. SSH 分层** | 家里电脑桥接 + SSH 到公司 | 公司机只开 SSH（你已有文档）；合规性较好 | Agent 在 SSH 会话内，非 GUI 桌面 | 公司限制第三方软件 |

### 3.2 决策矩阵（请对照公司 IT 政策勾选）

| 检查项 | 公司机直连 (A) | ClawCenter (B) | SSH 分层 (C) |
|--------|----------------|----------------|--------------|
| 允许安装 WeClaw/cli-in-wechat | 必须 | 中央机 + Worker 都要 | 仅家里机 |
| 允许 AI CLI（codex/claude） | 必须 | 必须 | 公司机需能跑 codex |
| 需 VPN 才能访问公司机 | 不需要（桥接在公司） | Worker 需可达中央 | 需要（SSH） |
| 7×24 开机不睡眠 | 公司机 | 公司机 + 中央机 | 公司机 |
| 安全软件可能拦截 Agent | 高风险 | 高风险 | 中等 |
| 需要看桌面画面 | 叠加 RDP/RustDesk | 叠加 RDP/RustDesk | 叠加 RDP/RustDesk |

### 3.3 推荐决策

**若公司允许在个人电脑装桥接 + AI CLI：**
→ 选 **模式 A**，在公司机安装 `weclaw.exe start`（或注册为 Windows 服务），手机微信直接对话。

**若公司只允许 SSH、不允许第三方远控软件：**
→ 选 **模式 C**，沿用你已有的 SSH 配置；在家里跑桥接，让 Agent 通过 `ssh company-pc` 操作公司项目。微信 ClawBot 负责对话，Codex SSH 负责远程执行。

**若有多台电脑（家里 + 公司 + 服务器）：**
→ 选 **模式 B** [ClawCenter](https://github.com/ruihanglix/clawcenter)，公司机以 Remote Worker 注册：

```bash
# 中央服务器
clawcenter start

# 公司电脑 Worker
clawcenter start --worker --center ws://中央服务器IP:9801
```

微信里用 `#claude` 切换 Agent，`#frontend` / `#backend` 切换不同工作目录。

**无论哪种模式，需要完整桌面操作时：**
→ 叠加 [公司电脑桌面远程控制方案.md](公司电脑桌面远程控制方案.md) 中的 RDP 或 RustDesk。

---

## 四、最终选型建议

基于本机环境验证与需求（本机 + 公司机、对话式控制）：

### 4.1 主选：weclaw

| 理由 |
|------|
| 本机已成功构建 `weclaw.exe`，单二进制易部署 |
| 自动检测 Claude + Codex（本机均已安装） |
| 支持 ACP 长驻进程，响应比每次 spawn 快 |
| `weclaw start` 可后台守护；`weclaw status/stop/restart` 管理方便 |
| 公司机部署同样简单：复制 exe + 扫码 + 注册开机启动 |

**公司机部署步骤概要：**
1. 复制 `weclaw.exe` 到公司机
2. 确认 `codex --version` 或 `claude --version` 可用
3. 运行 `weclaw.exe start`，微信扫码
4. 设置电源「接通电源从不睡眠」
5. 可选：任务计划程序开机自启 `weclaw start`

### 4.2 备选：cli-in-wechat

| 适用场景 |
|----------|
| 需要 40+ `/` 命令、引用消息路由、AskUserQuestion 审批 |
| 计划自建桥接或二次开发 |
| 已熟悉 Node.js 生态 |

本机已 `npm run build` 成功，可直接 `node dist/index.js` 使用。

### 4.3 暂不推荐（当前环境）

| 项目 | 原因 |
|------|------|
| WeClaude | 本机无 Python 3.11+；若偏好 Python 可后续安装 |
| CowAgent / OpenClaw | 功能全面但体积大；适合要 Skill 市场、多 IM 渠道时再上 |
| ClawCenter | 单台公司机阶段用 weclaw 直连即可；多机时再迁移 |

### 4.4 能力边界（务必知晓）

| 微信 ClawBot 能做 | 不能做 |
|-------------------|--------|
| 读写文件、跑终端命令、Git、装依赖 | 显示完整桌面画面 |
| 定时提醒（WeClaude）、Session 切换 | 群聊（iLink 暂不支持） |
| 远程审批工具调用（cc-wechat 等） | 替代公司 VPN/合规审查 |

---

## 五、快速命令参考

### weclaw

```powershell
D:\cursor\61\weclaw\weclaw.exe start      # 启动桥接
D:\cursor\61\weclaw\weclaw.exe status     # 查看状态
D:\cursor\61\weclaw\weclaw.exe stop       # 停止
D:\cursor\61\weclaw\weclaw.exe login      # 添加微信号
```

微信内：`/help` | `/cwd 路径` | `/new` | `/claude` | `/codex 任务描述`

### cli-in-wechat

```powershell
cd D:\cursor\61\cli-in-wechat
node dist/index.js           # 启动
node dist/index.js --debug   # 调试模式
```

微信内：`@claude 任务` | `@codex 任务` | `/help` | `/resume` | `/sessions`

---

## 六、安全提醒

- ClawBot 授予 AI **本机完整终端权限**，务必限制工作目录、审查敏感路径
- 公司部署前确认 IT 政策；勿将 SSH/RDP 端口暴露公网
- iLink 限流：长输出自动分片；避免 Bot 单方面连发
- 凭证存储：`~/.weclaw/` 或 `~/.wx-ai-bridge/`，注意文件权限

---

## 七、相关资源

| 资源 | 链接 |
|------|------|
| weclaw | https://github.com/fastclaw-ai/weclaw |
| cli-in-wechat | https://github.com/sgaofen/cli-in-wechat |
| WeClaude | https://github.com/allenhuang0/WeClaude |
| ClawCenter | https://github.com/ruihanglix/clawcenter |
| 腾讯官方微信插件 | https://github.com/Tencent/openclaw-weixin |
| iLink API 技术文档 | https://github.com/hao-ji-xing/openclaw-weixin |
