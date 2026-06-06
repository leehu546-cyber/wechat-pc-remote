# WeClaw 与 VPN / 代理配置

微信桥接依赖 PC 上 `weclaw.exe` 长轮询 `ilinkai.weixin.qq.com`。若流量走 Clash TUN / VPN，重连时会导致微信显示「暂无法连接 OpenClaw」。

## Clash / Clash Verge 建议

在规则中为 iLink **直连（DIRECT）**：

```yaml
rules:
  - DOMAIN,ilinkai.weixin.qq.com,DIRECT
  - IP-CIDR,43.163.179.90/32,DIRECT
```

或在「绕过域名 / Bypass」中加入：

```
ilinkai.weixin.qq.com
```

TUN 模式下务必让上述域名不走代理，否则日志中可能出现 `172.19.x.x` 源地址与 `GetUpdates error`。

## 验证

1. 关闭 VPN 后 `scripts\status.ps1` 应显示微信已登录。
2. 查看 `~/.weclaw/weclaw.log` 不应连续出现 `[monitor] GetUpdates error`。
3. `WeClawWatchdog` 计划任务每 5 分钟检查；连续 3 次 GetUpdates 错误会自动 `restart-weclaw.ps1`。
