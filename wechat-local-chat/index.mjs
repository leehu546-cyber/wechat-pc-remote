#!/usr/bin/env node
/**
 * WeChat ClawBot <-> Ollama brain + OpenCode assistant
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync, unlinkSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { login } from '../cli-in-wechat/dist/ilink/auth.js';
import { ILinkClient } from '../cli-in-wechat/dist/ilink/client.js';
import { runAgent, getAgentSystemPrompt, truncateReply } from './agent.js';
import { classifyTask, parseForcePrefix } from './task-classifier.js';
import { detectChromePath } from './shell.js';
import { checkServeHealth, ensureOpenCodeServe } from './opencode-client.js';

const DATA_DIR = join(homedir(), '.wechat-local-chat');
const CREDENTIALS_FILE = join(DATA_DIR, 'credentials.json');
const CONFIG_FILE = join(import.meta.dirname, 'config.json');

const DEFAULT_CONFIG = {
  ollamaUrl: 'http://127.0.0.1:11434',
  model: 'qwen2.5:7b',
  systemPrompt: '你是一个简洁友好的中文助手。回答要简短清楚，适合在手机微信里阅读。',
  agentMode: true,
  agentSystemPrompt: null,
  maxHistory: 20,
  maxAgentTurns: 8,
  commandTimeoutSec: 120,
  maxOutputChars: 4000,
  workDir: 'D:\\cursor\\61',
  notifyEachCommand: false,
  notifyOnStart: true,
  startMessage: '处理中…',
  resultOnly: true,
  maxReplyChars: 120,
  auditLog: true,
  taskClassification: { ambiguousMargin: 1 },
  cliRouting: {
    cliTimeoutSec: 300,
    opencode: {
      model: 'opencode/deepseek-v4-flash-free',
      serveUrl: 'http://127.0.0.1:4096',
      requireServe: true,
    },
  },
  serveWatchdogSec: 300,
};

function loadConfig() {
  try {
    return { ...DEFAULT_CONFIG, ...JSON.parse(readFileSync(CONFIG_FILE, 'utf-8')) };
  } catch {
    return { ...DEFAULT_CONFIG };
  }
}

function loadCredentials() {
  if (!existsSync(CREDENTIALS_FILE)) return null;
  try {
    const data = JSON.parse(readFileSync(CREDENTIALS_FILE, 'utf-8'));
    return data.botToken ? data : null;
  } catch {
    return null;
  }
}

function saveCredentials(creds) {
  mkdirSync(DATA_DIR, { recursive: true, mode: 0o700 });
  writeFileSync(CREDENTIALS_FILE, JSON.stringify(creds, null, 2), { mode: 0o600 });
}

async function checkOllama(config) {
  const res = await fetch(`${config.ollamaUrl}/api/tags`);
  if (!res.ok) throw new Error(`Ollama 未响应: HTTP ${res.status}`);
  const data = await res.json();
  const names = (data.models || []).map((m) => m.name);
  if (!names.some((n) => n === config.model || n.startsWith(config.model + ':'))) {
    console.warn(`[警告] 未找到模型 ${config.model}，当前可用: ${names.join(', ') || '无'}`);
  }
  console.log(`[ok] Ollama 已连接，使用模型: ${config.model}`);
}

/** @type {Map<string, object[]>} */
const histories = new Map();
/** @type {Map<string, 'agent'|'chat'>} */
const userModes = new Map();

function getMode(uid, config) {
  return userModes.get(uid) ?? (config.agentMode !== false ? 'agent' : 'chat');
}

function initHistory(uid, config, mode) {
  const system = mode === 'agent' ? getAgentSystemPrompt(config) : config.systemPrompt;
  histories.set(uid, [{ role: 'system', content: system }]);
  userModes.set(uid, mode);
}

function getHistory(uid, config) {
  const mode = getMode(uid, config);
  if (!histories.has(uid)) initHistory(uid, config, mode);
  return histories.get(uid);
}

function trimHistory(messages, maxHistory) {
  const system = messages.filter((m) => m.role === 'system');
  const rest = messages.filter((m) => m.role !== 'system');
  return [...system, ...rest.slice(-maxHistory * 2)];
}

async function chatWithOllama(uid, userText, config) {
  const messages = getHistory(uid, config);
  messages.push({ role: 'user', content: userText });
  const res = await fetch(`${config.ollamaUrl}/api/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: config.model,
      messages: trimHistory(messages, config.maxHistory),
      stream: false,
    }),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Ollama 请求失败: HTTP ${res.status} ${body}`);
  }
  const data = await res.json();
  const reply = data.message?.content?.trim() || '(模型无回复)';
  messages.push({ role: 'assistant', content: reply });
  return reply;
}

async function wechatLogin() {
  let qrGenerate = null;
  try {
    const mod = await import('qrcode-terminal');
    const qt = mod.default || mod;
    qrGenerate = qt.generate?.bind(qt) ?? null;
  } catch {
    const mod = await import('../cli-in-wechat/node_modules/qrcode-terminal/lib/main.js');
    const qt = mod.default || mod;
    qrGenerate = qt.generate?.bind(qt) ?? null;
  }
  return login((qrContent) => {
    if (qrGenerate) qrGenerate(qrContent, { small: true });
    else console.log('请用微信扫描二维码:', qrContent);
    writeLoginHtml(qrContent);
  });
}

