#!/usr/bin/env node
// harness-init — 프로젝트를 훑어 check 명령·감시 경로를 추측하고 .claude/harness.conf 를 채운다.
//
// 사용법
//   node detect.mjs            진단 결과(JSON) 출력 — 아무것도 쓰지 않는다
//   node detect.mjs --conf     채워 넣은 harness.conf 내용을 출력
//   node detect.mjs --write    .claude/harness.conf 를 만든다 (이미 있으면 건드리지 않음)
//
// 추측일 뿐이다. 결과의 checkCmd 를 실제로 한 번 돌려 통과하는지 확인하는 건 호출한 쪽 몫.
import { existsSync, readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const here = dirname(fileURLToPath(import.meta.url));
const has = (p) => existsSync(join(root, p));
const read = (p) => {
  try {
    return readFileSync(join(root, p), 'utf8');
  } catch {
    return '';
  }
};
const firstDirs = (cands) => cands.filter((d) => has(d)).map((d) => d + '/');

function node() {
  let pkg = {};
  try {
    pkg = JSON.parse(read('package.json'));
  } catch {
    /* 깨진 package.json — 빈 것으로 */
  }
  const pm = has('pnpm-lock.yaml') || has('pnpm-workspace.yaml')
    ? 'pnpm'
    : has('yarn.lock')
      ? 'yarn'
      : has('bun.lockb') || has('bun.lock')
        ? 'bun'
        : 'npm';
  const run = (s) => (pm === 'npm' ? (s === 'test' ? 'npm test' : `npm run ${s}`) : `${pm} ${s}`);
  const scripts = pkg.scripts || {};
  const deps = { ...pkg.dependencies, ...pkg.devDependencies };
  const missing = [];
  let checkCmd;
  if (scripts.check) checkCmd = run('check');
  else {
    const parts = [];
    const typecheck = ['typecheck', 'type-check', 'tsc', 'types'].find((s) => scripts[s]);
    if (typecheck) parts.push(run(typecheck));
    else if (has('tsconfig.json')) parts.push(pm === 'npm' ? 'npx tsc --noEmit' : `${pm} exec tsc --noEmit`);
    else missing.push('typecheck');
    if (scripts.lint) parts.push(run('lint'));
    else missing.push('lint');
    const testDefault = /no test specified/.test(scripts.test || '');
    if (scripts.test && !testDefault) parts.push(run('test'));
    else missing.push('test');
    checkCmd = parts.join(' && ');
  }
  const ui = ['next', 'react', 'vue', 'svelte', '@sveltejs/kit', 'vite', '@angular/core', 'solid-js', 'nuxt', 'astro'].some((d) => d in deps) || has('index.html');
  const llm = Object.keys(deps).some((d) => /^(@anthropic-ai\/|openai$|@ai-sdk\/|ai$|langchain|@langchain\/)/.test(d));
  const e2e = '@playwright/test' in deps || ['playwright.config.ts', 'playwright.config.js', 'playwright.config.mjs'].some(has);
  const watch = firstDirs(['src', 'app', 'apps', 'packages', 'lib', 'pages', 'components', 'server', 'test', 'tests', '__tests__', 'e2e']);
  if (watch.length) watch.push('package.json'); // 소스 폴더가 없으면 비워 둔다 = 저장소 전체 감시
  return { stack: 'node', pm, checkCmd, watch, missing, ui, llm, e2e, hasCheckScript: !!scripts.check };
}

function python() {
  const txt = read('pyproject.toml') + read('requirements.txt') + read('requirements-dev.txt') + read('setup.cfg');
  const parts = [];
  const missing = [];
  if (/\bruff\b/.test(txt)) parts.push('ruff check .');
  else missing.push('lint');
  if (/\bmypy\b/.test(txt)) parts.push('mypy .');
  else if (/\bpyright\b/.test(txt)) parts.push('pyright');
  else missing.push('typecheck');
  if (/\bpytest\b/.test(txt) || has('tests') || has('test')) parts.push('pytest -q');
  else missing.push('test');
  const runner = has('uv.lock') ? 'uv run ' : has('poetry.lock') ? 'poetry run ' : '';
  const checkCmd = parts.map((p) => runner + p).join(' && ');
  const llm = /\b(anthropic|openai|langchain)\b/.test(txt);
  const ui = /\b(streamlit|gradio|django|flask|fastapi)\b/.test(txt);
  return { stack: 'python', pm: runner.trim().split(' ')[0] || 'pip', checkCmd, watch: ['*.py', 'pyproject.toml'], missing, ui, llm, e2e: false };
}

function detect() {
  const makeCheck = /^check:/m.test(read('Makefile'));
  let r;
  if (has('package.json')) r = node();
  else if (has('pyproject.toml') || has('requirements.txt') || has('setup.py')) r = python();
  else if (has('go.mod')) r = { stack: 'go', pm: 'go', checkCmd: 'go vet ./... && go test ./...', watch: ['*.go', 'go.mod'], missing: [], ui: false, llm: /anthropic|openai/.test(read('go.mod')), e2e: false };
  else if (has('Cargo.toml')) r = { stack: 'rust', pm: 'cargo', checkCmd: 'cargo clippy --all-targets -- -D warnings && cargo test', watch: ['src/', 'tests/', 'Cargo.toml'], missing: [], ui: false, llm: false, e2e: false };
  else if (has('build.gradle') || has('build.gradle.kts')) r = { stack: 'gradle', pm: 'gradle', checkCmd: `${has('gradlew') ? './gradlew' : 'gradle'} check`, watch: ['src/', 'build.gradle*'], missing: [], ui: false, llm: false, e2e: false };
  else if (has('pom.xml')) r = { stack: 'maven', pm: 'mvn', checkCmd: 'mvn -q verify', watch: ['src/', 'pom.xml'], missing: [], ui: false, llm: false, e2e: false };
  else r = { stack: 'unknown', pm: '', checkCmd: '', watch: [], missing: ['typecheck', 'lint', 'test'], ui: has('index.html'), llm: false, e2e: false };
  if (makeCheck) r.checkCmd = 'make check'; // 프로젝트가 이미 묶어 둔 명령이 있으면 그걸 쓴다
  r.ci = has('.github/workflows') && readdirSync(join(root, '.github/workflows')).length > 0;
  r.specs = has('docs/specs');
  r.conf = has('.claude/harness.conf');
  return r;
}

function confText(r) {
  const tpl = readFileSync(join(here, '..', 'templates', 'harness.conf'), 'utf8').replace(/\r/g, '');
  const q = (s) => s.replace(/(["\\$`])/g, '\\$1');
  return tpl
    .replace(/^CHECK_CMD=.*$/m, `CHECK_CMD="${q(r.checkCmd || 'echo "CHECK_CMD 를 채워 주세요" && exit 1')}"`)
    .replace(/^WATCH_PATHS=.*$/m, `WATCH_PATHS="${q(r.watch.join(' '))}"`);
}

const arg = process.argv[2] || '';
const r = detect();
if (arg === '--conf') process.stdout.write(confText(r));
else if (arg === '--write') {
  const p = join(root, '.claude', 'harness.conf');
  if (existsSync(p)) {
    console.log('= 이미 있음: .claude/harness.conf (그대로 둠)');
  } else {
    mkdirSync(dirname(p), { recursive: true });
    writeFileSync(p, confText(r));
    console.log(`✓ 만듦: .claude/harness.conf — CHECK_CMD="${r.checkCmd}" WATCH_PATHS="${r.watch.join(' ')}"`);
  }
  if (!r.checkCmd) console.log('! check 명령을 추측하지 못했다 — CHECK_CMD 를 직접 채워야 한다');
  if (r.missing.length) console.log(`! 없는 검사: ${r.missing.join(', ')}`);
} else if (arg === '' || arg === '--json') console.log(JSON.stringify(r, null, 2));
else {
  console.error('사용법: node detect.mjs [--json | --conf | --write]');
  process.exit(1);
}
