# WeChat ClawBot Bridge

手机微信 → weclaw → opencode ACP → 智谱AI GLM-4-Flash（免费）

## 启动

`powershell
scripts\start-weclaw.ps1
`

## 状态

`powershell
scripts\status.ps1
`

## 微信命令

- /new — 清空当前会话
- /help — 查看帮助

## 配置

- ~/.weclaw/config.json — weclaw 配置
- 解锁走 WeClaw 本地 `unlocker.script_path` 固定脚本；不依赖 OpenClaw HTTP `/v1/chat/completions`
- ~/.config/opencode/opencode.json — opencode 模型配置
- 智谱AI API Key 保存在 opencode auth
- 常开 VPN 时见 [docs/weclaw-vpn.md](docs/weclaw-vpn.md)（iLink 需直连）