function writeLoginHtml(qrContent) {
  mkdirSync(DATA_DIR, { recursive: true, mode: 0o700 });
  const htmlPath = join(DATA_DIR, 'login.html');
  const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=${encodeURIComponent(qrContent)}`;
  writeFileSync(htmlPath, `<!DOCTYPE html><html lang="zh-CN"><head><meta charset="utf-8"><title>登录</title></head><body><img src="${qrUrl}" width="400"/></body></html>`, 'utf-8');
}

function helpText(mode) {
  if (mode === 'agent') {
    return `Agent 模式（大脑调度）

本地 Ollama 为大脑，自动选择：
  简单 → PowerShell（快）
  复杂 → OpenCode 助手（常驻在线）

强制：
/fast — 仅 PowerShell
/oc 或 /opencode — 仅 OpenCode

/chat /agent /new /help`;
  }
  return `Chat 模式（纯对话）

/agent — 切换控制模式
/new — 清空上下文
/help — 本帮助`;
}

function startServeWatchdog(config) {
  const sec = config.serveWatchdogSec ?? 300;
  const serveUrl = config.cliRouting?.opencode?.serveUrl || 'http://127.0.0.1:4096';
  setInterval(async () => {
    if (!(await checkServeHealth(serveUrl))) {
      console.log('[watchdog] OpenCode serve down, restarting...');
      await ensureOpenCodeServe(config);
    }
  }, sec * 1000);
}

const processing = new Set();

async function main() {
  const config = loadConfig();
  const chromePath = await detectChromePath();
  if (chromePath) {
    config.chromePath = chromePath;
    console.log(`[ok] Chrome: ${chromePath}`);
  }

  console.log('');
  console.log('  微信 ClawBot  <->  Ollama 大脑 + OpenCode 助手');
  console.log(`  模型: ${config.model} | OpenCode: ${config.cliRouting?.opencode?.model}`);
  console.log(`  工作目录: ${config.workDir}`);
  console.log('');

  await checkOllama(config);

  const serveOk = await ensureOpenCodeServe(config);
  const serveUrl = config.cliRouting?.opencode?.serveUrl || 'http://127.0.0.1:4096';
  console.log(serveOk ? `[ok] OpenCode serve: ${serveUrl}` : `[!!] OpenCode serve 未就绪，复杂任务可能失败`);

  startServeWatchdog(config);

  let credentials = loadCredentials();
  if (!credentials) {
    console.log('[..] 需要微信扫码登录...');
    credentials = await wechatLogin();
    saveCredentials(credentials);
    const loginHtml = join(DATA_DIR, 'login.html');
    if (existsSync(loginHtml)) {
      try { unlinkSync(loginHtml); } catch { /* ignore */ }
    }
    console.log('[ok] 微信登录成功');
  } else {
    console.log('[ok] 使用已保存的微信登录');
  }

  const ilink = new ILinkClient(credentials);

  ilink.onMessage(async (msg, text) => {
    const uid = msg.from_user_id;
    const userText = text.trim();
    if (!userText) return;

    if (userText === '/new' || userText === '/重置') {
      histories.delete(uid);
      userModes.delete(uid);
      await ilink.sendText(uid, '已清空对话，我们可以重新开始。');
      return;
    }
    if (userText === '/chat') {
      initHistory(uid, config, 'chat');
      await ilink.sendText(uid, '已切换为 Chat 模式（纯对话，不执行命令）。');
      return;
    }
    if (userText === '/agent') {
      initHistory(uid, config, 'agent');
      await ilink.sendText(uid, '已切换为 Agent 模式（大脑调度 PowerShell + OpenCode）。');
      return;
    }
    if (userText === '/help' || userText === '/帮助') {
      await ilink.sendText(uid, helpText(getMode(uid, config)));
      return;
    }
    if (processing.has(uid)) {
      await ilink.sendText(uid, '上一条还在处理，请稍等…');
      return;
    }

    processing.add(uid);
    const stopTyping = await ilink.startTyping(uid);
    const mode = getMode(uid, config);

    try {
      console.log(`[收][${mode}] ${userText.substring(0, 80)}`);
      let reply;

      if (mode === 'agent') {
        if (config.notifyOnStart !== false) {
          await ilink.sendText(uid, config.startMessage || '处理中…', {
            streamType: 'intermediate',
          });
        }

        const { force, taskText } = parseForcePrefix(userText);
        const agentConfig = { ...config };
        if (force === 'fast') agentConfig.agentForce = 'fast';
        if (force === 'oc') agentConfig.agentForce = 'oc';

        const classification = classifyTask(taskText, config);
        console.log(`[brain] ${classification.level} | force=${force}`);

        reply = await runAgent(uid, taskText, agentConfig, {
          getMessages: () => getHistory(uid, config),
          classification,
          force,
          onProgress: config.notifyEachCommand
            ? (t) => ilink.sendText(uid, t, { streamType: 'intermediate' })
            : undefined,
        });
        reply = truncateReply(reply, config.maxReplyChars ?? 120);
      } else {
        reply = await chatWithOllama(uid, userText, config);
        reply = truncateReply(reply, config.maxReplyChars ?? 500);
      }

      console.log(`[回] ${reply.substring(0, 80)}${reply.length > 80 ? '…' : ''}`);
      await ilink.sendText(uid, reply);
    } catch (err) {
      console.error('[错误]', err);
      await ilink.sendText(uid, `出错了: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      stopTyping();
      processing.delete(uid);
    }
  });

  ilink.start();
  console.log('[ok] 桥接已启动 — 在微信 ClawBot 里发消息即可\n');

  const shutdown = () => {
    ilink.stop();
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  console.error('启动失败:', err);
  process.exit(1);
});
