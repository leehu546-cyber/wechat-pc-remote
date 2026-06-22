# WeChat ClawBot Bridge

手机微信 → weclaw → opencode ACP → DeepSeek v4 Flash（`deepseek/deepseek-v4-flash`）

**架构说明：** [docs/架构说明.md](docs/架构说明.md)

## 启动

```powershell
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

- ~/.weclaw/config.json — weclaw 配置
- 解锁走 WeClaw 本地 `unlocker.script_path` 固定脚本；不依赖 OpenClaw HTTP
- ~/.config/opencode/opencode.json — opencode 模型配置
- DeepSeek API Key 保存在 opencode auth
- 常开 VPN 时见 [docs/weclaw-vpn.md](docs/weclaw-vpn.md)（iLink 需直连）

## 意图路由（大脑负责）

| 用户说 | 脚本 / 动作 |
|--------|-------------|
| 截图 | `scripts/screenshot.ps1` |
| 检索 / 看屏幕文字 | `scripts/screen-ocr.ps1` |
| 亮屏 / 关屏 | `wake-screen.ps1` / `turn-off-screen.ps1` |
| 解锁 | Agent 输出 `WECLAW_DELEGATE: openclaw-unlocker` |
| 股票 | `scripts/stock-info.ps1` → 原样转发 CARD |

详见 [docs/架构说明.md](docs/架构说明.md) §4。
