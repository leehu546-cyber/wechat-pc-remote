---
name: wechat-stock-info
description: MANDATORY for 股票/持仓/股票信息/查股票/510300/我的股票. One bash then verbatim WECHAT_STOCK_CARD only.
---

# 微信查持仓股票 (wechat-stock-info)

## 何时加载

用户意图含：**股票信息、查股票、持仓、我的股票、510300、盈亏、该买还是卖** 等。

## 执行（仅 1 次 bash）

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/stock-info.ps1
```

禁止：即兴 curl、第二遍抓行情、改脚本。

脚本会**同时**请求 3 个行情源（东方财富 / 新浪 / 腾讯），至少 1 个成功才返回；2 个以上且价格一致时标注「N 源一致」。

## bash 之后：只转发卡片（4–5 行，无空行）

1. 在 stdout 中找到 `WECHAT_STOCK_CARD:` **下一行起至结尾**的纯文本。
2. **你的整条回复 = 该卡片原文**（每行一条信息，**不要**空行，禁止改数字）。
3. **禁止把多行挤成一行** — 微信靠换行排版。
4. 禁止加 Markdown、禁止加分析。
5. 若 bash 失败，回复：`没做成：{失败原因}`。

## 卡片示例（数值随行情变化）

```
510300 沪深300ETF
现价 4.818 (+1.41%)  盈亏 -10.2元 (-2.07%)
建议 持有  风控 止损/止盈均未触发
来源 3 源一致 (eastmoney+sina+tencent)
抓取 2026-06-14 20:45:20
```

每行一条信息，**不要**空行，**不要**把一句话拆成多行。

## 禁止

- 编造价格或时间
- 省略 CARD 或合并成一行
- 凭记忆重打中文（必须从 tool stdout 原样复制）
- 建议用户 /new 或开新对话

乱码排查 → 加载 `wechat-encoding-safety` skill。
