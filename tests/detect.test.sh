#!/usr/bin/env bash
# 조건식을 작은따옴표 문자열로 넘겨 ok() 안에서 eval 한다 — 펼침이 늦게 일어나는 건 의도다.
# shellcheck disable=SC2016
# scripts/detect.mjs 테스트 — 프로젝트 종류별로 check 명령·감시 경로 추측
# 실행: bash tests/detect.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/scripts/detect.mjs"
pass=0
fail=0

check() {
  if [ "$2" = "0" ]; then
    pass=$((pass + 1))
    echo "  ✓ $1"
  else
    fail=$((fail + 1))
    echo "  ✗ $1  (rc=$RC)"
    printf '%s\n' "$OUT" | head -12 | sed 's/^/    | /'
  fi
}
ok() { if eval "$1"; then echo 0; else echo 1; fi; }
new_repo() { REPO="$(mktemp -d)"; }
run() { OUT="$(CLAUDE_PROJECT_DIR="$REPO" node "$D" "$@" 2>&1)"; RC=$?; }
field() { node -e 'const r=JSON.parse(require("fs").readFileSync(0,"utf8"));const v=r[process.argv[1]];console.log(Array.isArray(v)?v.join(" "):String(v))' "$1" <<<"$OUT"; }

echo "detect.mjs"

new_repo
printf '{"scripts":{"check":"tsc && eslint . && vitest run","test":"vitest"},"devDependencies":{"react":"18","@playwright/test":"1"}}' >"$REPO/package.json"
touch "$REPO/pnpm-lock.yaml"
mkdir -p "$REPO/src" "$REPO/e2e"
run
check "check 스크립트가 있으면 그대로 (pnpm)" "$(ok '[ "$(field checkCmd)" = "pnpm check" ]')"
check "있는 소스 폴더만 감시 + package.json" "$(ok '[ "$(field watch)" = "src/ e2e/ package.json" ]')"
check "화면 · E2E 감지" "$(ok '[ "$(field ui)" = true ] && [ "$(field e2e)" = true ] && [ "$(field llm)" = false ]')"

new_repo
printf '{"scripts":{"typecheck":"tsc","lint":"eslint .","test":"echo \\"Error: no test specified\\" && exit 1"},"dependencies":{"@anthropic-ai/sdk":"1"}}' >"$REPO/package.json"
run
check "check 없으면 있는 것만 묶음 (npm, 기본 test 스크립트는 무시)" "$(ok '[ "$(field checkCmd)" = "npm run typecheck && npm run lint" ] && [ "$(field missing)" = test ]')"
check "LLM 의존성 감지" "$(ok '[ "$(field llm)" = true ]')"
check "소스 폴더 없으면 감시 경로 비움 (= 전체)" "$(ok '[ -z "$(field watch)" ]')"

new_repo
printf '[tool.ruff]\n[tool.pytest.ini_options]\n' >"$REPO/pyproject.toml"
touch "$REPO/uv.lock"
run
check "Python: uv run ruff + pytest, mypy 없음 표시" "$(ok '[ "$(field checkCmd)" = "uv run ruff check . && uv run pytest -q" ] && [ "$(field missing)" = typecheck ]')"

new_repo
printf 'module x\n' >"$REPO/go.mod"
printf 'check:\n\tgo test ./...\n' >"$REPO/Makefile"
run
check "Go + Makefile check → make check 우선" "$(ok '[ "$(field stack)" = go ] && [ "$(field checkCmd)" = "make check" ]')"

new_repo
run
check "모르는 프로젝트 → 빈 명령" "$(ok '[ "$(field stack)" = unknown ] && [ -z "$(field checkCmd)" ]')"
run --write
check "모르면 conf 에 실패하는 자리표시 + 안내" "$(ok 'grep -q "채워 주세요" "$REPO/.claude/harness.conf" && grep -q "추측하지 못했다" <<<"$OUT"')"

new_repo
printf '{"scripts":{"check":"node -e \\"1\\""}}' >"$REPO/package.json"
mkdir -p "$REPO/lib"
run --write
check "--write: conf 생성, 값 채움, 나머지 템플릿 유지" "$(ok 'grep -qx "CHECK_CMD=\"npm run check\"" "$REPO/.claude/harness.conf" && grep -qx "WATCH_PATHS=\"lib/ package.json\"" "$REPO/.claude/harness.conf" && grep -qx "MAX_RETRIES=3" "$REPO/.claude/harness.conf"')"
check "생성된 conf 를 셸이 그대로 읽음" "$(ok '( . "$REPO/.claude/harness.conf" && [ "$CHECK_CMD" = "npm run check" ] )')"
printf 'CHECK_CMD="mine"\n' >"$REPO/.claude/harness.conf"
run --write
check "--write: 이미 있으면 덮어쓰지 않음" "$(ok '[ "$(cat "$REPO/.claude/harness.conf")" = "CHECK_CMD=\"mine\"" ] && grep -q "그대로 둠" <<<"$OUT"')"

run --bogus
check "모르는 옵션 → 사용법 + 실패" "$(ok '[ "$RC" = 1 ] && grep -q "사용법" <<<"$OUT"')"

echo
echo "결과: ${pass} 통과, ${fail} 실패"
[ "$fail" = 0 ]
