# WeChat ClawBot Bridge

手机微信 → weclaw → **OpenCode ACP** → **DeepSeek 付费 API**（`deepseek/deepseek-v4-flash`）

**架构说明：** [docs/架构说明.md](docs/架构说明.md)

## 启动

```powershell
scripts\setup-opencode-deepseek.ps1   # 确认 OpenCode 已登录 DeepSeek Key
scripts\init-weclaw-opencode.ps1      # 写入 ~/.weclaw/config.json
scripts\start-weclaw.ps1
```

## 状态

```powershell
scripts\status.ps1
```

## 微信命令

- /new — 清空当前 OpenCode 会话
- /help — 查看帮助

## 配置

- `~/.weclaw/config.json` — default_agent=**opencode**，model=**deepseek/deepseek-v4-flash**
- `~/.local/share/opencode/auth.json` — DeepSeek API Key（OpenCode 登录后生成）
- 解锁走 WeClaw 本地 `unlocker.script_path` 固定脚本
- **不要用** `opencode/deepseek-v4-flash-free`（OpenCode 免费云额度已尽）

## 意图路由

由 OpenCode 大脑读 `.opencode/AGENTS.md` + skills，调用 `scripts/*.ps1` 固定脚本。

详见 [docs/架构说明.md](docs/架构说明.md) §4。
