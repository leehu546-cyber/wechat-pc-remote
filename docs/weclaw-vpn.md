# WeClaw 与 VPN / 代理配置

微信桥接依赖 PC 上 `weclaw.exe` 长轮询 `ilinkai.weixin.qq.com`。若流量走 Clash 代理 / TUN，会导致微信显示「暂无法连接 OpenClaw」（日志 `172.19.x.x` + `GetUpdates error`）。

## 模式说明

| Clash 模式 | 仅靠 `rules: DIRECT` 够吗？ | 正确绕过方式 |
|-----------|---------------------------|-------------|
| 规则模式 | ✅ 够 | `prepend-rules` + `fake-ip-filter` |
| **全局模式** | ❌ 不够（规则被忽略） | **`tun.route-exclude-address`** + IP 列表 |
| TUN 开启 | 系统 bypass 无效 | 同上 + `fake-ip-filter` |

## 一键配置（Clash Nyanpasu，支持全局 + TUN）

```powershell
D:\cursor\61\scripts\setup-clash-ilink-direct.ps1
```

脚本会：

1. 解析 `ilinkai.weixin.qq.com` 真实 IP → `weclaw-ilink-ip.yaml`
2. 写入 `tun.route-exclude-address`（全局/TUN 下绕过代理的关键）
3. 写入 `prepend-rules`、`fake-ip-filter`、`nameserver-policy`（规则模式兜底）
4. 注册 Merge 配置链 `WeClaw iLink Bypass`
5. 设置 `system_proxy_bypass`

改完后在 Clash Nyanpasu **重新加载配置**，再 `restart-weclaw.ps1`。

订阅更新后请再跑一遍脚本（IP 可能变化）。

## 验证

1. 关闭 VPN 后 `scripts\status.ps1` 应显示微信已登录。
2. 查看 `~/.weclaw/weclaw.log` 不应连续出现 `[monitor] GetUpdates error`。
3. `WeClawWatchdog` 计划任务每 5 分钟检查；连续 3 次 GetUpdates 错误会自动 `restart-weclaw.ps1`。
