---
name: wechat-task-orchestrator
description: Use for compound WeChat PC-control tasks, especially requests that combine actions or ask to open/show/confirm/send a screenshot. This is a brain-only collaboration protocol, not a standalone tool.
---

# WeChat Task Orchestrator

## Purpose

Use this skill when the user asks for a multi-step computer task, asks to see the result, asks for screenshot/OCR confirmation, or combines creation/opening/browser/screen/file actions.

The main brain is the only decision maker. Domain agents are worker roles: they execute a chosen step and return evidence.

## Protocol

For compound tasks, run:

1. Plan: classify task and choose the smallest worker sequence.
2. Act: execute each step with the fixed skill/script/tool for that worker.
3. Verify: if the user asks to see/confirm, verify with screenshot, OCR, file existence, or process/window checks.
4. Report: **固定句式收尾**（见 AGENTS.md 微信回复模板）：
   - 成功：`已完成：{做了什么}`
   - 失败：`没做成：{一句原因}`

Visible progress for compound tasks:

```text
WECHAT_PROGRESS: 正在制定执行步骤
WECHAT_PROGRESS: 正在执行第N步
WECHAT_PROGRESS: 正在验证结果
```

## Result Prefixes

| Prefix | Brain action |
|--------|--------------|
| `WECHAT_OK:` | Continue to the next step or report success. |
| `WECHAT_FAIL:` | Stop; reply `没做成：{原因}` |
| `WECHAT_USER_REPLY:` | **原样转发**作为最终回复 |
| `WECHAT_NEED_CONFIRM:` | Reply `需要你确认：{缺什么}` |
| `WECHAT_ARTIFACT:` | Store the absolute path for later open/verify steps. |

## Hard Rules

- Do not split a complete compound request into multiple WeChat turns.
- Do not list/read many files for known PC actions; use fixed scripts.
- Do not retry the same failed action more than once.
- Final reply ≤120 chars unless forwarding stock CARD.
