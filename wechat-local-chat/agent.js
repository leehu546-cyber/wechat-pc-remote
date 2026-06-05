/**
 * Ollama brain — run_powershell + run_opencode with classifier guard
 */
import { execPowerShell } from './shell.js';
import { appendFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { runOpenCode, formatOpenCodeReply } from './opencode-client.js';
import { classifyTask, suggestPowerShellCommand } from './task-classifier.js';

const BRAIN_PROMPT = `你是用户 Windows 电脑上的调度大脑，有两个下属工具：

1. run_powershell — 快速单步：关闭/打开程序、列目录、查进程、单条命令
2. run_opencode — 复杂助手：浏览器搜索、多步任务、代码分析、Git、多文件

决策规则：
- 一条 PowerShell 能完成的 → 必须 run_powershell，禁止 run_opencode
- 需浏览器 UI、搜索、多步规划、代码仓库 → run_opencode
- 调用工具前 content 留空，不要写教程
- 最终一句话由程序生成`;

function buildToolDefinitions(config) {
  const tools = [
    {
      type: 'function',
      function: {
        name: 'run_powershell',
        description:
          'Execute one PowerShell command for simple local ops: close/open apps, list dirs, check processes.',
        parameters: {
          type: 'object',
          required: ['command'],
          properties: {
            command: { type: 'string', description: 'PowerShell command' },
          },
        },
      },
    },
  ];
  if (config.agentForce !== 'fast') {
    tools.push({
      type: 'function',
      function: {
        name: 'run_opencode',
        description:
          'Delegate complex multi-step tasks to OpenCode assistant: browser search, code, git, planning.',
        parameters: {
          type: 'object',
          required: ['task'],
          properties: {
            task: { type: 'string', description: 'Clear task for OpenCode' },
          },
        },
      },
    });
  }
  return tools;
}

const ACTION_RE =
  /关闭|打开|启动|结束|退出|删除|列出|查看|运行|执行|创建|关机|休眠|重启|安装|卸载|chrome|浏览器|进程|目录|文件/i;

const NUDGE_PS =
  '请直接调用 run_powershell 完成用户请求，不要输出操作说明。';
const NUDGE_OC =
  '此任务较复杂，请改用 run_opencode 交给助手完成。';

async function ollamaChat(messages, config, withTools) {
  const payload = {
    model: config.model,
    messages,
    stream: false,
  };
  if (withTools) payload.tools = buildToolDefinitions(config);

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
  return [...system, ...rest.slice(-maxHistory * 4)];
}

function parseArguments(raw) {
  if (raw == null) return {};
  if (typeof raw === 'object') return raw;
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw);
    } catch {
      return { command: raw, task: raw };
    }
  }
  return {};
}

const TOOL_NAMES = ['run_powershell', 'run_opencode'];

function extractToolCalls(message) {
  const calls = [];

  if (message.tool_calls?.length) {
    for (const tc of message.tool_calls) {
      const fn = tc.function || tc;
      if (!TOOL_NAMES.includes(fn.name)) continue;
      calls.push({ name: fn.name, arguments: parseArguments(fn.arguments) });
    }
    if (calls.length) return calls;
  }

  const content = message.content || '';
  for (const name of TOOL_NAMES) {
    const jsonRe = new RegExp(`\\{"name"\\s*:\\s*"${name}"[^}]+\\}`, 'gi');
    let m;
    while ((m = jsonRe.exec(content)) !== null) {
      try {
        const obj = JSON.parse(m[0]);
        calls.push({ name, arguments: parseArguments(obj.arguments) });
      } catch { /* skip */ }
    }
  }
  return calls;
}

function firstLine(text, max = 80) {
  const line = extractMeaningfulLine(text);
  return line.length <= max ? line : line.slice(0, max) + '…';
}

function extractMeaningfulLine(text) {
  const lines = (text || '').split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
  if (!lines.length) return '';
  if (lines[0] === '[stderr]') {
    const err = lines.find((l, i) => i > 0 && l && l !== '[stderr]');
    if (err) return err;
  }
  return lines[0];
}

/**
 * @param {{ tool: string, command?: string, task?: string, exitCode: number, output: string, guardAction?: string }[]} toolRuns
 */
