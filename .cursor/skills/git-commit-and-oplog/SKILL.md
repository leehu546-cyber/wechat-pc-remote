---
name: git-commit-and-oplog
description: >-
  Enforces git commit and docs/操作日志.md step logging after every code change
  in a git repository. Use when modifying code, scripts, or config in any
  project with a .git folder; when the user mentions 提交, 日志, commit, or
  operation log; or at the end of any implementation task before marking done.
---

# Git 提交 + 操作日志（有仓库项目必做）

## 硬性要求

在**任意含 `.git` 的项目**中，只要**修改了代码、脚本或配置**（含本仓库与子模块/子仓库如 `weclaw/`），在结束当前任务前**必须**完成：

1. **追加操作日志** — `docs/操作日志.md`（或项目约定的 `docs/*日志*.md`）
2. **Git 提交** — 仅提交与本任务相关的文件，不提交密钥与本地运行时数据

**禁止**：改完代码只口头总结、不提交、不写日志（除非用户明确说「先不要提交」）。

## 何时触发

- 完成一个功能、修复、重构或配置变更后
- 用户说「继续」「做完」「好了」且本轮有文件改动
- 多轮对话中每一**独立逻辑批次**的改动（例如先修 handler 再修 watchdog → 可两次提交，或一次提交但日志写清两步）

## 工作流（按顺序）

### 1. 确认仓库与改动

```powershell
git status
git diff --stat
```

若存在**嵌套 git 仓库**（如 `weclaw/`），分别在各自目录执行 `git status`，**分别提交**。

### 2. 追加操作日志

优先用项目脚本（本仓库）：

```powershell
D:\cursor\61\scripts\log-step.ps1 `
  -Title "简短标题" `
  -Category "修复" `   # 开发|修复|优化|配置|整理|验证
  -Body "关键命令或改动的文件列表" `
  -Result "验证结果或用户可见效果"
```

无脚本时，在 `docs/操作日志.md` 的「待办」章节**之前**按既有格式追加 `### NN | 类别 | 标题`。

日志必须写清：**改了什么、为什么、怎么验证**。

### 3. 暂存与提交

```powershell
git add <相关文件> docs/操作日志.md
git commit -m "$(cat <<'EOF'
一句话说明目的（中文，祈使句）。

EOF
)"
git status
```

- 不提交：`.env`、API key、`node_modules/`、`weclaw.exe`、仅本地运行时目录
- 不 `git push`，除非用户明确要求
- 不 `git config` 修改

### 4. 嵌套仓库（示例：weclaw）

```powershell
cd weclaw
go build -o weclaw.exe .
git add messaging/handler.go messaging/handler_test.go
git commit -m "..."
cd ..
```

主仓库日志中注明 weclaw 子仓库 commit hash（若已提交）。

## 提交信息风格

- 中文或英文与仓库既有风格一致
- 一行主题 + 可选正文；写**目的**不写文件清单堆砌
- 示例：`修复外出断联：截图/亮屏走本地快路径，加强 watchdog`

## 任务完成自检

在标记任务完成前核对：

- [ ] `docs/操作日志.md` 已新增本节记录
- [ ] 主仓库 `git status` 干净（或仅剩用户未要求的未跟踪文件）
- [ ] 嵌套 git 仓库已单独提交（如有改动）
- [ ] 未提交 secrets 与构建产物

## 例外

仅当用户**明确**说「不要提交」「先别 commit」「只改代码不写日志」时可跳过；否则默认执行本 skill。
