---
name: wechat-task-orchestrator
description: Use for compound WeChat PC-control tasks, especially requests that combine actions or ask to open/show/confirm/send a screenshot. This is a brain-only collaboration protocol, not a standalone tool.
---

# WeChat Task Orchestrator

## Purpose

Use this skill when the user asks for a multi-step computer task, asks to see the result, asks for screenshot/OCR confirmation, or combines creation/opening/browser/screen/file actions.

The main brain is the only decision maker. Domain agents are worker roles: they execute a chosen step and return evidence. They must not change the user's goal or invent a new plan.

## Worker Roles

| Role | Owns | Must not do |
|------|------|-------------|
| FileAgent | create, find, open, copy, move files | decide unrelated app/browser actions |
| DesktopAgent | visible app/window state, foregrounding, simple app launch | write documents or analyze screen text |
| DocumentAgent | Word/WPS/Markdown/PDF creation and editing | verify GUI visibility by itself |
| BrowserAgent | browser open/search/play/navigation | use screenshots as analysis unless asked |
| ScreenAgent | wake, screen off, screenshot, OCR, unlock delegate | improvise display commands |
| VerifierAgent | screenshot/OCR/file/process/window verification | redo the main action unless brain decides |
| ReporterAgent | final concise Chinese reply | expose internal chain details |

## Protocol

For compound tasks, run:

1. Plan: classify task and choose the smallest worker sequence.
2. Act: execute each step with the fixed skill/script/tool for that worker.
3. Verify: if the user says 打开给我看 / 发截图 / 确认 / 看看成功没有 / 让我看到, verify with screenshot, OCR, file existence, or process/window checks.
4. Report: one concise Chinese sentence with the outcome or first clear failure.

Visible progress for compound tasks:

```text
WECHAT_PROGRESS: 正在制定执行步骤
WECHAT_PROGRESS: 正在执行第N步
WECHAT_PROGRESS: 正在验证结果
```

Keep progress lines separate from final replies.

## Result Prefixes

Interpret worker/script output as:

| Prefix | Brain action |
|--------|--------------|
| `WECHAT_OK:` | Continue to the next step or report success. |
| `WECHAT_FAIL:` | Stop repeated attempts; report the failure reason. |
| `WECHAT_NEED_CONFIRM:` | Ask the user for confirmation. |
| `WECHAT_ARTIFACT:` | Store the absolute path for later open/verify steps. |

## Common Flows

- Create file -> open file -> screenshot verify.
- Open browser/page -> wait briefly if needed -> screenshot/OCR verify when requested.
- Play music/video -> open page/player -> verify visible window or screenshot when requested.
- Screen action -> fixed screen skill/script -> concise reply.
- Unlock -> output only `WECLAW_DELEGATE: openclaw-unlocker`; after delegate result, screenshot only if the user requested proof.

## Hard Rules

- Do not route by bridge-side keywords; the brain chooses.
- Do not split a complete compound request into multiple WeChat turns.
- Do not list/read many files for known PC actions; use fixed scripts and recent task context.
- Do not retry the same failed action more than once. If no progress, report the failure or ask for one missing detail.
- Word/WPS is only one example. Apply this protocol to all local PC-control domains.
