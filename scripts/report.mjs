#!/usr/bin/env node
// harness-init — 제작 과정 보고서 생성기
//
// 사용법: node report.mjs <기능> [--out <경로>]
// 재료:   docs/specs/<기능>.md          규칙 목록
//         .harness/journal/<기능>.jsonl  작업 일지 (journal.sh)
//         .git/harness/checks.jsonl     Stop 훅 자동 검사 기록 (verify.sh)
//         git log                       기간 안의 커밋
// 결과:   .harness/reports/<기능>.html  (캡처 이미지까지 담은 파일 하나)
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, extname, join, resolve } from 'node:path';

const args = process.argv.slice(2);
const feature = args.find((a) => !a.startsWith('--'));
const outIdx = args.indexOf('--out');
if (!feature) {
  console.error('사용법: node report.mjs <기능> [--out <경로>]');
  process.exit(1);
}

const root = resolve(process.env.CLAUDE_PROJECT_DIR || process.cwd());
const p = (...xs) => join(root, ...xs);
const read = (f) => (existsSync(f) ? readFileSync(f, 'utf8') : '');
const git = (...a) => {
  try {
    return execFileSync('git', a, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    return '';
  }
};

// ── 재료 읽기 ────────────────────────────────────────────
const conf = read(p('.claude', 'harness.conf'));
const specsDir = conf.match(/^SPECS_DIR=["']?([^"'\r\n]+)/m)?.[1] ?? 'docs/specs';
const specPath = p(specsDir, `${feature}.md`);
const specText = read(specPath).replace(/\r/g, '');
const title = specText.match(/^#\s+(.+)$/m)?.[1]?.trim() || feature;
const specRules = [];
for (const line of specText.split('\n')) {
  const m = line.match(/^\s*[-*]\s+(?:\*\*)?(R\d+)(?:\*\*)?[*:.)\s]*(.*)$/);
  if (m) specRules.push({ id: m[1], text: m[2].trim() });
}

const parseJsonl = (txt) =>
  txt
    .split('\n')
    .map((l) => {
      try {
        return l.trim() ? JSON.parse(l) : null;
      } catch {
        return null;
      }
    })
    .filter(Boolean);

const journal = parseJsonl(read(p('.harness', 'journal', `${feature}.jsonl`))).sort((a, b) => a.ts.localeCompare(b.ts));
if (!journal.length && !specRules.length) {
  console.error(`보고서 재료가 없다: ${specsDir}/${feature}.md 도 .harness/journal/${feature}.jsonl 도 없음`);
  process.exit(1);
}

const start = journal[0]?.ts;
const end = journal.at(-1)?.ts;
const inRange = (ts) => {
  if (!start) return false;
  const t = Date.parse(ts);
  return t >= Date.parse(start) - 60_000 && t <= Date.parse(end) + 10 * 60_000;
};

const stateDir = git('rev-parse', '--git-path', 'harness');
const checks = stateDir
  ? parseJsonl(read(resolve(root, stateDir, 'checks.jsonl'))).filter((c) => inRange(c.ts))
  : [];

const commits = start
  ? git('log', `--since=${new Date(Date.parse(start) - 60_000).toISOString()}`, '--format=%h%x1f%aI%x1f%s')
      .split('\n')
      .filter(Boolean)
      .map((l) => {
        const [hash, ts, subject] = l.split('\x1f');
        return { hash, ts: new Date(ts).toISOString(), subject, rules: subject.match(/R\d+/g) ?? [] };
      })
      .filter((c) => inRange(c.ts))
  : [];

// ── 규칙별 집계 ──────────────────────────────────────────
const ruleIds = [...new Set([...specRules.map((r) => r.id), ...journal.map((e) => e.rule).filter(Boolean)])].sort(
  (a, b) => Number(a.slice(1)) - Number(b.slice(1)),
);
const rules = ruleIds.map((id) => {
  const evs = journal.filter((e) => e.rule === id);
  const spec = specRules.find((r) => r.id === id);
  let state = 'todo';
  for (const e of evs) {
    if (e.event === 'red') state = 'red';
    if (e.event === 'green') state = 'green';
  }
  const verify = evs.filter((e) => e.event === 'verify').at(-1)?.detail;
  const killed = evs.filter((e) => e.event === 'mutant-killed').length;
  const survived = evs.filter((e) => e.event === 'mutant-survived').length;
  const lastMut = evs.filter((e) => e.event.startsWith('mutant-')).at(-1)?.event;
  return {
    id,
    text: spec?.text ?? '',
    inSpec: Boolean(spec),
    state,
    verify,
    killed,
    survived,
    mutationOk: lastMut === 'mutant-killed',
    tests: evs.filter((e) => e.event === 'test').map((e) => e.detail),
    journey: evs.filter((e) => !['verify', 'todo', 'note'].includes(e.event)).map((e) => e.event),
    commits: commits.filter((c) => c.rules.includes(id)).map((c) => c.hash),
    first: evs[0]?.ts,
    last: evs.at(-1)?.ts,
  };
});

const verdictEv = journal.filter((e) => e.event === 'verdict').at(-1);
const computedVerdict = rules.some((r) => r.state === 'red' || (r.survived && !r.mutationOk))
  ? '❌ 실패'
  : rules.some((r) => r.state !== 'green')
    ? '⚠️ 부분 통과'
    : '✅ 통과';
const verdict = verdictEv?.detail || computedVerdict;
const todos = journal.filter((e) => e.event === 'todo');
const shots = journal.filter((e) => e.event === 'shot');
const stats = {
  rules: rules.filter((r) => r.inSpec).length,
  // 망가뜨려도 통과한 규칙은 테스트가 부실하므로 통과로 세지 않는다
  green: rules.filter((r) => r.inSpec && r.state === 'green' && (r.killed + r.survived === 0 || r.mutationOk)).length,
  checksPass: checks.filter((c) => c.result === 'pass').length,
  checksFail: checks.filter((c) => c.result !== 'pass').length,
  killed: rules.reduce((s, r) => s + r.killed, 0),
  mutants: rules.reduce((s, r) => s + r.killed + r.survived, 0),
  commits: commits.length,
};

// ── HTML ────────────────────────────────────────────────
const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const fmt = (ts) =>
  ts
    ? new Date(ts).toLocaleString('ko-KR', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })
    : '';
const dur = (a, b) => {
  if (!a || !b) return '';
  const m = Math.round((Date.parse(b) - Date.parse(a)) / 60_000);
  return m < 60 ? `${m}분` : `${Math.floor(m / 60)}시간 ${m % 60}분`;
};
const MIME = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.webp': 'image/webp' };
const img = (path) => {
  const f = resolve(root, path);
  const mime = MIME[extname(f).toLowerCase()];
  if (!mime || !existsSync(f) || statSync(f).size > 3 * 1024 * 1024) return '';
  return `<img src="data:${mime};base64,${readFileSync(f).toString('base64')}" alt="${esc(path)}" loading="lazy">`;
};

const EV = {
  spec: ['📏', '규칙 문서'],
  test: ['🧪', '테스트 작성'],
  red: ['🔴', '실패 확인'],
  impl: ['🛠', '구현'],
  green: ['🟢', '통과'],
  'mutant-killed': ['🧨', '망가뜨려 보기 — 테스트가 잡음'],
  'mutant-survived': ['⚠️', '망가뜨려도 통과 — 테스트 부실'],
  fix: ['🔧', '수정'],
  shot: ['📸', '화면 캡처'],
  verify: ['🔍', '검사'],
  todo: ['☐', '사람이 확인할 것'],
  verdict: ['🧾', '판정'],
  note: ['💬', '메모'],
};
const BAD = new Set(['red', 'mutant-survived']);
const GOOD = new Set(['green', 'mutant-killed']);

const timeline = [
  ...journal.map((e) => ({ ...e, kind: 'journal' })),
  ...commits.map((c) => ({ ts: c.ts, kind: 'commit', ...c })),
  ...checks.map((c) => ({ ...c, kind: 'check' })),
].sort((a, b) => a.ts.localeCompare(b.ts));

const tlItem = (e) => {
  if (e.kind === 'commit')
    return `<li class="ev commit"><span class="ic">⎇</span><div><div class="meta">${fmt(e.ts)} · 커밋 <code>${esc(e.hash)}</code></div><div>${esc(e.subject)}</div></div></li>`;
  if (e.kind === 'check') {
    const label = e.result === 'pass' ? '자동 검사 통과' : e.result === 'timeout' ? '자동 검사 시간 초과' : `자동 검사 실패 (${esc(e.n)}/${esc(e.max)})`;
    return `<li class="ev check ${e.result === 'pass' ? 'good' : 'bad'}"><span class="ic">${e.result === 'pass' ? '✓' : '✗'}</span><div><div class="meta">${fmt(e.ts)} · Stop 훅</div><div>${label}</div></div></li>`;
  }
  const [ic, label] = EV[e.event] ?? ['•', e.event];
  const cls = BAD.has(e.event) ? 'bad' : GOOD.has(e.event) ? 'good' : '';
  const pic = e.event === 'shot' ? img(e.detail) : '';
  return `<li class="ev ${cls}"><span class="ic">${ic}</span><div><div class="meta">${fmt(e.ts)}${e.rule ? ` · <b>${esc(e.rule)}</b>` : ''} · ${label}</div>${e.detail ? `<div>${esc(e.detail)}</div>` : ''}${pic ? `<div class="shot">${pic}</div>` : ''}</div></li>`;
};

const stateCell = (r) => {
  if (r.verify) return esc(r.verify);
  if (r.state === 'green' && r.survived && !r.mutationOk) return '⚠️ 통과 (테스트 부실)';
  return { green: '✅ 통과', red: '❌ 실패 중', todo: '— 미착수' }[r.state];
};
const mutCell = (r) =>
  r.killed + r.survived === 0
    ? '<span class="dim">안 함</span>'
    : r.mutationOk
      ? `✅ 잡음 ${r.killed}`
      : `❌ 통과해버림 ${r.survived}`;

const verdictCls = verdict.includes('✅') ? 'good' : verdict.includes('❌') ? 'bad' : 'warn';

const html = `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)} 제작 과정</title>
<style>
:root { --bg:#fafaf9; --fg:#1c1917; --dim:#78716c; --card:#fff; --line:#e7e5e4; --good:#15803d; --bad:#b91c1c; --warn:#b45309; --accent:#4f46e5; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg:#0c0a09; --fg:#f5f5f4; --dim:#a8a29e; --card:#1c1917; --line:#292524; --good:#4ade80; --bad:#f87171; --warn:#fbbf24; --accent:#818cf8; } }
:root[data-theme="dark"] { --bg:#0c0a09; --fg:#f5f5f4; --dim:#a8a29e; --card:#1c1917; --line:#292524; --good:#4ade80; --bad:#f87171; --warn:#fbbf24; --accent:#818cf8; }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--fg); font:15px/1.6 system-ui,-apple-system,"Apple SD Gothic Neo","Malgun Gothic",sans-serif; }
main { max-width:960px; margin:0 auto; padding:32px 16px 64px; }
h1 { font-size:26px; margin:0 0 4px; } h2 { font-size:18px; margin:40px 0 12px; }
.sub { color:var(--dim); margin:0 0 20px; }
.verdict { display:inline-block; font-weight:700; padding:6px 14px; border-radius:999px; border:1px solid currentColor; }
.good { color:var(--good); } .bad { color:var(--bad); } .warn { color:var(--warn); } .dim { color:var(--dim); }
.stats { display:grid; grid-template-columns:repeat(auto-fit,minmax(140px,1fr)); gap:10px; margin-top:20px; }
.stat { background:var(--card); border:1px solid var(--line); border-radius:12px; padding:12px 14px; }
.stat b { display:block; font-size:22px; } .stat b em { font-style:normal; } .stat > span { color:var(--dim); font-size:13px; }
th { white-space:nowrap; } td:first-child { white-space:nowrap; } td:nth-child(2) { min-width:220px; } td:nth-child(6) { min-width:200px; }
.journey { white-space:nowrap; letter-spacing:1px; }
details > summary { cursor:pointer; color:var(--dim); margin-bottom:8px; }
.tablewrap { overflow-x:auto; border:1px solid var(--line); border-radius:12px; background:var(--card); }
table { border-collapse:collapse; width:100%; min-width:640px; }
th,td { text-align:left; padding:10px 12px; border-bottom:1px solid var(--line); vertical-align:top; font-size:14px; }
th { color:var(--dim); font-weight:600; } tr:last-child td { border-bottom:0; }
code { font:12.5px ui-monospace,Menlo,Consolas,monospace; background:var(--line); padding:1px 5px; border-radius:4px; }
ol.tl { list-style:none; margin:0; padding:0 0 0 8px; border-left:2px solid var(--line); }
.ev { display:flex; gap:12px; padding:8px 0 8px 14px; position:relative; }
.ev .ic { flex:0 0 22px; text-align:center; } .ev .meta { color:var(--dim); font-size:13px; }
.ev.bad .meta b, .ev.bad .ic { color:var(--bad); } .ev.good .ic { color:var(--good); }
.ev.check, .ev.commit { opacity:.8; font-size:14px; }
.shot img, .gallery img { max-width:100%; border:1px solid var(--line); border-radius:8px; margin-top:6px; }
.shot img { max-height:260px; }
.gallery { display:grid; grid-template-columns:repeat(auto-fill,minmax(260px,1fr)); gap:12px; }
.gallery figure { margin:0; } .gallery figcaption { color:var(--dim); font-size:13px; }
ul.todo { padding-left:20px; } footer { color:var(--dim); font-size:12px; margin-top:48px; }
button.theme { float:right; background:var(--card); color:var(--fg); border:1px solid var(--line); border-radius:8px; padding:4px 10px; cursor:pointer; }
</style>
</head>
<body>
<main>
<button class="theme" type="button" onclick="var r=document.documentElement,d=r.dataset.theme?r.dataset.theme==='dark':matchMedia('(prefers-color-scheme: dark)').matches;r.dataset.theme=d?'light':'dark'">◐</button>
<h1>${esc(title)} — 제작 과정</h1>
<p class="sub">${start ? `${fmt(start)} ~ ${fmt(end)} (${dur(start, end)})` : '일지 없음'} · 기준 문서 <code>${esc(`${specsDir}/${feature}.md`)}</code></p>
<span class="verdict ${verdictCls}">판정: ${esc(verdict)}</span>

<div class="stats">
  <div class="stat"><b>${stats.green}/${stats.rules}</b><span>규칙 통과</span></div>
  <div class="stat"><b>${stats.killed}/${stats.mutants}</b><span>망가뜨려 보기 잡음</span></div>
  <div class="stat"><b>${stats.checksPass} / <em class="${stats.checksFail ? 'bad' : ''}">${stats.checksFail}</em></b><span>자동 검사 통과 / 막힘</span></div>
  <div class="stat"><b>${stats.commits}</b><span>커밋</span></div>
</div>

<h2>규칙별 결과</h2>
<div class="tablewrap"><table>
<thead><tr><th>규칙</th><th>내용</th><th>과정</th><th>결과 · 확인 깊이</th><th>망가뜨려 보기</th><th>테스트</th><th>커밋</th></tr></thead>
<tbody>
${rules
  .map(
    (r) => `<tr><td><b>${esc(r.id)}</b></td><td>${r.inSpec ? esc(r.text) : '<span class="dim">(문서에 없음 — 삭제된 규칙)</span>'}</td><td class="journey" title="${esc(r.journey.map((ev) => EV[ev]?.[1] ?? ev).join(' → '))}">${r.journey.map((ev) => EV[ev]?.[0] ?? '•').join('') || '<span class="dim">—</span>'}</td><td>${stateCell(r)}</td><td>${mutCell(r)}</td><td>${r.tests.map((t) => `<div><code>${esc(t)}</code></div>`).join('') || '<span class="dim">—</span>'}</td><td>${r.commits.map((h) => `<code>${esc(h)}</code>`).join(' ') || '<span class="dim">—</span>'}</td></tr>`,
  )
  .join('\n')}
</tbody></table></div>

${todos.length ? `<h2>사람이 확인할 것</h2><ul class="todo">${todos.map((t) => `<li>☐ ${t.rule ? `<b>${esc(t.rule)}</b> ` : ''}${esc(t.detail)}</li>`).join('')}</ul>` : ''}

<h2>타임라인</h2>
${timeline.length ? `<details open><summary>기록 ${timeline.length}건 — 접기/펼치기</summary><ol class="tl">${timeline.map(tlItem).join('\n')}</ol></details>` : '<p class="dim">기록된 일지가 없다.</p>'}
<p class="dim" style="font-size:13px">과정 아이콘: 📏 문서 · 🧪 테스트 작성 · 🔴 실패 확인 · 🛠 구현 · 🟢 통과 · 🧨 망가뜨려 보기 잡음 · ⚠️ 망가뜨려도 통과 · 🔧 수정 · 📸 캡처</p>

${shots.length ? `<h2>캡처</h2><div class="gallery">${shots.map((s) => `<figure>${img(s.detail) || `<div class="dim">이미지 없음: <code>${esc(s.detail)}</code></div>`}<figcaption>${s.rule ? `${esc(s.rule)} · ` : ''}${esc(s.detail)}</figcaption></figure>`).join('')}</div>` : ''}

<footer>harness-init 제작 과정 보고서 · ${esc(new Date().toLocaleString('ko-KR'))} 생성</footer>
</main>
</body>
</html>
`;

const out = outIdx >= 0 ? resolve(args[outIdx + 1]) : p('.harness', 'reports', `${feature}.html`);
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, html);
console.log(out);
