/**
 * Shared CLI prompt builder
 * @param {string} userText
 */
export function buildCliPrompt(userText) {
  return `你在用户 Windows 电脑上执行任务。直接操作，不要教用户手动点击。
任务：${userText}
完成后只用一句中文说明结果（成功或失败原因），不要列命令或教程。`;
}
