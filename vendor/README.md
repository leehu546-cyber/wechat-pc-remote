# Vendor — 外部 WeChat / Agent Skills（参考）

本目录为从 GitHub 浅克隆的参考实现，**不直接接入 WeClaw 主路径**。
借鉴 UI 自动化模式；新能力应沉淀为 `scripts/*.ps1` 并注册到 `data/registry.sqlite`。

| 目录 | 来源 | 用途 |
|------|------|------|
| `wechat-auto-sender-skills` | [wangdxnum1/wechat-auto-sender-skills](https://github.com/wangdxnum1/wechat-auto-sender-skills) | OpenClaw Skill：Windows 发微信消息 |
| `wechat-automation-api` | [LAVARONG/wechat-automation-api](https://github.com/LAVARONG/wechat-automation-api) | Flask/UIA 发信 API + Skill CLI |

更新：`git -C vendor/<name> pull` 或重新 clone。
