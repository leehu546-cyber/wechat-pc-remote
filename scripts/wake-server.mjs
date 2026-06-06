#!/usr/bin/env node
/**
 * Mobile wake display server — binds 0.0.0.0 (no Windows http.sys urlacl).
 */
import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { readFileSync, existsSync, appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { join, dirname, extname } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "..");
const mobileDir = join(repoRoot, "wake-mobile");
const wakeScript = join(__dirname, "wake-screen.ps1");
const configPath = join(homedir(), ".weclaw", "wake-server.json");
const logPath = join(homedir(), ".weclaw", "wake-server.log");

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".json": "application/manifest+json; charset=utf-8",
  ".svg": "image/svg+xml",
};

function log(msg) {
  const line = `${new Date().toISOString().replace("T", " ").slice(0, 19)} ${msg}\n`;
  try {
    mkdirSync(dirname(logPath), { recursive: true });
    appendFileSync(logPath, line, "utf8");
  } catch { /* ignore */ }
}

function loadConfig() {
  if (!existsSync(configPath)) {
    const token = randomUUID().replace(/-/g, "");
    const cfg = { port: 18790, token, bind: "0.0.0.0" };
    mkdirSync(dirname(configPath), { recursive: true });
    writeFileSync(configPath, JSON.stringify(cfg, null, 2), "utf8");
    return cfg;
  }
  const raw = readFileSync(configPath, "utf8").replace(/^\uFEFF/, "");
  return JSON.parse(raw);
}

const config = loadConfig();
const PORT = config.port || 18790;
const TOKEN = config.token || "";
const HOST = config.bind === "+" ? "0.0.0.0" : config.bind || "0.0.0.0";

let lastWake = 0;

function sendJson(res, code, body) {
  const data = JSON.stringify(body);
  res.writeHead(code, { "Content-Type": "application/json; charset=utf-8" });
  res.end(data);
}

function sendText(res, code, text, type = "text/plain; charset=utf-8") {
  res.writeHead(code, { "Content-Type": type });
  res.end(text);
}

function getToken(req) {
  const auth = req.headers.authorization || "";
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (m) return m[1].trim();
  try {
    const u = new URL(req.url, `http://${req.headers.host}`);
    return u.searchParams.get("t") || u.searchParams.get("token") || "";
  } catch {
    return "";
  }
}

function wakeDisplay() {
  return new Promise((resolve) => {
    const ps = spawn(
      "powershell.exe",
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", wakeScript],
      { windowsHide: true }
    );
    let out = "";
    ps.stdout?.on("data", (d) => { out += d; });
    ps.stderr?.on("data", (d) => { out += d; });
    ps.on("close", () => {
      const text = out.trim();
      if (text.includes("WECHAT_OK")) {
        resolve({ ok: true, message: "已唤醒显示器" });
      } else {
        resolve({ ok: true, message: text || "wake sent" });
      }
    });
    ps.on("error", (e) => resolve({ ok: false, message: String(e) }));
  });
}

function serveStatic(res, name) {
  const file = join(mobileDir, name);
  if (!existsSync(file)) {
    sendText(res, 404, "not found");
    return;
  }
  const ext = extname(file);
  sendText(res, 200, readFileSync(file), MIME[ext] || "application/octet-stream");
}

const server = createServer(async (req, res) => {
  const path = (req.url || "/").split("?")[0];

  if (path === "/" || path === "/index.html") {
    serveStatic(res, "index.html");
    return;
  }
  if (path === "/manifest.json") {
    serveStatic(res, "manifest.json");
    return;
  }
  if (path === "/icon.svg") {
    serveStatic(res, "icon.svg");
    return;
  }
  if (path === "/api/health" && req.method === "GET") {
    sendJson(res, 200, { ok: true, service: "wake-server-node" });
    return;
  }
  if (path === "/api/wake" && req.method === "POST") {
    const t = getToken(req);
    if (t !== TOKEN) {
      log(`unauthorized wake from ${req.socket.remoteAddress}`);
      sendJson(res, 401, { ok: false, error: "unauthorized" });
      return;
    }
    const now = Date.now();
    if (now - lastWake < 2000) {
      sendJson(res, 429, { ok: false, error: "rate limited" });
      return;
    }
    lastWake = now;
    const result = await wakeDisplay();
    log(`wake from ${req.socket.remoteAddress} -> ${result.message}`);
    sendJson(res, 200, result);
    return;
  }

  sendText(res, 404, "not found");
});

server.listen(PORT, HOST, () => {
  log(`started on http://${HOST}:${PORT}/`);
  console.log(`wake-server listening http://${HOST}:${PORT}/`);
});
