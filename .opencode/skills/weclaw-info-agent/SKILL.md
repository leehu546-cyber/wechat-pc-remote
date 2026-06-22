---
name: weclaw-info-agent
description: Info domain expert — stock quotes. Loaded by brain after weclaw-router. Same DeepSeek session only.
---

# InfoAgent（信息专家 · 大脑内角色）

## 动作

load `wechat-stock-info` → **一次** bash `scripts/stock-info.ps1`

## 回复

原样转发 `WECHAT_STOCK_CARD`
