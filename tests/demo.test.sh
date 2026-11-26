#!/usr/bin/env bash
# 조건식을 작은따옴표 문자열로 넘겨 ok() 안에서 eval 한다 — 펼침이 늦게 일어나는 건 의도다.
# shellcheck disable=SC2016,SC2034,SC2015
# scripts/demo.mjs 조립 단계 테스트 — Playwright 없이 가짜 JSON 리포트로 검사한다.
# (실제 녹화는 로컬에서 Playwright 프로젝트로 확인)
# 실행: bash tests/demo.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/scripts/demo.mjs"
R="$ROOT/scripts/report.mjs"
pass=0
fail=0

check() {
  if [ "$2" = "0" ]; then
    pass=$((pass + 1))
    echo "  ✓ $1"
  else
    fail=$((fail + 1))
    echo "  ✗ $1  (rc=$RC)"
    printf '%s\n' "$OUT" | head -6 | sed 's/^/    | /'
  fi
}

new_repo() {
  REPO="$(mktemp -d)"
  git -C "$REPO" init -q
  mkdir -p "$REPO/.claude" "$REPO/docs/specs" "$REPO/raw"
  printf '%s\n' "# 계산기" "" "- R1 숫자 입력" "- R2 2 + 3 = 5" "- R10 </script><img src=x onerror=alert(1)>" >"$REPO/docs/specs/calc.md"
  printf 'webm-R2' >"$REPO/raw/v2.webm"
  printf 'webm-R10' >"$REPO/raw/v10.webm"
  # Playwright JSON 리포트 형태 (중첩 suite, 상대/절대 경로 섞어서)
  cat >"$REPO/raw/report.json" <<EOF
{ "suites": [ { "title": "calc.spec.ts", "file": "e2e/calc.spec.ts", "specs": [], "suites": [ { "title": "그룹", "specs": [
  { "title": "R10: 스크립트 주입 문구", "tests": [ { "results": [ { "status": "passed", "duration": 2000, "attachments": [ { "name": "video", "path": "$(cd "$REPO" && pwd -W 2>/dev/null || pwd)/raw/v10.webm" } ] } ] } ] },
  { "title": "R2: 2 + 3 = 5", "tests": [ { "results": [ { "status": "failed", "duration": 1500, "attachments": [ { "name": "video", "path": "v2.webm" } ] } ] } ] },
  { "title": "R1: 숫자 입력", "tests": [ { "results": [ { "status": "passed", "duration": 900, "attachments": [] } ] } ] },
  { "title": "규칙 번호 없는 테스트", "tests": [ { "results": [ { "status": "passed", "duration": 500, "attachments": [ { "name": "video", "path": "v2.webm" } ] } ] } ] }
] } ] } ] }
EOF
}

run() {
  OUT="$(CLAUDE_PROJECT_DIR="$REPO" node "$D" "$@" 2>&1)"
  RC=$?
}
ok() { if eval "$1"; then echo 0; else echo 1; fi; }
DEMO() { printf '%s' "$REPO/.harness/demo/calc"; }

echo "demo.mjs (조립)"
new_repo
run calc --json "$REPO/raw/report.json" --no-mp4
check "조립 성공" "$(ok '[ "$RC" = 0 ] && grep -q "장면 2개" <<<"$OUT"')"
check "규칙 번호순 영상 (R2 → R10), 번호 없는 테스트 제외" "$(ok '[ -f "$(DEMO)/clips/02-R2.webm" ] && [ -f "$(DEMO)/clips/03-R10.webm" ] && [ "$(ls "$(DEMO)/clips" | wc -l | tr -d " ")" = 2 ]')"
check "영상 내용 그대로 복사" "$(ok '[ "$(cat "$(DEMO)/clips/02-R2.webm")" = "webm-R2" ]')"
check "영상 없는 테스트는 목록으로 남김" "$(ok 'grep -q "R1: 숫자 입력" "$(DEMO)/manifest.json" && grep -q "영상 없음 1" <<<"$OUT"')"
check "자막: 실패는 ❌, 시간 누적" "$(ok 'grep -q "❌ R2 2 + 3 = 5" "$(DEMO)/demo.srt" && grep -q "00:00:01,500 --> 00:00:03,500" "$(DEMO)/demo.srt"')"
check "MP4 끔" "$(ok 'grep -q "\"mp4\": \"\"" "$(DEMO)/manifest.json" && [ ! -f "$(DEMO)/demo.mp4" ]')"
HTML="$(cat "$(DEMO)/index.html")"
check "재생 페이지: 통과 수" "$(ok 'grep -q "1/2 통과" <<<"$HTML"')"
check "재생 페이지: 목록 이스케이프" "$(ok '! grep -q "<img src=x" <<<"$HTML" && grep -q "&lt;img src=x" <<<"$HTML"')"
check "재생 페이지: 스크립트 안 </script> 차단" "$(ok '[ "$(grep -o "</script>" <<<"$HTML" | wc -l | tr -d " ")" = 1 ]')"
check "일지에 video 기록" "$(ok 'grep -q "\"event\":\"video\"" "$REPO/.harness/journal/calc.jsonl"')"

OUT="$(CLAUDE_PROJECT_DIR="$REPO" node "$R" calc 2>&1)"; RC=$?
REP="$(cat "$REPO/.harness/reports/calc.html")"
check "보고서에 데모 영상 섹션 + 상대 경로" "$(ok 'grep -q "데모 영상" <<<"$REP" && grep -q "../demo/calc/index.html" <<<"$REP" && grep -q "../demo/calc/clips/02-R2.webm" <<<"$REP"')"
check "보고서 타임라인에 데모 영상 기록" "$(ok 'grep -q "· 데모 영상</div>" <<<"$REP"')"

echo
echo "demo.mjs (실패 경우)"
new_repo
printf '{ "suites": [ { "specs": [ { "title": "그냥 테스트", "tests": [ { "results": [ { "status": "passed" } ] } ] } ] } ] }' >"$REPO/raw/empty.json"
run calc --json "$REPO/raw/empty.json" --no-mp4
check "규칙 테스트 없으면 실패 + 안내" "$(ok '[ "$RC" = 1 ] && grep -q "규칙 번호" <<<"$OUT"')"
run calc --no-mp4
check "Playwright 설정 없으면 실패 + 안내" "$(ok '[ "$RC" = 1 ] && grep -q "playwright.config" <<<"$OUT"')"
run
check "기능 이름 없으면 사용법" "$(ok '[ "$RC" = 1 ] && grep -q "사용법" <<<"$OUT"')"

echo
echo "결과: ${pass} 통과, ${fail} 실패"
[ "$fail" = 0 ]
