#!/usr/bin/env bash
# scripts/spec-status.sh · scripts/spec-reminder.sh 테스트
# 실행: bash tests/spec-sync.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATUS="$ROOT/scripts/spec-status.sh"
REMIND="$ROOT/scripts/spec-reminder.sh"
pass=0
fail=0

new_repo() {
  REPO="$(mktemp -d)"
  git -C "$REPO" init -q
  mkdir -p "$REPO/.claude" "$REPO/docs/specs"
  printf 'CHECK_CMD="true"\n' >"$REPO/.claude/harness.conf"
}

spec() { # spec <이름> <줄...>
  local name="$1"
  shift
  printf '%s\n' "# $name" "" "$@" >"$REPO/docs/specs/$name.md"
}

st() { OUT="$(CLAUDE_PROJECT_DIR="$REPO" bash "$STATUS" "$@" 2>&1)"; RC=$?; }
rm_() { OUT="$(printf '{}' | CLAUDE_PROJECT_DIR="$REPO" bash "$REMIND" 2>&1)"; RC=$?; }

check() {
  if [ "$2" = "0" ]; then
    pass=$((pass + 1))
    echo "  ✓ $1"
  else
    fail=$((fail + 1))
    echo "  ✗ $1  (rc=$RC)"
    printf '%s\n' "$OUT" | sed 's/^/    | /'
  fi
}
has() { grep -qF -- "$1" <<<"$OUT"; }

echo "spec-status.sh"

new_repo
st
check "문서 없으면 출력 없음" "$( { [ -z "$OUT" ]; } && echo 0 || echo 1)"

spec calc "- R1 숫자를 누르면 화면에 붙는다" "- R2 2 + 3 = 5" "- R10 % 는 100으로 나눈다"
st
check "새 문서 → 전부 추가로 표시" "$( { has '새 문서' && has '+ R1 [추가]' && has '+ R2 [추가]' && has '+ R10 [추가]' && ! has '[삭제]'; } && echo 0 || echo 1)"
check "번호순 정렬 (R2 가 R10 보다 먼저)" "$( { [ "$(grep -n 'R2' <<<"$OUT" | cut -d: -f1)" -lt "$(grep -n 'R10' <<<"$OUT" | cut -d: -f1)" ]; } && echo 0 || echo 1)"

st --brief
check "요약 형식" "$( { [ "$OUT" = "calc: +R1 +R2 +R10" ]; } && echo 0 || echo 1)"

st --mark calc
check "반영 완료 표시 → 스냅샷 생성" "$( { [ -f "$REPO/.claude/harness-synced/calc.md" ]; } && echo 0 || echo 1)"
st
check "표시 후엔 변경 없음" "$( { [ -z "$OUT" ]; } && echo 0 || echo 1)"

spec calc "- R1 숫자를 누르면 화면에 붙는다" "- R2 2 + 3 = 5 이다" "- R11 C 는 초기화한다"
st --brief
check "추가·수정·삭제 감지" "$( { [ "$OUT" = "calc: ~R2 -R10 +R11" ]; } && echo 0 || echo 1)"

# 규칙 아닌 줄·공백·CRLF 차이는 무시
st --mark calc
printf '# calc\r\n\r\n설명 문단 추가\r\n-   R1   숫자를 누르면 화면에 붙는다  \r\n- R2 2 + 3 = 5 이다\r\n- R11 C 는 초기화한다\r\n' >"$REPO/docs/specs/calc.md"
st
check "설명·공백·CRLF 차이는 무시" "$( { [ -z "$OUT" ]; } && echo 0 || echo 1)"

# 굵게·콜론 표기도 규칙으로 인식
spec calc "- **R1**: 숫자를 누르면 화면에 붙는다" "- R2 2 + 3 = 5 이다" "- R11 C 는 초기화한다"
st
check "'- **R1**:' 표기도 같은 규칙" "$( { [ -z "$OUT" ]; } && echo 0 || echo 1)"

# 여러 문서 + 하위 폴더 + 이름 지정
mkdir -p "$REPO/docs/specs/sci"
printf '%s\n' "- R1 sin 계산" >"$REPO/docs/specs/sci/trig.md"
st --brief
check "하위 폴더 문서도 감지" "$( { [ "$OUT" = "sci/trig: +R1" ]; } && echo 0 || echo 1)"
st --brief calc
check "이름 지정 시 그 문서만" "$( { [ -z "$OUT" ]; } && echo 0 || echo 1)"

# 문서 삭제
rm "$REPO/docs/specs/calc.md"
st --brief
check "문서 삭제 감지" "$( { has 'calc: 문서 삭제됨'; } && echo 0 || echo 1)"

st --mark nope
check "없는 문서 표시 → 실패" "$( { [ "$RC" = 1 ]; } && echo 0 || echo 1)"

# 기준선 잡기
new_repo
spec a "- R1 a"
spec b "- R1 b"
st --mark-all
st
check "--mark-all 후 변경 없음" "$( { [ -z "$OUT" ]; } && echo 0 || echo 1)"

# 설정에서 경로 변경
new_repo
mkdir -p "$REPO/specs"
printf 'SPECS_DIR="specs"\n' >>"$REPO/.claude/harness.conf"
printf '%s\n' "- R1 x" >"$REPO/specs/x.md"
st --brief
check "SPECS_DIR 설정 반영" "$( { [ "$OUT" = "x: +R1" ]; } && echo 0 || echo 1)"

echo
echo "spec-reminder.sh"

new_repo
rm "$REPO/.claude/harness.conf"
spec calc "- R1 x"
rm_
check "설정 없으면 조용함" "$( { [ "$RC" = 0 ] && [ -z "$OUT" ]; } && echo 0 || echo 1)"

new_repo
rm_
check "변경 없으면 조용함" "$( { [ "$RC" = 0 ] && [ -z "$OUT" ]; } && echo 0 || echo 1)"

spec calc "- R1 x" "- R2 y"
rm_
check "변경 있으면 알림 + sync 제안" "$( { has 'calc: +R1 +R2' && has '/harness-init:sync'; } && echo 0 || echo 1)"
rm_
check "같은 상태면 다시 안 알림" "$( { [ -z "$OUT" ]; } && echo 0 || echo 1)"

spec calc "- R1 x" "- R2 y 수정"
rm_
check "문서가 또 바뀌면 다시 알림" "$( { has 'calc: +R1 +R2'; } && echo 0 || echo 1)"

spec calc "- R1 x" "- R2 y 다시"
printf 'SPEC_REMINDER=0\n' >>"$REPO/.claude/harness.conf"
rm_
check "SPEC_REMINDER=0 이면 끔" "$( { [ -z "$OUT" ]; } && echo 0 || echo 1)"

check "상태는 .git 안에만" "$( { [ ! -e "$REPO/.claude/.harness-state" ]; } && echo 0 || echo 1)"

echo
echo "결과: ${pass} 통과, ${fail} 실패"
[ "$fail" = 0 ]
