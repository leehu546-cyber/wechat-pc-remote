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
        'Execute a PowerShell command on the Windows PC and return stdout/stderr and exit code. Use this to list files, read/write files, run programs, check system state, etc.',
      parameters: {
        type: 'object',
        required: ['command'],
        properties: {
          command: {
            type: 'string',
            description: 'PowerShell command to run, e.g. Get-ChildItem D:\\',
          },
        },
      },
    },
  },
];

const DEFAULT_AGENT_PROMPT = `你是运行在用户 Windows 电脑上的助手，可通过 run_powershell 工具执行 PowerShell 命令完成任务。
规则：
- 需要查看或操作电脑时，调用 run_powershell，不要编造命令输出。
- 命令执行后根据真实输出回答；失败时分析原因并尝试修复。
- 最终回复用中文，简短清楚，适合手机微信阅读（不超过 500 字为宜）。
- 破坏性操作（删除、格式化等）仅在用户明确要求时执行。`;

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

/** Extract tool calls from assistant message or content fallback */
function extractToolCalls(message) {
  const calls = [];

  if (message.tool_calls?.length) {
    for (const tc of message.tool_calls) {
      const fn = tc.function || tc;
      const name = fn.name;
      if (name !== 'run_powershell') continue;
      calls.push({
        name,
        arguments: parseArguments(fn.arguments),
      });
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

async function runTool(name, args, config) {
  if (name !== 'run_powershell') {
    return { exitCode: -1, output: `未知工具: ${name}` };
  }
  const command = args.command || args.cmd || '';
  if (!command.trim()) {
    return { exitCode: -1, output: '命令为空' };
  }
  return execPowerShell(command, {
    workDir: config.workDir,
    timeoutSec: config.commandTimeoutSec,
    maxOutputChars: config.maxOutputChars,
    auditLog: config.auditLog !== false,
  });
}

function formatToolResult(result) {
  return `exitCode: ${result.exitCode}\n${result.output}`;
}

/**
 * @param {string} userId
 * @param {string} userText
 * @param {object} config
 * @param {{ getMessages: () => object[], pushMessages: (msgs: object[]) => void, onProgress?: (text: string) => Promise<void> }} ctx
 */
export async function runAgent(userId, userText, config, ctx) {
  const messages = ctx.getMessages();
  messages.push({ role: 'user', content: userText });

  const maxTurns = config.maxAgentTurns ?? 8;
  let lastReply = '';

  for (let turn = 0; turn < maxTurns; turn++) {
    const data = await ollamaChat(trimHistory(messages, config.maxHistory), config, true);
    const msg = data.message || {};
    const toolCalls = extractToolCalls(msg);

    if (toolCalls.length === 0) {
      lastReply = (msg.content || '').trim() || '任务已完成。';
      messages.push({ role: 'assistant', content: lastReply });
      return lastReply;
    }

    const assistantMsg = {
      role: 'assistant',
      content: msg.content || '',
      tool_calls: msg.tool_calls || toolCalls.map((tc, i) => ({
        type: 'function',
        function: {
          index: i,
          name: tc.name,
          arguments: tc.arguments,
        },
      })),
    };
    messages.push(assistantMsg);

    for (const tc of toolCalls) {
      const cmd = tc.arguments.command || '';
      if (config.notifyEachCommand !== false && ctx.onProgress) {
        const preview = cmd.length > 120 ? cmd.slice(0, 120) + '…' : cmd;
        await ctx.onProgress(`正在执行:\n${preview}`);
      }
      console.log(`[agent] exec: ${cmd.slice(0, 100)}`);
      const result = await runTool(tc.name, tc.arguments, config);
      const toolContent = formatToolResult(result);
      messages.push({
        role: 'tool',
        tool_name: 'run_powershell',
        content: toolContent,
      });
    }
  }

  lastReply = '已达到最大执行轮次，请简化任务或分步发送指令。';
  messages.push({ role: 'assistant', content: lastReply });
  return lastReply;
}

export function getAgentSystemPrompt(config) {
  return config.agentSystemPrompt || DEFAULT_AGENT_PROMPT;
}
