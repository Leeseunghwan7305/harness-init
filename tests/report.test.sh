#!/usr/bin/env bash
# scripts/journal.sh · scripts/report.mjs · verify.sh 검사 기록 테스트
# 실행: bash tests/report.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
J="$ROOT/scripts/journal.sh"
R="$ROOT/scripts/report.mjs"
V="$ROOT/scripts/verify.sh"
pass=0
fail=0

new_repo() {
  REPO="$(mktemp -d)"
  git -C "$REPO" init -q
  git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  mkdir -p "$REPO/.claude" "$REPO/docs/specs" "$REPO/src"
  printf 'CHECK_CMD="true"\nWATCH_PATHS="src/"\n' >"$REPO/.claude/harness.conf"
  printf '%s\n' "# 계산기" "" "- R1 숫자를 누르면 붙는다" "- R2 2 + 3 = 5" "- R3 0으로 나누면 안내 문구" >"$REPO/docs/specs/calc.md"
}

j() { CLAUDE_PROJECT_DIR="$REPO" bash "$J" "$@"; }
report() {
  OUT="$(CLAUDE_PROJECT_DIR="$REPO" node "$R" "$@" 2>&1)"
  RC=$?
  HTML="$(cat "$REPO/.harness/reports/${1}.html" 2>/dev/null)"
}
check() {
  if [ "$2" = "0" ]; then
    pass=$((pass + 1))
    echo "  ✓ $1"
  else
    fail=$((fail + 1))
    echo "  ✗ $1  (rc=$RC)"
    printf '%s\n' "$OUT" | head -5 | sed 's/^/    | /'
  fi
}
has() { grep -qF -- "$1" <<<"$HTML"; }

echo "journal.sh"
new_repo
j calc test R1 "tests/calc.test.ts: R1 숫자 이어붙이기"
check "기록 → jsonl 한 줄" "$( { [ "$(wc -l <"$REPO/.harness/journal/calc.jsonl")" -eq 1 ]; } && echo 0 || echo 1)"
j calc note - '따옴표 " 와 역슬래시 \ 와
줄바꿈'
check "특수문자도 유효한 JSON" "$( { node -e 'require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").forEach(l=>JSON.parse(l))' "$REPO/.harness/journal/calc.jsonl"; } && echo 0 || echo 1)"
OUT="$(j calc bogus R1 x 2>&1)"; RC=$?
check "모르는 이벤트는 거부" "$( { [ "$RC" = 1 ]; } && echo 0 || echo 1)"
OUT="$(j calc test 3 x 2>&1)"; RC=$?
check "잘못된 규칙 번호는 거부" "$( { [ "$RC" = 1 ]; } && echo 0 || echo 1)"
j sci/trig note - x
check "하위 경로 기능 이름" "$( { [ -f "$REPO/.harness/journal/sci/trig.jsonl" ]; } && echo 0 || echo 1)"

echo
echo "verify.sh 검사 기록"
new_repo
echo x >"$REPO/src/a.ts"
printf '{}' | CLAUDE_PROJECT_DIR="$REPO" bash "$V" 2>/dev/null
check "통과 기록" "$( { grep -q '"result":"pass"' "$REPO/.git/harness/checks.jsonl"; } && echo 0 || echo 1)"
printf 'CHECK_CMD="exit 1"\nWATCH_PATHS="src/"\n' >"$REPO/.claude/harness.conf"
echo y >"$REPO/src/a.ts"
printf '{}' | CLAUDE_PROJECT_DIR="$REPO" bash "$V" 2>/dev/null
check "실패 기록 (n=1)" "$( { grep -q '"result":"fail","n":1' "$REPO/.git/harness/checks.jsonl"; } && echo 0 || echo 1)"

# 일지·스냅샷 변경은 코드 변경이 아니다 (빈 WATCH_PATHS 에서도)
new_repo
printf 'CHECK_CMD="echo r >> %s.runs"\nWATCH_PATHS=""\n' "$REPO" >"$REPO/.claude/harness.conf"
git -C "$REPO" -c core.autocrlf=false add -A && git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m c
j calc note - x
mkdir -p "$REPO/.claude/harness-synced" && echo s >"$REPO/.claude/harness-synced/calc.md"
printf '{}' | CLAUDE_PROJECT_DIR="$REPO" bash "$V" 2>/dev/null
check "일지·스냅샷만 바뀌면 검사 안 돎" "$( { [ ! -s "$REPO.runs" ]; } && echo 0 || echo 1)"

