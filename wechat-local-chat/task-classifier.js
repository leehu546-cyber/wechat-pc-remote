/**
 * Task complexity classifier — Layer 1 hint for brain (does not route directly)
 */

const DEFAULT_STRIP = ['给我', '帮我', '请', '麻烦', '能不能', '可以'];

const SIMPLE_ACTION =
  /关闭|打开|启动|结束|退出|列出|查看|查一下|查下|关机|重启|休眠|运行(?!\s*测试)|结束进程/i;

const SIMPLE_OBJECT =
  /Chrome|chrome|谷歌|浏览器|进程|目录|文件夹|文件|程序|记事本|计算器|资源管理器/i;

const COMPLEX_BROWSER =
  /搜索|网页|点击|填写|登录|下载|截图|百度|Google|google/i;

const COMPLEX_CODE =
  /\.(py|js|ts|mjs|tsx|jsx|go|rs|json)\b|git|提交|重构|单元测试|bug|Bug|代码|函数/i;

const COMPLEX_MULTI =
  /然后|接着|先.*再|同时|并且|分步|一共.*步/i;

const COMPLEX_COGNITIVE =
  /分析|对比|设计|写一份|调研|总结|解释.*并|修复.*并/i;

const WIN_PATH_RE = /[A-Za-z]:\\[^\s]+/;

const FILE_EXT_RE = /\.(py|js|ts|mjs|json|md|tsx|jsx|go|rs)\b/i;

/**
 * @param {string} text
 * @param {object} config
 */
export function stripPoliteness(text, config) {
  let t = (text || '').trim();
  const prefixes = config?.taskClassification?.stripPrefixes || DEFAULT_STRIP;
  for (const p of prefixes) {
    if (t.startsWith(p)) {
      t = t.slice(p.length).trim();
      break;
    }
  }
  return t;
}

/**
 * @param {string} userText
 * @param {object} config
 * @returns {{
 *   level: 'simple' | 'complex' | 'ambiguous',
 *   simpleScore: number,
 *   complexScore: number,
 *   reasons: string[],
 *   hint: string,
 *   normalizedText: string
 * }}
 */
export function classifyTask(userText, config = {}) {
  const tc = config.taskClassification || {};
  const margin = tc.ambiguousMargin ?? 1;
  const normalized = stripPoliteness(userText, config);

  let simpleScore = 0;
  let complexScore = 0;
  /** @type {string[]} */
  const reasons = [];

  if (SIMPLE_ACTION.test(normalized)) {
    simpleScore += 2;
    reasons.push('简单动作词');
  }
  if (SIMPLE_OBJECT.test(normalized)) {
    simpleScore += 1;
    reasons.push('本地对象(进程/目录/程序)');
  }

  if (COMPLEX_BROWSER.test(normalized)) {
    complexScore += 3;
    reasons.push('浏览器/搜索交互');
  }
  if (COMPLEX_CODE.test(normalized) || FILE_EXT_RE.test(normalized)) {
    complexScore += 3;
    reasons.push('代码/仓库');
  }
  if (COMPLEX_MULTI.test(normalized)) {
    complexScore += 3;
    reasons.push('多步连接词');
  }
  if (COMPLEX_COGNITIVE.test(normalized)) {
    complexScore += 2;
    reasons.push('分析/解释类');
  }
  if (WIN_PATH_RE.test(normalized) && /改|写|创建|修/i.test(normalized)) {
    complexScore += 2;
    reasons.push('路径+修改');
  }

  // 关/开 + 浏览器 且无搜索 → 简单（覆盖浏览器关键词）
  if (/关闭|打开|启动|结束/i.test(normalized) && /浏览器|Chrome|chrome|谷歌/i.test(normalized)) {
    if (!COMPLEX_BROWSER.test(normalized)) {
      simpleScore += 3;
      complexScore = Math.max(0, complexScore - 2);
      reasons.push('仅关开浏览器→简单');
    }
  }

  // 列目录模板
  if (/列出|查看|列一下/i.test(normalized) && /盘|目录|文件夹/i.test(normalized)) {
    simpleScore += 2;
    reasons.push('列目录模板');
  }

  let level;
  let hint;
  const diff = simpleScore - complexScore;

  if (diff >= margin) {
    level = 'simple';
    hint = '分类:simple — 优先 run_powershell，单条命令可完成';
  } else if (complexScore - simpleScore >= margin) {
    level = 'complex';
    hint = '分类:complex — 优先 run_opencode 助手';
  } else {
    level = 'ambiguous';
    hint = '分类:ambiguous — 能一条 PowerShell 则用 run_powershell，否则 run_opencode';
  }

  return {
    level,
    simpleScore,
    complexScore,
    reasons,
    hint,
    normalizedText: normalized,
  };
}

/**
 * Parse /fast /oc force prefix from user message
 * @returns {{ force: 'none'|'fast'|'oc', taskText: string }}
 */
export function parseForcePrefix(userText) {
  const text = (userText || '').trim();
  if (/^\/fast\s+/i.test(text)) {
    return { force: 'fast', taskText: text.replace(/^\/fast\s+/i, '').trim() || text };
  }
  if (/^\/oc\s+/i.test(text) || /^\/opencode\s+/i.test(text)) {
    return { force: 'oc', taskText: text.replace(/^\/(?:oc|opencode)\s+/i, '').trim() || text };
  }
  return { force: 'none', taskText: text };
}

/**
 * Suggest PowerShell for simple guard when brain wrongly picks opencode
 * @param {string} userText
 * @param {object} config
 */
export function suggestPowerShellCommand(userText, config) {
  const t = stripPoliteness(userText, config);
  const chrome = config.chromePath || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

  if (/关闭|结束|退出/i.test(t) && /Chrome|chrome|谷歌|浏览器/i.test(t)) {
    return "Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force";
  }
  if (/打开|启动/i.test(t) && /Chrome|chrome|谷歌|浏览器/i.test(t)) {
    return `Start-Process '${chrome}'`;
  }
  if (/列出|查看|列/i.test(t) && /D盘|D:\\/i.test(t)) {
    return 'Get-ChildItem D:\\ | Select-Object -ExpandProperty Name';
  }
  if (/列出|查看|列/i.test(t) && /C盘|C:\\/i.test(t)) {
    return 'Get-ChildItem C:\\ | Select-Object -ExpandProperty Name';
  }
  return null;
}
