/**
 * Ollama agent loop with run_powershell tool
 */
import { execPowerShell } from './shell.js';

export const TOOL_DEFINITIONS = [
  {
    type: 'function',
    function: {
      name: 'run_powershell',
      description:
        'Execute a PowerShell command on the Windows PC. Always use this to operate the computer; never tell the user to click UI manually.',
      parameters: {
        type: 'object',
        required: ['command'],
        properties: {
          command: {
            type: 'string',
            description: 'PowerShell command to run',
          },
        },
      },
    },
  },
];

const DEFAULT_AGENT_PROMPT = `你是运行在用户 Windows 电脑上的执行助手，只能通过 run_powershell 操作电脑。
硬性规则：
- 用户要求操作本机（关闭/打开程序、列目录、创建文件等）必须调用 run_powershell，禁止教用户手动点鼠标或快捷键。
- 调用工具前不要在正文写说明，content 留空。
- 不要编造命令输出；根据工具返回的真实结果判断成败。
- 给用户看的最终一句话由程序生成，你只需正确调用工具。`;

const ACTION_RE =
  /关闭|打开|启动|结束|退出|删除|列出|查看|运行|执行|创建|关机|休眠|重启|安装|卸载|chrome|浏览器|进程|目录|文件|cmd|powershell/i;

const NUDGE =
  '请直接调用 run_powershell 完成用户请求，不要输出操作说明或教程文字。';

/**
 * @param {object[]} messages
 * @param {object} config
 */
async function ollamaChat(messages, config, withTools) {
  const payload = {
    model: config.model,
    messages,
    stream: false,
  };
  if (withTools) payload.tools = TOOL_DEFINITIONS;

  const res = await fetch(`${config.ollamaUrl}/api/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Ollama 请求失败: HTTP ${res.status} ${body}`);
  }

  return res.json();
}

function trimHistory(messages, maxHistory) {
  const system = messages.filter((m) => m.role === 'system');
  const rest = messages.filter((m) => m.role !== 'system');
  const kept = rest.slice(-maxHistory * 4);
  return [...system, ...kept];
}

function parseArguments(raw) {
  if (raw == null) return {};
  if (typeof raw === 'object') return raw;
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw);
    } catch {
      return { command: raw };
    }
  }
  return {};
}

function extractToolCalls(message) {
  const calls = [];

  if (message.tool_calls?.length) {
    for (const tc of message.tool_calls) {
      const fn = tc.function || tc;
      if (fn.name !== 'run_powershell') continue;
      calls.push({ name: fn.name, arguments: parseArguments(fn.arguments) });
    }
    if (calls.length) return calls;
  }

  const content = message.content || '';
  const xmlRe = /<tool_call>\s*([\s\S]*?)\s*<\/tool_call>/gi;
  let m;
  while ((m = xmlRe.exec(content)) !== null) {
    try {
      const obj = JSON.parse(m[1].trim());
      if (obj.name === 'run_powershell' || obj.name === 'run_terminal') {
        calls.push({
          name: 'run_powershell',
          arguments: parseArguments(obj.arguments),
        });
      }
    } catch { /* skip */ }
  }

  if (!calls.length) {
    const jsonRe = /\{"name"\s*:\s*"run_powershell"[^}]+\}/gi;
    while ((m = jsonRe.exec(content)) !== null) {
      try {
        const obj = JSON.parse(m[0]);
        calls.push({ name: 'run_powershell', arguments: parseArguments(obj.arguments) });
      } catch { /* skip */ }
    }
  }

  return calls;
}

function looksLikeActionRequest(text) {
  return ACTION_RE.test(text);
}

function firstLine(text, max = 80) {
  const line = (text || '').split(/\r?\n/).map((s) => s.trim()).find(Boolean) || '';
  if (line.length <= max) return line;
  return line.slice(0, max) + '…';
}

/**
 * One-line WeChat reply from tool execution results
 * @param {string} userText
 * @param {{ command: string, exitCode: number, output: string }[]} toolRuns
 */
