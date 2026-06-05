/**
 * OpenCode serve health + spawn via attach
 */
import { spawn } from 'node:child_process';
import { appendFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { buildCliPrompt } from './cli-runner-core.js';

const LOG_DIR = join(homedir(), '.wechat-local-chat', 'logs');
const SCRIPTS_DIR = join(dirname(fileURLToPath(import.meta.url)), '..', 'scripts');

/** Resolve npm global CLI on Windows */
export function resolveCliBinary(name, configPath) {
  if (configPath && existsSync(configPath)) return configPath;
  const candidates = [
    join(process.env.APPDATA || '', 'npm', `${name}.cmd`),
    join(process.env.LOCALAPPDATA || '', 'npm', `${name}.cmd`),
    join(process.env.APPDATA || '', 'npm', name),
  ];
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  return name;
}

/**
 * @param {string} serveUrl
 */
export async function checkServeHealth(serveUrl) {
  try {
    const res = await fetch(serveUrl, { method: 'GET', signal: AbortSignal.timeout(3000) });
    return res.ok || res.status === 404 || res.status === 405;
  } catch {
    return false;
  }
}

/**
 * Ensure opencode serve is running (spawn start script on Windows)
 * @param {object} config
 */
export async function ensureOpenCodeServe(config) {
  const oc = config.cliRouting?.opencode || {};
  const serveUrl = oc.serveUrl || 'http://127.0.0.1:4096';
  if (await checkServeHealth(serveUrl)) return true;

  const startScript = join(SCRIPTS_DIR, 'start-opencode-serve.ps1');
  if (!existsSync(startScript)) return false;

  await new Promise((resolve) => {
    spawn(
      'powershell.exe',
      ['-ExecutionPolicy', 'Bypass', '-File', startScript],
      { windowsHide: true, shell: false },
    ).on('close', () => resolve());
  });

  for (let i = 0; i < 15; i++) {
    await new Promise((r) => setTimeout(r, 1000));
    if (await checkServeHealth(serveUrl)) return true;
  }
  return false;
}

function spawnCli(command, args, opts = {}) {
  const {
    cwd = process.cwd(),
    env = process.env,
    timeoutSec = 300,
    maxOutputChars = 8000,
  } = opts;

  let execCmd = command;
  let execArgs = args;
  if (process.platform === 'win32' && /\.cmd$/i.test(command)) {
    execCmd = 'cmd.exe';
    execArgs = ['/c', command, ...args];
  }

  return new Promise((resolve) => {
    const child = spawn(execCmd, execArgs, { cwd, env, windowsHide: true, shell: false });
    let stdout = '';
    let stderr = '';
    let killed = false;
    const timer = setTimeout(() => {
      killed = true;
      child.kill('SIGTERM');
    }, timeoutSec * 1000);

    child.stdout?.on('data', (d) => { stdout += d.toString(); });
    child.stderr?.on('data', (d) => { stderr += d.toString(); });

    child.on('close', (code) => {
      clearTimeout(timer);
      const exitCode = killed ? -1 : (code ?? 1);
      let out = stdout.trim();
      if (!out && stderr.trim()) out = stderr.trim();
      if (killed) out += (out ? '\n' : '') + `[超时 ${timeoutSec}s 已终止]`;
      if (out.length > maxOutputChars) out = out.slice(0, maxOutputChars) + `\n...[截断]`;
      resolve({ exitCode, output: out || '(无输出)', stderr: stderr.trim() });
    });

    child.on('error', (err) => {
      clearTimeout(timer);
      resolve({ exitCode: -1, output: `执行失败: ${err.message}`, stderr: '' });
    });
  });
}

/**
 * @param {string} taskText
 * @param {object} config
 */
export async function runOpenCode(taskText, config) {
  const rc = config.cliRouting || {};
  const oc = rc.opencode || {};
  const serveUrl = oc.serveUrl || 'http://127.0.0.1:4096';
  const requireServe = oc.requireServe !== false;

  if (requireServe) {
    const ok = await ensureOpenCodeServe(config);
    if (!ok) {
      return {
        exitCode: -1,
        output: 'OpenCode serve 未就绪，请运行 scripts/start-opencode-serve.ps1',
      };
    }
  }

  const prompt = buildCliPrompt(taskText);
  const model = oc.model || 'opencode/deepseek-v4-flash-free';
  const args = [
    'run',
    prompt,
    '--attach',
    serveUrl,
    '--dir',
    config.workDir,
    '-m',
    model,
    '--dangerously-skip-permissions',
  ];

  const opencodeBin = resolveCliBinary('opencode', oc.binaryPath);
  const result = await spawnCli(opencodeBin, args, {
    cwd: config.workDir,
    timeoutSec: rc.cliTimeoutSec ?? 300,
    maxOutputChars: config.maxOutputChars ?? 8000,
  });

  appendRouteAudit('opencode', taskText, result);
  return result;
}

function firstLine(text, max = 120) {
  const line = (text || '').split(/\r?\n/).map((s) => s.trim()).find(Boolean) || '';
  return line.length <= max ? line : line.slice(0, max) + '…';
}

/**
 * @param {{ exitCode: number, output: string, stderr?: string }} result
 */
export function formatOpenCodeReply(result) {
  if (result.exitCode !== 0) {
    const err =
      firstLine(result.output, 100) ||
      firstLine(result.stderr, 100) ||
      `退出码 ${result.exitCode}`;
    return `失败：${err}`;
  }
  const out = (result.output || '').trim();
  if (!out || out === '(无输出)') return '已完成。';
  const lines = out.split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
  return firstLine(lines[lines.length - 1] || out, 200);
}

function appendRouteAudit(routeTarget, userText, result) {
  try {
    mkdirSync(LOG_DIR, { recursive: true });
    appendFileSync(
      join(LOG_DIR, 'commands.log'),
      JSON.stringify({
        ts: new Date().toISOString(),
        routeTarget,
        task: userText.slice(0, 200),
        exitCode: result.exitCode,
        outputPreview: (result.output || '').slice(0, 200),
      }) + '\n',
      'utf-8',
    );
  } catch { /* ignore */ }
}

export { buildCliPrompt };