export function formatUserReply(userText, toolRuns, config) {
  if (!toolRuns.length) return '已完成。';

  const last = toolRuns[toolRuns.length - 1];

  if (last.tool === 'run_opencode') {
    return formatOpenCodeReply(last);
  }

  const cmdLower = (last.command || '').toLowerCase();
  const out = (last.output || '').trim();

  if (last.exitCode !== 0) {
    return `失败：${firstLine(out, 100) || `退出码 ${last.exitCode}`}`;
  }

  if (/stop-process/i.test(last.command) && /chrome/i.test(cmdLower + out)) {
    return '已完成：已关闭 Chrome';
  }
  if (/stop-process/i.test(last.command)) {
    const proc = last.command.match(/Stop-Process\s+(?:-Name\s+)?['"]?(\w+)/i);
    return proc ? `已完成：已结束 ${proc[1]}` : '已完成：已结束进程';
  }
  if (/get-process/i.test(last.command) && /chrome/i.test(cmdLower)) {
    return /cannot find|找不到/i.test(out) ? 'Chrome 未在运行' : 'Chrome 正在运行';
  }
  if (/get-childitem|dir\s|ls\s/i.test(last.command)) {
    const lines = out.split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
    if (!lines.length || lines[0] === '(无输出)') return '已完成：目录为空';
    const preview = lines.slice(0, 5).join('、');
    return `已完成：${preview}${lines.length > 5 ? ` 等共 ${lines.length} 项` : ''}`;
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

function appendAgentAudit(entry) {
  try {
    const dir = join(homedir(), '.wechat-local-chat', 'logs');
    mkdirSync(dir, { recursive: true });
    appendFileSync(join(dir, 'commands.log'), JSON.stringify({ ts: new Date().toISOString(), ...entry }) + '\n', 'utf-8');
  } catch { /* ignore */ }
}

async function runTool(name, args, config, ctx) {
  const { classification, userText, force } = ctx;
  let guardAction = 'none';

  if (name === 'run_opencode') {
    if (force === 'fast' || config.agentForce === 'fast') {
      guardAction = 'block_oc_fast';
      name = 'run_powershell';
      const cmd = suggestPowerShellCommand(userText, config) || args.command || '';
      if (!cmd) return { tool: 'run_powershell', command: '', exitCode: -1, output: 'guard:fast模式禁止OpenCode', guardAction };
      args = { command: cmd };
    } else if (classification.level === 'simple') {
      guardAction = 'redirect_simple_to_ps';
      const cmd =
        suggestPowerShellCommand(userText, config) ||
        args.command ||
        '';
      if (cmd) {
        console.log(`[guard] simple task → powershell: ${cmd.slice(0, 80)}`);
        name = 'run_powershell';
        args = { command: cmd };
      }
    }
  }

  if (force === 'oc' || config.agentForce === 'oc') {
    if (name === 'run_powershell') {
      guardAction = 'force_oc';
      name = 'run_opencode';
      args = { task: userText };
    }
  }

  if (name === 'run_powershell') {
    const command = args.command || args.cmd || '';
    if (!command.trim()) {
      return { tool: 'run_powershell', command: '', exitCode: -1, output: '命令为空', guardAction };
    }
    console.log(`[agent] powershell: ${command.slice(0, 100)}`);
    const result = await execPowerShell(command, {
      workDir: config.workDir,
      timeoutSec: config.commandTimeoutSec,
      maxOutputChars: config.maxOutputChars,
      auditLog: false,
    });
    appendAgentAudit({
      routeTarget: 'powershell',
      classifierLevel: classification.level,
      brainTool: 'run_powershell',
      guardAction,
      command,
      exitCode: result.exitCode,
      outputPreview: result.output.slice(0, 200),
    });
    return { tool: 'run_powershell', command, ...result, guardAction };
  }

  if (name === 'run_opencode') {
    const task = args.task || args.command || userText;
    console.log(`[agent] opencode: ${task.slice(0, 80)}`);
    const result = await runOpenCode(task, config);
    appendAgentAudit({
      routeTarget: 'opencode',
      classifierLevel: classification.level,
      brainTool: 'run_opencode',
      guardAction,
      task: task.slice(0, 200),
      exitCode: result.exitCode,
      outputPreview: (result.output || '').slice(0, 200),
    });
    return { tool: 'run_opencode', task, ...result, guardAction };
  }

  return { tool: name, exitCode: -1, output: `未知工具: ${name}`, guardAction };
}

function formatToolResult(result) {
  return `exitCode: ${result.exitCode}\n${result.output}`;
}

/**
 * @param {string} userId
 * @param {string} userText
 * @param {object} config
 * @param {{ getMessages: () => object[], onProgress?: (text: string) => Promise<void>, classification?: object, force?: string }} ctx
 */
export async function runAgent(userId, userText, config, ctx) {
  const classification = ctx.classification || classifyTask(userText, config);
  const force = ctx.force || config.agentForce || 'none';

  console.log(
    `[classify] ${classification.level} s=${classification.simpleScore} c=${classification.complexScore} | ${classification.reasons.join(',')}`,
  );

  const messages = ctx.getMessages();
  const userContent =
    force === 'oc'
      ? `[强制:opencode] ${classification.hint}\n${userText}`
      : force === 'fast'
        ? `[强制:fast仅PowerShell] ${classification.hint}\n${userText}`
        : `[${classification.hint}]\n${userText}`;

  messages.push({ role: 'user', content: userContent });

  const maxTurns = config.maxAgentTurns ?? 8;
  const resultOnly = config.resultOnly !== false;
  /** @type {object[]} */
  const toolRuns = [];
  let nudgePsUsed = false;
  let nudgeOcUsed = false;

  const toolCtx = { classification, userText, force };

  for (let turn = 0; turn < maxTurns; turn++) {
    const data = await ollamaChat(trimHistory(messages, config.maxHistory), config, true);
    const msg = data.message || {};
    let toolCalls = extractToolCalls(msg);

    if (force === 'oc' && toolCalls.length === 0 && toolRuns.length === 0 && !nudgeOcUsed) {
      nudgeOcUsed = true;
      messages.push({ role: 'assistant', content: msg.content || '' });
      messages.push({ role: 'user', content: '必须调用 run_opencode 完成此任务。' });
      continue;
    }

    if (toolCalls.length === 0) {
      if (!nudgePsUsed && ACTION_RE.test(userText) && toolRuns.length === 0 && force !== 'oc') {
        nudgePsUsed = true;
        messages.push({ role: 'assistant', content: msg.content || '' });
        messages.push({ role: 'user', content: NUDGE_PS });
        continue;
      }

      if (
        !nudgeOcUsed &&
        classification.level === 'complex' &&
        toolRuns.length === 0 &&
        force !== 'fast'
      ) {
        nudgeOcUsed = true;
        messages.push({ role: 'assistant', content: msg.content || '' });
        messages.push({ role: 'user', content: NUDGE_OC });
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
      if (config.notifyEachCommand && ctx.onProgress) {
        const preview = tc.arguments.command || tc.arguments.task || '';
        await ctx.onProgress(`正在执行:\n${preview.slice(0, 120)}`);
      }
      const result = await runTool(tc.name, tc.arguments, config, toolCtx);
      toolRuns.push(result);
      messages.push({
        role: 'tool',
        tool_name: result.tool,
        content: formatToolResult(result),
      });
    }

    if (resultOnly && toolRuns.length > 0) {
      const reply = formatUserReply(userText, toolRuns, config);
      messages.push({ role: 'assistant', content: reply });
      return reply;
    }
  }

  if (toolRuns.length > 0) {
    return formatUserReply(userText, toolRuns, config);
  }
  return '已达到最大执行轮次，请简化任务或分步发送指令。';
}

export function getAgentSystemPrompt(config) {
  let prompt = config.agentSystemPrompt || BRAIN_PROMPT;
  if (config.chromePath) {
    prompt += `\n本机 Chrome: ${config.chromePath}（打开/带URL启动用此路径）。`;
  }
  if (config.agentForce === 'fast') {
    prompt += '\n当前强制：仅可使用 run_powershell。';
  }
  if (config.agentForce === 'oc') {
    prompt += '\n当前强制：必须使用 run_opencode。';
  }
  return prompt;
}

export function truncateReply(text, maxChars = 120) {
  const t = (text || '').trim();
  return t.length <= maxChars ? t : t.slice(0, maxChars) + '…';
}
