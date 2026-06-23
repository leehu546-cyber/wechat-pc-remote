# WeClaw Bug 修复操作日志

> 项目：`D:\cursor\61` (微信 Claw Bot)
> 操作日期：2026-06-23
> 修改文件：`weclaw/agent/acp_agent.go`

---

## 修复概览

| 编号 | Bug | 严重度 | 状态 |
|------|-----|--------|------|
| FIX-1 | Fallback 跨轮取数据 — empty assistant text 后提取到上一轮的 system reply | 🔴 高 | ✅ 已修复 |
| FIX-2 | Session 无限复用 — 上下文膨胀、tool output 累积污染 | 🔴 高 | ✅ 已修复 |
| FIX-3 | 上下文 Token 超长无截断 — totalTokens 膨胀至 58K+ 时模型省略文字回复 | 🟡 中 | ✅ 已修复 |

---

## FIX-1：Fallback 跨轮取数据

### 问题

`acp_agent.go` 的 `extractWeChatToolFallback` 在 assistant text 为空时，从工具输出中扫描 `WECHAT_USER_REPLY:` 作为回复。当同一 session 被多次复用，旧轮次的系统操作输出（如 unlock 脚本的"屏幕已点亮。"）残留在工具输出中，导致：
- 用户问"搜索新闻写Word" → 回复"屏幕已点亮。"
- 用户问"截图" → 回复"屏幕已点亮。"

### 修改

1. **限制扫描范围**：`extractWeChatToolFallback` 只扫描最后 3 个工具输出片段（`maxLookback=3`），不再扫描全量累积输出

2. **新增 `isStaleSystemReply` 过滤**：当存在多个工具输出片段时，跳过来自旧轮次系统操作的回复（"屏幕已点亮"、"已解锁"、"截图已发"等）。单片段场景不受此过滤影响，保证当前轮次的系统操作回复仍能正常使用

3. **变更位置**：`acp_agent.go` 第 1429-1510 行

### 代码 diff 摘要

```diff
+ const maxLookback = 3  // 只查看最近3个tool output

  func extractWeChatToolFallback(toolSnippets []string) string {
-     for i := len(toolSnippets) - 1; i >= 0; i-- {
+     start := len(toolSnippets) - maxLookback
+     for i := len(toolSnippets) - 1; i >= start; i-- {
          ...
+         if len(toolSnippets) > 1 && isStaleSystemReply(reply) {
+             continue  // 多片段场景跳过旧轮次系统操作回复
+         }
      }

+ func isStaleSystemReply(body string) bool { ... }
```

---

## FIX-2：Session 复用不清理

### 问题

同一个 conversation 的 session 被无限复用，导致：
- 每次复用追加 prompt，上下文持续膨胀（58K → 62K → 68K tokens）
- 旧轮次 tool output 在 session 中累积，污染后续 fallback
- DeepSeek 在超长上下文中倾向省略文字回复

### 修改

1. **新增 `sessionReuseCount` 字段**：跟踪每个 conversation 的 session 复用次数

2. **强制新建 session**：复用超过 3 次（`maxSessionReuses=3`）后自动删除旧 session 并创建新 session，日志记录 `forcing new session after N reuses`

3. **清理计数器**：`dropSessionForConversation` 同步清理 `sessionReuseCount`

4. **变更位置**：
   - 结构体定义（第 42-44 行）
   - `NewACPAgent` 初始化（第 232 行）
   - `getOrCreateSession`（第 680-720 行）
   - `dropSessionForConversation`（第 569-571 行）

### 代码 diff 摘要

```diff
  type ACPAgent struct {
      ...
+     sessionReuseCount map[string]int  // 跟踪session复用次数
  }

+ const maxSessionReuses = 3

  func (a *ACPAgent) getOrCreateSession(...) {
      if exists {
+         if count >= maxSessionReuses {
+             log.Printf("[acp] forcing new session after %d reuses", count)
+             a.dropSessionForConversation(conversationID)
+             exists = false
+         } else {
+             a.sessionReuseCount[conversationID] = count + 1
+             return sid, false, nil
+         }
      }
+     a.sessionReuseCount[conversationID] = 0  // 新建时重置
  }
```

---

## FIX-3：上下文 Token 超长截断

### 问题

向 DeepSeek 发送请求前无 token 预算检查，prompt 组合（system instructions + chat-log context）可能远超模型舒适区间，导致：
- `totalTokens=68,446` 时 `outputTokens=18`（模型几乎不产文字）
- 大段上下文中的无关信息干扰 Agent 意图识别

### 修改

1. **新增 `promptBudgetChars` 常量**：32,000 字符预算（≈32K tokens for Chinese）

2. **`promptEntries` 增加截断逻辑**：
   - 预算充足时直接返回（fast path）
   - 超出预算时优先保留 system instructions，从 user request（含 chat-log context）中截断
   - 截断时保留尾部（最新上下文），丢弃头部（早期上下文）
   - system prompt 超大时也做兜底截断

3. **日志记录**：截断发生时记录原始大小、截断后大小

4. **变更位置**：`acp_agent.go` 第 521-567 行

### 代码 diff 摘要

```diff
+ const promptBudgetChars = 32000

  func (a *ACPAgent) promptEntries(message string) []promptEntry {
      ...
+     totalChars := len([]rune(fullText))
+     if totalChars <= promptBudgetChars {
+         return ...  // fast path
+     }
+     log.Printf("[acp] prompt too large (%d > %d), truncating context", totalChars, promptBudgetChars)
+     // 保留system instructions，从message尾部截断
+     message = "…[earlier context truncated]\n" + tail
  }
```

---

## 测试结果

```
go test ./agent/... -count=1
ok  github.com/fastclaw-ai/weclaw/agent  0.881s  (18/18 PASS)
```

- 无回归：所有 18 个 agent 包测试通过
- 新增逻辑在单片段/多片段/空回复等场景均正确

---

## 待后续处理

1. **git 提交**：由主 Agent 执行 `git add` + `git commit`
2. **WeClaw 重启**：修改生效需重启 WeClaw 进程
3. **建议配合 config.json 调整**：确保 `routing.cancel_previous = true`（当前为 false，与日志中实际 cancel 行为不一致）
