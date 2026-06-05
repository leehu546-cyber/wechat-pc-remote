#!/usr/bin/env node
/**
 * 微信 ClawBot <-> 本地 Ollama 纯对话桥接
 * 微信发消息 -> qwen2.5:7b 回复 -> 发回微信
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync, unlinkSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { login } from '../cli-in-wechat/dist/ilink/auth.js';
import { ILinkClient } from '../cli-in-wechat/dist/ilink/client.js';

const DATA_DIR = join(homedir(), '.wechat-local-chat');
const CREDENTIALS_FILE = join(DATA_DIR, 'credentials.json');
const CONFIG_FILE = join(import.meta.dirname, 'config.json');

const DEFAULT_CONFIG = {
  ollamaUrl: 'http://127.0.0.1:11434',
  model: 'qwen2.5:7b',
  systemPrompt: '你是一个简洁友好的中文助手。回答要简短清楚，适合在手机微信里阅读。',
  maxHistory: 20,
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

/** 每个微信用户独立对话历史 */
const histories = new Map();

function getHistory(userId, config) {
  if (!histories.has(userId)) {
    histories.set(userId, [
      { role: 'system', content: config.systemPrompt },
    ]);
  }
  return histories.get(userId);
}

function trimHistory(messages, maxHistory) {
  const system = messages.filter((m) => m.role === 'system');
  const rest = messages.filter((m) => m.role !== 'system');
  const kept = rest.slice(-maxHistory * 2);
  return [...system, ...kept];
}

async function chatWithOllama(userId, userText, config) {
  const messages = getHistory(userId, config);
  messages.push({ role: 'user', content: userText });
  const payload = {
    model: config.model,
    messages: trimHistory(messages, config.maxHistory),
    stream: false,
  };

  const res = await fetch(`${config.ollamaUrl}/api/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
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
    // cli-in-wechat node_modules
    const mod = await import('../cli-in-wechat/node_modules/qrcode-terminal/lib/main.js');
    const qt = mod.default || mod;
    qrGenerate = qt.generate?.bind(qt) ?? null;
  }

  return login((qrContent) => {
    if (qrGenerate) {
      qrGenerate(qrContent, { small: true });
    } else {
      console.log('请用微信扫描二维码:', qrContent);
    }
    writeLoginHtml(qrContent);
  });
}

/** 生成浏览器扫码页，避免终端二维码看不清 */
function writeLoginHtml(qrContent) {
  mkdirSync(DATA_DIR, { recursive: true, mode: 0o700 });
  const htmlPath = join(DATA_DIR, 'login.html');
  const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=${encodeURIComponent(qrContent)}`;
  const html = `<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>微信 ClawBot 登录</title>
<style>body{font-family:sans-serif;text-align:center;padding:2rem;background:#f5f5f5}
.box{background:#fff;padding:2rem;border-radius:12px;display:inline-block;box-shadow:0 2px 12px #0001}
img{border:1px solid #ddd;border-radius:8px}</style></head>
<body><div class="box"><h2>微信 ClawBot 扫码登录</h2>
<p>用手机微信扫描下方二维码，在 ClawBot 中确认</p>
<img src="${qrUrl}" width="400" height="400" alt="QR"/>
<p style="color:#666;font-size:14px">二维码约 5 分钟有效，过期后刷新本页或重启桥接</p>
</div></body></html>`;
  writeFileSync(htmlPath, html, 'utf-8');
  console.log(`[提示] 浏览器扫码页: file:///${htmlPath.replace(/\\/g, '/')}`);
}

const processing = new Set();

async function main() {
  const config = loadConfig();

  console.log('');
  console.log('  微信 ClawBot  <->  本地 Ollama 对话');
  console.log(`  模型: ${config.model}`);
  console.log('');

  await checkOllama(config);

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
      await ilink.sendText(uid, '已清空对话，我们可以重新开始。');
      return;
    }
    if (userText === '/help' || userText === '/帮助') {
      await ilink.sendText(
        uid,
        '本地对话模式\n\n直接发文字即可聊天\n/new 或 /重置 — 清空上下文\n/help — 本帮助',
      );
      return;
    }
    if (processing.has(uid)) {
      await ilink.sendText(uid, '上一条还在想，请稍等…');
      return;
    }

    processing.add(uid);
    const stopTyping = await ilink.startTyping(uid);

    try {
      console.log(`[收] ${userText.substring(0, 80)}`);
      const reply = await chatWithOllama(uid, userText, config);
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
  console.log('[ok] 桥接已启动 — 在微信 ClawBot 里发消息即可');
  console.log('     按 Ctrl+C 退出\n');

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
