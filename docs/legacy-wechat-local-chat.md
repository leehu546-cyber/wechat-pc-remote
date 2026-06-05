# 遗留方案：wechat-local-chat

`wechat-local-chat/` 是早期自研桥接方案，路径为：

```text
微信 ClawBot -> wechat-local-chat -> Ollama 大脑 -> PowerShell / OpenCode serve
```

当前主方案已经切换为：

```text
微信 ClawBot -> weclaw.exe -> opencode acp
```

因此 `wechat-local-chat/` 只保留作历史参考或紧急回退，不再作为默认维护方向。

## 与当前主方案的区别

- 旧方案依赖本地 Ollama 模型做任务分类和调度。
- 旧方案使用 `opencode serve` 与 `opencode run --attach`。
- 当前主方案使用 WeClaw 的 ACP Agent 配置，直接运行 `opencode acp`。
- 当前主方案的启动、状态和恢复入口都在 `scripts/` 下的 WeClaw 脚本中。

## 回退到旧方案

仅在明确需要回退时使用：

```powershell
D:\cursor\61\weclaw\weclaw.exe stop
D:\cursor\61\scripts\start-wechat-local-chat-background.ps1
```

如果旧方案无法启动，优先回到当前主方案：

```powershell
D:\cursor\61\scripts\start-weclaw.ps1
```

## 注意事项

- 旧方案可能仍包含长驻进程、OpenCode serve、Ollama 配置等历史逻辑。
- 旧方案配置位于 `wechat-local-chat/config.json`，其中部分路径可能写死为 `D:\cursor\61`。
- 新功能和日常修复应优先落在 WeClaw + OpenCode ACP 主方案。
