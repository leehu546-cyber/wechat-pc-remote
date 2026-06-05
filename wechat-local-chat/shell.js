/**
 * PowerShell execution for WeChat agent
 */
import { spawn } from 'node:child_process';
import { appendFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

const LOG_DIR = join(homedir(), '.wechat-local-chat', 'logs');

/**
 * @param {string} command
 * @param {{ workDir?: string, timeoutSec?: number, maxOutputChars?: number, auditLog?: boolean }} opts
 */
export function execPowerShell(command, opts = {}) {
  const {
    workDir = process.cwd(),
    timeoutSec = 120,
    maxOutputChars = 4000,
    auditLog = true,
  } = opts;

  return new Promise((resolve) => {
    const child = spawn(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', command],
      {
        cwd: workDir,
        windowsHide: true,
        env: process.env,
      },
    );

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
      let out = stdout;
      if (stderr) out += (out ? '\n' : '') + `[stderr]\n${stderr}`;
      if (killed) out += (out ? '\n' : '') + `[超时 ${timeoutSec}s 已终止]`;
      if (out.length > maxOutputChars) {
        out = out.slice(0, maxOutputChars) + `\n...[截断，共 ${stdout.length + stderr.length} 字符]`;
      }
      const result = { exitCode, output: out || '(无输出)' };
      if (auditLog) appendAudit(command, result);
      resolve(result);
    });

    child.on('error', (err) => {
      clearTimeout(timer);
      const result = { exitCode: -1, output: `执行失败: ${err.message}` };
      if (auditLog) appendAudit(command, result);
      resolve(result);
    });
  });
}

function appendAudit(command, result) {
  try {
    mkdirSync(LOG_DIR, { recursive: true });
    const line = JSON.stringify({
      ts: new Date().toISOString(),
      command,
      exitCode: result.exitCode,
      outputPreview: result.output.slice(0, 200),
    });
    appendFileSync(join(LOG_DIR, 'commands.log'), line + '\n', 'utf-8');
  } catch {
    /* ignore */
  }
}