export function formatUserReply(userText, toolRuns, config) {
  if (!toolRuns.length) {
    return '已完成。';
  }

  const last = toolRuns[toolRuns.length - 1];
  const cmdLower = last.command.toLowerCase();
  const out = (last.output || '').trim();

  if (last.exitCode !== 0) {
    const err = firstLine(out, 100) || `退出码 ${last.exitCode}`;
    return `失败：${err}`;
  }

  if (/stop-process/i.test(last.command) && /chrome/i.test(cmdLower + out)) {
    return '已完成：已关闭 Chrome';
  }
  if (/stop-process/i.test(last.command)) {
    const proc = last.command.match(/Stop-Process\s+(?:-Name\s+)?['"]?(\w+)/i);
    return proc ? `已完成：已结束 ${proc[1]}` : '已完成：已结束进程';
  }

  if (/get-process/i.test(last.command) && /chrome/i.test(cmdLower)) {
    const running = !/cannot find|找不到/i.test(out);
    return running ? 'Chrome 正在运行' : 'Chrome 未在运行';
  }

  if (/get-childitem|dir\s|ls\s/i.test(last.command)) {
    const lines = out.split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
    if (!lines.length || lines[0] === '(无输出)') return '已完成：目录为空';
    const preview = lines.slice(0, 5).join('、');
    const suffix = lines.length > 5 ? ` 等共 ${lines.length} 项` : '';
    return `已完成：${preview}${suffix}`;
  }

  if (/set-content|new-item|out-file/i.test(last.command)) {
    return '已完成：文件已写入';
  }

  if (toolRuns.length > 1) {
    return `已完成（共 ${toolRuns.length} 步）`;
  }

  if (out && out !== '(无输出)') {
    return `已完成：${firstLine(out, 80)}`;
  }

  return '已完成。';
}

async function runTool(name, args, config) {
  if (name !== 'run_powershell') {
    return { command: '', exitCode: -1, output: `未知工具: ${name}` };
  }
  const command = args.command || args.cmd || '';
  if (!command.trim()) {
    return { command: '', exitCode: -1, output: '命令为空' };
  }
  const result = await execPowerShell(command, {
    workDir: config.workDir,
    timeoutSec: config.commandTimeoutSec,
    maxOutputChars: config.maxOutputChars,
    auditLog: config.auditLog !== false,
  });
  return { command, ...result };
}

function formatToolResult(result) {
  return `exitCode: ${result.exitCode}\n${result.output}`;
}

/**
 * @param {string} userId
 * @param {string} userText
 * @param {object} config
 * @param {{ getMessages: () => object[], onProgress?: (text: string) => Promise<void> }} ctx
 */
export async function runAgent(userId, userText, config, ctx) {
  const messages = ctx.getMessages();
  messages.push({ role: 'user', content: userText });

  const maxTurns = config.maxAgentTurns ?? 8;
  const resultOnly = config.resultOnly !== false;
  /** @type {{ command: string, exitCode: number, output: string }[]} */
  const toolRuns = [];
  let nudgeUsed = false;

  for (let turn = 0; turn < maxTurns; turn++) {
    const data = await ollamaChat(trimHistory(messages, config.maxHistory), config, true);
    const msg = data.message || {};
    const toolCalls = extractToolCalls(msg);

    if (toolCalls.length === 0) {
      if (
        !nudgeUsed &&
        looksLikeActionRequest(userText) &&
        toolRuns.length === 0
      ) {
        nudgeUsed = true;
        messages.push({ role: 'assistant', content: msg.content || '' });
        messages.push({ role: 'user', content: NUDGE });
        continue;
      }

      const modelReply = (msg.content || '').trim();
      if (resultOnly && toolRuns.length > 0) {
        const reply = formatUserReply(userText, toolRuns, config);
        messages.push({ role: 'assistant', content: reply });
        return reply;
      }

      const lastReply = modelReply || (toolRuns.length ? formatUserReply(userText, toolRuns, config) : '已完成。');
      messages.push({ role: 'assistant', content: lastReply });
      return lastReply;
    }

    messages.push({
      role: 'assistant',
      content: msg.content || '',
      tool_calls: msg.tool_calls || toolCalls.map((tc, i) => ({
        type: 'function',
        function: { index: i, name: tc.name, arguments: tc.arguments },
      })),
    });

    for (const tc of toolCalls) {
      const cmd = tc.arguments.command || '';
      if (config.notifyEachCommand && ctx.onProgress) {
        await ctx.onProgress(`正在执行:\n${cmd.slice(0, 120)}`);
      }
      console.log(`[agent] exec: ${cmd.slice(0, 100)}`);
      const result = await runTool(tc.name, tc.arguments, config);
      toolRuns.push(result);
      messages.push({
        role: 'tool',
        tool_name: 'run_powershell',
        content: formatToolResult(result),
      });
    }

    if (resultOnly && toolRuns.length > 0) {
      const reply = formatUserReply(userText, toolRuns, config);
      messages.push({ role: 'assistant', content: reply });
      return reply;
    }
  }

  if (resultOnly && toolRuns.length > 0) {
    const reply = formatUserReply(userText, toolRuns, config);
    messages.push({ role: 'assistant', content: reply });
    return reply;
  }

  const lastReply = '已达到最大执行轮次，请简化任务或分步发送指令。';
  messages.push({ role: 'assistant', content: lastReply });
  return lastReply;
}

export function getAgentSystemPrompt(config) {
  return config.agentSystemPrompt || DEFAULT_AGENT_PROMPT;
}

export function truncateReply(text, maxChars = 120) {
  const t = (text || '').trim();
  if (t.length <= maxChars) return t;
  return t.slice(0, maxChars) + '…';
}
