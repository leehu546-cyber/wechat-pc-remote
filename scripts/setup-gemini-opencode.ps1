# Install OpenCode + configure for WeClaw ACP (unattended WeChat use)
$ErrorActionPreference = "Stop"

Write-Host "=== OpenCode setup for WeClaw ===" -ForegroundColor Cyan

Write-Host "`n[1/2] Installing OpenCode CLI..." -ForegroundColor Yellow
npm install -g opencode-ai
opencode --version

Write-Host "`n[2/2] Configuring global opencode.json..." -ForegroundColor Yellow
$ocDir = Join-Path $env:USERPROFILE ".config\opencode"
New-Item -ItemType Directory -Path $ocDir -Force | Out-Null
@'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "ollama/qwen2.5:7b",
  "permission": {
    "edit": "allow",
    "bash": "allow",
    "webfetch": "allow",
    "websearch": "allow"
  },
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": { "baseURL": "http://127.0.0.1:11434/v1" },
      "models": {
        "qwen2.5:7b": { "name": "Qwen 2.5 7B" }
      }
    }
  }
}
'@ | Set-Content -Path (Join-Path $ocDir "opencode.json") -Encoding UTF8

Write-Host @"

Free cloud models (no API key):
  ollama/qwen2.5:7b
  opencode/minimax-m3-free
  opencode/mimo-v2.5-free

WeClaw uses: opencode acp (no serve needed)

Test:
  opencode run "say OK" -m ollama/qwen2.5:7b --dir D:\cursor\61
"@ -ForegroundColor White

Write-Host "`nDone." -ForegroundColor Green
