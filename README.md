# WeChat ClawBot Bridge

手机微信 → weclaw → **DeepSeek HTTP（Router）** + **Codex ACP（Specialist）**

**架构说明：** [docs/架构说明.md](docs/架构说明.md)

## 启动

```powershell
scripts\setup-deepseek-key.ps1   # 首次：保存 DeepSeek API Key
scripts\init-weclaw-opencode.ps1 # 写入 ~/.weclaw/config.json
scripts\start-weclaw.ps1
```

## 状态

```powershell
scripts\status.ps1
```

## 微信命令

- /new — 清空当前 Specialist（Codex）会话
- /help — 查看帮助

## 配置

- `~/.weclaw/config.json` — weclaw 配置（router=deepseek-router, specialist=codex）
- `~/.weclaw/deepseek.json` 或环境变量 `DEEPSEEK_API_KEY` — Router/OCR 总结用
- 解锁走 WeClaw 本地 `unlocker.script_path` 固定脚本
- 常开 VPN 时见 [docs/weclaw-vpn.md](docs/weclaw-vpn.md)（iLink 需直连）

## 意图路由（Plan A）

| 用户说 | 谁处理 |
|--------|--------|
| 截图 / 亮屏 / 关屏 / 股票 | DeepSeek Router 分类 → WeClaw 直跑脚本 |
| 检索屏幕 | OCR 脚本 + DeepSeek 总结 |
| 解锁 | Router → delegate → 本地解锁脚本 |
| 复合 / 文件 / 浏览器 | Codex Specialist |

详见 [docs/架构说明.md](docs/架构说明.md) §4。
