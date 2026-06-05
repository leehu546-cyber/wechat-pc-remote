# cli-in-wechat 架构笔记

阅读路径：`D:\cursor\61\cli-in-wechat\src\`

## 入口 `index.ts`

启动顺序：
1. `AdapterRegistry.detectAvailable()` — 检测 claude/codex/gemini/kimi/opencode
2. `loadCredentials()` 或 `login()` — QR 扫码
3. `new ILinkClient(credentials)` + `Router.start()` + `ilink.start()`

## ilink 层

### auth.ts
- `GET /ilink/bot/get_bot_qrcode?bot_type=3`
- 轮询 `GET /ilink/bot/get_qrcode_status?qrcode=...`
- 状态：`wait` → `scaned` → `confirmed`（拿到 bot_token）

### client.ts
- 长轮询 `POST /ilink/bot/getupdates`，body 含 `get_updates_buf`（cursor）
- 收到用户消息后缓存 `context_token`（按 from_user_id）
- 发送 `POST /ilink/bot/sendmessage`，必须带 context_token
- 限流：`ret=-2` 时指数冷却，中间消息可跳过
- 文本超 2000 字自动分片（优先在段落/行/空格处断开）

## bridge 层

### router.ts（1388 行，核心）
- `@claude` / `@codex` 前缀路由
- 引用消息：从 footer `— DisplayName |` 解析原工具
- `/` 命令：/help, /cwd, /resume, /sessions, /model 等
- `>>` 把上条 Agent 结果传给下个工具
- AskUserQuestion：Claude 交互式提问转发到微信，用户回复后 resolve

### session.ts
- 每用户 `sessions.json`：defaultTool, workDir, sessionIds[tool], model 等
- `setSession(userId, tool, sessionId)` 对接 CLI `--resume`

### formatter.ts
- Markdown → 微信纯文本（去代码块围栏、链接只留显示文字）

## adapters 层

### base.ts
- `UserSettings`：通用 + 各 CLI 专属 flag（effort, sandbox, thinking...）
- `execute(prompt, settings, { onActivity, onAskUser })` 统一接口

### claude.ts
- 优先 Anthropic Agent SDK；降级 `claude -p --resume`
- 支持 media 附件路径注入 prompt

### registry.ts
- `detectAvailable()` 用 `which`/`where` 检测各 CLI

## 本地数据目录（默认 ~/.wx-ai-bridge/）

| 文件 | 内容 |
|------|------|
| credentials.json | bot_token, baseUrl |
| poll-cursor.json | get_updates_buf |
| context-tokens.json | 每用户 context_token |
| sessions/sessions.json | 用户会话状态 |

## 自建桥接最小实现清单

1. QR 登录 + token 持久化
2. getupdates 长轮询 + cursor 持久化
3. context_token 缓存
4. sendmessage 分片 + 限流退避
5. 消息 → Agent spawn → 输出格式化 → 回发
6. session resume 持久化
