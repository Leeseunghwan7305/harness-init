#!/usr/bin/env node
// harness-init — 데모 영상: 규칙 번호가 붙은 E2E 테스트를 녹화해 규칙별 영상 + 재생 페이지(+ MP4)를 만든다.
//
// 사용법
//   node demo.mjs <기능> [--slowmo 500] [--no-mp4] [-- <playwright test 인자...>]
//   node demo.mjs <기능> --json <playwright-json-report>    녹화 없이 기존 결과로 조립만
//
// 결과: .harness/demo/<기능>/
//   index.html     자막과 함께 규칙 순서대로 이어 재생하는 페이지
//   clips/*.webm   규칙별 영상
//   demo.mp4       (ffmpeg 가 있으면) 한 편으로 합친 영상 + 자막 트랙
//   manifest.json  보고서가 읽는 목록
import { execFileSync, spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';

const argv = process.argv.slice(2);
const dd = argv.indexOf('--');
const own = dd >= 0 ? argv.slice(0, dd) : argv;
const passthrough = dd >= 0 ? argv.slice(dd + 1) : [];
const feature = own.find((a, i) => !a.startsWith('--') && !['--json', '--slowmo'].includes(own[i - 1]));
const opt = (k) => (own.includes(k) ? own[own.indexOf(k) + 1] : undefined);
const jsonArg = opt('--json');
const slowmo = Number(opt('--slowmo') ?? 500);
const wantMp4 = !own.includes('--no-mp4');
if (!feature) {
  console.error('사용법: node demo.mjs <기능> [--slowmo 500] [--no-mp4] [--json <report.json>] [-- <playwright 인자>]');
  process.exit(1);
}

const root = resolve(process.env.CLAUDE_PROJECT_DIR || process.cwd());
const outDir = join(root, '.harness', 'demo', feature);
const posix = (p) => p.split(sep).join('/');
const has = (cmd, args = ['-version']) => {
  try {
    execFileSync(cmd, args, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
};

// ── 규칙 문서 ────────────────────────────────────────────
const read = (f) => (existsSync(f) ? readFileSync(f, 'utf8') : '');
const conf = read(join(root, '.claude', 'harness.conf'));
const specsDir = conf.match(/^SPECS_DIR=["']?([^"'\r\n]+)/m)?.[1] ?? 'docs/specs';
const specText = read(join(root, specsDir, `${feature}.md`)).replace(/\r/g, '');
const title = specText.match(/^#\s+(.+)$/m)?.[1]?.trim() || feature;
const ruleText = {};
for (const line of specText.split('\n')) {
  const m = line.match(/^\s*[-*]\s+(?:\*\*)?(R\d+)(?:\*\*)?[*:.)\s]*(.*)$/);
  if (m) ruleText[m[1]] = m[2].trim();
}

// ── 1. 녹화 ──────────────────────────────────────────────
let reportJson = jsonArg ? resolve(jsonArg) : '';
let runExit = 0;
if (!reportJson) {
  const base = ['ts', 'mts', 'js', 'mjs', 'cjs'].map((e) => join(root, `playwright.config.${e}`)).find(existsSync);
  if (!base) {
    console.error('Playwright 설정(playwright.config.*)이 없다 — 화면 있는 앱에서 E2E 테스트를 먼저 만들어야 한다 (/harness-init:rule-tests).');
    process.exit(1);
  }
  const raw = join(outDir, 'raw');
  rmSync(raw, { recursive: true, force: true });
  mkdirSync(raw, { recursive: true });
  reportJson = join(raw, 'report.json');
  const wrapper = join(outDir, 'playwright.demo.config.ts');
  let rel = posix(relative(outDir, base)).replace(/\.(ts|mts|js|mjs|cjs)$/, '');
  if (!rel.startsWith('.')) rel = `./${rel}`;
  writeFileSync(
    wrapper,
    `// harness-init demo — 자동 생성. 프로젝트 설정 위에 녹화 옵션만 덮어쓴다.
import { resolve } from 'node:path';
import baseConfig from '${rel}';
const root = ${JSON.stringify(root)};
const b: any = (baseConfig as any)?.default ?? baseConfig;
const withCwd = (w: any) => ({ cwd: root, ...w });
export default {
  ...b,
  testDir: resolve(root, b.testDir ?? '.'),
  outputDir: ${JSON.stringify(raw)},
  workers: 1,
  retries: 0,
  fullyParallel: false,
  reporter: [['json', { outputFile: ${JSON.stringify(reportJson)} }], ['line']],
  projects: b.projects?.length ? [b.projects[0]] : undefined,
  webServer: Array.isArray(b.webServer) ? b.webServer.map(withCwd) : b.webServer ? withCwd(b.webServer) : undefined,
  use: {
    ...b.use,
    viewport: b.use?.viewport ?? { width: 1280, height: 720 },
    video: { mode: 'on', size: b.use?.viewport ?? { width: 1280, height: 720 } },
    launchOptions: { ...(b.use?.launchOptions ?? {}), slowMo: ${slowmo} },
  },
};
`,
  );
  console.log(`▶ 녹화: playwright test (규칙 번호가 붙은 테스트, slowMo ${slowmo}ms)`);
  const pwArgs = ['test', '--config', wrapper, '--grep', 'R\\d+', ...passthrough];
  // 프로젝트에 설치된 Playwright CLI 를 node 로 직접 실행한다 (셸·npx 불필요, Windows 안전)
  const cli = ['@playwright/test/cli.js', 'playwright/cli.js'].map((m) => join(root, 'node_modules', m)).find(existsSync);
  const r = cli
    ? spawnSync(process.execPath, [cli, ...pwArgs], { cwd: root, stdio: 'inherit' })
    : process.platform === 'win32'
      ? spawnSync(`npx playwright ${pwArgs.map((a) => `"${a.replace(/"/g, '\\"')}"`).join(' ')}`, { cwd: root, stdio: 'inherit', shell: true })
      : spawnSync('npx', ['playwright', ...pwArgs], { cwd: root, stdio: 'inherit' });
  runExit = r.status ?? 1;
  if (!existsSync(reportJson)) {
    console.error('녹화 결과(report.json)가 없다 — 위 Playwright 출력을 확인하라.');
    process.exit(1);
  }
}

// ── 2. 결과에서 규칙별 영상 찾기 ─────────────────────────
const report = JSON.parse(readFileSync(reportJson, 'utf8'));
const found = [];
const walk = (suite, file) => {
  for (const s of suite.suites ?? []) walk(s, s.file ?? file);
  for (const spec of suite.specs ?? []) {
    const rule = spec.title.match(/\bR\d+\b/)?.[0];
    if (!rule) continue;
    for (const t of spec.tests ?? []) {
      const res = t.results?.at(-1);
      const video = res?.attachments?.find((a) => a.name === 'video' && a.path)?.path;
      found.push({
        rule,
        title: spec.title,
        file: spec.file ?? file,
        status: res?.status ?? 'unknown',
        duration: (res?.duration ?? 0) / 1000,
        video: video ? resolve(dirname(reportJson), video) : '',
      });
    }
  }
};
for (const s of report.suites ?? []) walk(s, s.file);
found.sort((a, b) => Number(a.rule.slice(1)) - Number(b.rule.slice(1)) || a.title.localeCompare(b.title));

const clipsDir = join(outDir, 'clips');
rmSync(clipsDir, { recursive: true, force: true });
mkdirSync(clipsDir, { recursive: true });
const clips = [];
const missing = [];
found.forEach((c, i) => {
  if (!c.video || !existsSync(c.video)) {
    missing.push(c);
    return;
  }
  const name = `${String(i + 1).padStart(2, '0')}-${c.rule}.webm`;
  copyFileSync(c.video, join(clipsDir, name));
  let duration = c.duration;
  if (has('ffprobe')) {
    try {
      duration = Number(
        execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', join(clipsDir, name)], {
          encoding: 'utf8',
        }).trim(),
      ) || duration;
    } catch {
      /* 길이를 못 읽으면 테스트 시간으로 대신한다 */
    }
  }
  clips.push({ ...c, src: `clips/${name}`, duration, text: ruleText[c.rule] ?? '' });
});

if (!clips.length) {
  console.error(
    found.length
      ? `규칙 테스트 ${found.length}개를 찾았지만 영상이 없다 — video 설정이 프로젝트별로 꺼져 있는지 확인하라.`
      : '테스트 이름에 규칙 번호(R1, R2 …)가 붙은 E2E 테스트가 없다.',
  );
  process.exit(1);
}

// ── 3. 자막 (SRT) ────────────────────────────────────────
const srtTime = (s) => {
  const ms = Math.max(0, Math.round(s * 1000));
  const p = (n, w = 2) => String(n).padStart(w, '0');
  return `${p(Math.floor(ms / 3_600_000))}:${p(Math.floor(ms / 60_000) % 60)}:${p(Math.floor(ms / 1000) % 60)},${p(ms % 1000, 3)}`;
};
const mark = (st) => (st === 'passed' ? '✅' : st === 'skipped' ? '⏭' : '❌');
// MP4 는 장면마다 마지막 화면을 HOLD_SEC 동안 붙잡아 둔다 (재생 페이지의 1.2초 유지와 같게). 자막도 그 길이에 맞춘다.
const HOLD_SEC = 1.2;
let t = 0;
const srt = clips
  .map((c, i) => {
    const end = t + c.duration + HOLD_SEC;
    const line = `${i + 1}\n${srtTime(t)} --> ${srtTime(end)}\n${mark(c.status)} ${c.rule} ${c.text || c.title}\n`;
    t = end;
    return line;
  })
  .join('\n');
writeFileSync(join(outDir, 'demo.srt'), srt);

// ── 4. MP4 (선택) ────────────────────────────────────────
let mp4 = '';
if (wantMp4 && has('ffmpeg')) {
  // 장면마다 마지막 프레임을 HOLD_SEC 동안 복제(tpad)한 뒤 이어 붙인다 — 동작 없이 확인만 하는 규칙도 결과 화면이 보이게.
  const n = clips.length;
  const chains = clips.map((_, i) => `[${i}:v]scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=25,setsar=1,tpad=stop_mode=clone:stop_duration=${HOLD_SEC}[v${i}]`);
  const filter = `${chains.join(';')};${clips.map((_, i) => `[v${i}]`).join('')}concat=n=${n}:v=1:a=0[out]`;
  try {
    execFileSync(
      'ffmpeg',
      ['-y', '-loglevel', 'error', ...clips.flatMap((c) => ['-i', join(outDir, c.src)]), '-i', join(outDir, 'demo.srt'),
        '-filter_complex', filter, '-map', '[out]', '-map', String(n), '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
        '-c:s', 'mov_text', '-metadata:s:s:0', 'language=kor',
        join(outDir, 'demo.mp4')],
      { stdio: 'inherit' },
    );
    mp4 = 'demo.mp4';
  } catch {
    console.error('MP4 합치기 실패 — 규칙별 영상과 재생 페이지는 그대로 쓸 수 있다.');
  }
}

// ── 5. 재생 페이지 + manifest ────────────────────────────
const manifest = { feature, title, createdAt: new Date().toISOString(), runExit, mp4, clips: clips.map(({ video, ...c }) => c), missing: missing.map((m) => m.title) };
writeFileSync(join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 2));

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const passed = clips.filter((c) => c.status === 'passed').length;
const html = `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)} 데모</title>
<style>
:root { --bg:#fafaf9; --fg:#1c1917; --dim:#78716c; --card:#fff; --line:#e7e5e4; --good:#15803d; --bad:#b91c1c; --accent:#4f46e5; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg:#0c0a09; --fg:#f5f5f4; --dim:#a8a29e; --card:#1c1917; --line:#292524; --good:#4ade80; --bad:#f87171; --accent:#818cf8; } }
:root[data-theme="dark"] { --bg:#0c0a09; --fg:#f5f5f4; --dim:#a8a29e; --card:#1c1917; --line:#292524; --good:#4ade80; --bad:#f87171; --accent:#818cf8; }
* { box-sizing:border-box; }
body { margin:0; background:var(--bg); color:var(--fg); font:15px/1.6 system-ui,-apple-system,"Apple SD Gothic Neo","Malgun Gothic",sans-serif; }
main { max-width:1100px; margin:0 auto; padding:24px 16px 48px; }
h1 { font-size:24px; margin:0; } .sub { color:var(--dim); margin:4px 0 16px; }
.layout { display:grid; grid-template-columns:minmax(0,1fr) 300px; gap:16px; }
@media (max-width: 820px) { .layout { grid-template-columns:1fr; } }
.stage { position:relative; background:#000; border-radius:12px; overflow:hidden; aspect-ratio:16/9; }
.stage video { width:100%; height:100%; display:block; object-fit:contain; }
.cap { margin-top:8px; background:var(--card); border:1px solid var(--line); border-radius:10px; padding:10px 14px; font-size:16px; min-height:46px; }
.cap b { margin-right:6px; }
.ctrl { display:flex; flex-wrap:wrap; gap:8px; align-items:center; margin-top:10px; }
button, select { background:var(--card); color:var(--fg); border:1px solid var(--line); border-radius:8px; padding:6px 12px; font:inherit; cursor:pointer; }
button.primary { background:var(--accent); border-color:var(--accent); color:#fff; }
ol.list { list-style:none; margin:0; padding:0; border:1px solid var(--line); border-radius:12px; background:var(--card); overflow:hidden; }
ol.list li { padding:10px 12px; border-bottom:1px solid var(--line); cursor:pointer; }
ol.list li:last-child { border-bottom:0; }
ol.list li.on { background:color-mix(in srgb, var(--accent) 14%, transparent); }
ol.list .meta { color:var(--dim); font-size:12.5px; }
.good { color:var(--good); } .bad { color:var(--bad); }
.note { color:var(--dim); font-size:13px; margin-top:16px; }
</style>
</head>
<body>
<main>
<h1>${esc(title)} — 데모</h1>
<p class="sub">규칙 ${clips.length}개 장면 · <span class="${passed === clips.length ? 'good' : 'bad'}">${passed}/${clips.length} 통과</span>${mp4 ? ` · <a href="${mp4}" download>MP4 내려받기</a>` : ''}</p>
<div class="layout">
  <div>
    <div class="stage"><video id="v" playsinline muted controls></video></div>
    <div class="cap" id="cap" aria-live="polite"></div>
    <div class="ctrl">
      <button class="primary" id="all" type="button">▶ 처음부터 전체 재생</button>
      <button id="prev" type="button">◀ 이전</button><button id="next" type="button">다음 ▶</button>
      <label>속도 <select id="rate"><option>0.5</option><option selected>1</option><option>1.5</option><option>2</option></select></label>
    </div>
  </div>
  <ol class="list" id="list">
${clips
  .map(
    (c, i) =>
      `    <li data-i="${i}"><div><b>${esc(c.rule)}</b> <span class="${c.status === 'passed' ? 'good' : 'bad'}">${mark(c.status)}</span> ${esc(c.text || c.title)}</div><div class="meta">${esc(c.title)} · ${c.duration.toFixed(1)}초</div></li>`,
  )
  .join('\n')}
  </ol>
</div>
${missing.length ? `<p class="note">영상이 없는 테스트: ${missing.map((m) => esc(m.title)).join(', ')}</p>` : ''}
<p class="note">E2E 테스트를 녹화한 것이다 (동작을 ${slowmo}ms씩 느리게). 영상은 "규칙대로 동작한다"는 증거이고, 좋은 화면인지는 사람이 본다.</p>
</main>
<script>
var clips = ${JSON.stringify(clips.map((c) => ({ src: c.src, rule: c.rule, text: c.text || c.title, ok: c.status === 'passed' }))).replace(/</g, '\\u003c')};
var v = document.getElementById('v'), cap = document.getElementById('cap'), items = document.querySelectorAll('#list li'), cur = 0, auto = false;
function show(i, play) {
  cur = (i + clips.length) % clips.length;
  var c = clips[cur];
  v.src = c.src; v.playbackRate = Number(document.getElementById('rate').value);
  cap.innerHTML = '';
  var b = document.createElement('b'); b.textContent = c.rule + ' ' + (c.ok ? '\\u2705' : '\\u274c');
  cap.appendChild(b); cap.appendChild(document.createTextNode(' ' + c.text));
  items.forEach(function (li, k) { li.classList.toggle('on', k === cur); });
  if (play) v.play().catch(function () {});
}
// 테스트는 결과가 나오자마자 끝나므로, 마지막 화면(결과)을 잠깐 보여준 뒤 다음 장면으로 넘어간다
var HOLD_MS = 1200, holdTimer = null;
v.addEventListener('ended', function () {
  if (!(auto && cur < clips.length - 1)) { auto = false; return; }
  holdTimer = setTimeout(function () { if (auto) show(cur + 1, true); }, HOLD_MS);
});
v.addEventListener('play', function () { clearTimeout(holdTimer); });
v.addEventListener('ratechange', function () { document.getElementById('rate').value = String(v.playbackRate); });
items.forEach(function (li) { li.addEventListener('click', function () { auto = false; show(Number(li.dataset.i), true); }); });
document.getElementById('all').onclick = function () { auto = true; show(0, true); };
document.getElementById('prev').onclick = function () { auto = false; show(cur - 1, true); };
document.getElementById('next').onclick = function () { auto = false; show(cur + 1, true); };
document.getElementById('rate').onchange = function (e) { v.playbackRate = Number(e.target.value); };
show(0, false);
</script>
</body>
</html>
`;
writeFileSync(join(outDir, 'index.html'), html);

// ── 6. 일지 기록 ─────────────────────────────────────────
const jfile = join(root, '.harness', 'journal', `${feature}.jsonl`);
mkdirSync(dirname(jfile), { recursive: true });
const ts = new Date().toISOString().replace(/\.\d+Z$/, 'Z');
writeFileSync(jfile, `${JSON.stringify({ ts, event: 'video', rule: '', detail: posix(relative(root, join(outDir, 'index.html'))), commit: '' })}\n`, { flag: 'a' });

console.log(`✓ 데모: 장면 ${clips.length}개 (${passed} 통과)${missing.length ? `, 영상 없음 ${missing.length}` : ''}${mp4 ? ', MP4 생성' : wantMp4 ? ', MP4 건너뜀 (ffmpeg 없음)' : ''}`);
console.log(join(outDir, 'index.html'));
if (mp4) console.log(join(outDir, mp4));
