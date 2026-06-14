---
name: wechat-stock-info
description: MANDATORY for 股票/持仓/股票信息/查股票/510300/我的股票. One bash then verbatim mini WECHAT_STOCK_CARD only.
---

# 微信查持仓股票 (wechat-stock-info)

## 何时加载

用户意图含：**股票信息、查股票、持仓、我的股票、510300、盈亏、该买还是卖** 等。

## 执行（仅 1 次 bash）

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/stock-info.ps1
```

禁止：即兴 curl、第二遍抓行情、改脚本。

## bash 之后：只转发极简卡片

1. 在 stdout 中找到 `WECHAT_STOCK_CARD:` **下一行起至结尾**的纯文本（约 4 行）。
2. **你的整条回复 = 该卡片原文**（保留换行，禁止改数字、禁止改抓取时间）。
3. 若脚本输出 `WECHAT_USER_REPLY:`，忽略；以 CARD 为准。
4. 禁止加 Markdown、禁止加分析、禁止把卡片挤成一行。
5. 若 bash 失败（含 `WECHAT_FAIL`），回复：`没做成：{失败原因}`。

## 卡片示例（数值随行情变化）

```
510300 沪深300ETF
现价 4.818 (+1.41%)  盈亏 -10.2元 (-2.07%)
建议 持有  风控 止损/止盈均未触发
抓取 2026-06-14 20:45:20
```

## 禁止

- 编造价格或时间
- 省略 CARD 改用自写表格或五层分析
- 建议用户 /new 或开新对话