echo
echo "report.mjs"
new_repo
report calc
check "일지 없어도 문서만으로 생성" "$( { [ "$RC" = 0 ] && has 'R1' && has '미착수'; } && echo 0 || echo 1)"

j calc spec - "규칙 3개 작성"
j calc test R1 "R1 숫자 이어붙이기"
j calc red R1 "expected '12' got ''"
j calc impl R1 "src/calc.ts append()"
j calc green R1
j calc mutant-killed R1 "append 를 빈 함수로 → 실패함"
j calc verify R1 "✅ 화면까지"
j calc test R2 "R2 덧셈"
j calc green R2
j calc mutant-survived R2 "+ 를 - 로 바꿔도 통과"
j calc test R3 "R3 <script>alert(1)</script>"
j calc red R3 "안내 문구 없음"
j calc todo R3 "실제 문구가 기획과 맞는지"
echo x >"$REPO/src/a.ts"
git -C "$REPO" -c core.autocrlf=false add -A && git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m "feat: R1 숫자 입력"
printf '{}' | CLAUDE_PROJECT_DIR="$REPO" bash "$V" 2>/dev/null
report calc
check "생성 성공 + 경로 출력" "$( { [ "$RC" = 0 ] && grep -q 'calc.html' <<<"$OUT" && [ -n "$HTML" ]; } && echo 0 || echo 1)"
check "제목은 문서 제목" "$( { has '<title>계산기 제작 과정</title>'; } && echo 0 || echo 1)"
check "R1: verifier 판정 표시" "$( { has '✅ 화면까지' && has '✅ 잡음 1'; } && echo 0 || echo 1)"
check "R2: 망가뜨려도 통과 → ❌ + 테스트 부실" "$( { has '❌ 통과해버림 1' && has '⚠️ 통과 (테스트 부실)'; } && echo 0 || echo 1)"
check "R3: 실패 중" "$( { has '❌ 실패 중'; } && echo 0 || echo 1)"
check "전체 판정은 가장 나쁜 결과 (❌)" "$( { has '판정: ❌ 실패'; } && echo 0 || echo 1)"
check "사람 확인 목록" "$( { has '실제 문구가 기획과 맞는지'; } && echo 0 || echo 1)"
check "규칙과 커밋 연결" "$( { grep -q "<code>$(git -C "$REPO" rev-parse --short HEAD)</code>" <<<"$HTML"; } && echo 0 || echo 1)"
check "자동 검사 기록 포함" "$( { has '자동 검사 통과'; } && echo 0 || echo 1)"
check "HTML 이스케이프 (script 주입 안 됨)" "$( { ! has '<script>alert(1)' && has '&lt;script&gt;alert(1)'; } && echo 0 || echo 1)"
check "통과 1/3 집계" "$( { has '<b>1/3</b><span>규칙 통과'; } && echo 0 || echo 1)"

j calc verdict - "⚠️ 부분 통과"
report calc
check "명시한 판정이 우선" "$( { has '판정: ⚠️ 부분 통과'; } && echo 0 || echo 1)"

# 캡처는 파일 안에 넣는다
printf '\x89PNG\r\n\x1a\n' >"$REPO/shot.png"
j calc shot R1 "shot.png"
j calc shot R2 "missing.png"
report calc
check "캡처 이미지 내장" "$( { has 'data:image/png;base64,'; } && echo 0 || echo 1)"
check "없는 이미지는 안내" "$( { has '이미지 없음'; } && echo 0 || echo 1)"

# 삭제된 규칙
j calc green R9
report calc
check "문서에 없는 규칙은 표시" "$( { has '문서에 없음'; } && echo 0 || echo 1)"

OUT="$(CLAUDE_PROJECT_DIR="$REPO" node "$R" nothing 2>&1)"; RC=$?
check "재료 없으면 실패" "$( { [ "$RC" = 1 ]; } && echo 0 || echo 1)"

report calc --out "$REPO/custom/out.html"
check "--out 경로" "$( { [ -f "$REPO/custom/out.html" ]; } && echo 0 || echo 1)"

echo
echo "결과: ${pass} 통과, ${fail} 실패"
[ "$fail" = 0 ]
