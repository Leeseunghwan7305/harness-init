#!/usr/bin/env bash
# scripts/verify.sh 동작 테스트 — 임시 git 저장소에서 시나리오별 종료코드와 출력을 확인한다.
# 실행: bash tests/verify.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY="$ROOT/scripts/verify.sh"
pass=0
fail=0

new_repo() {
  REPO="$(mktemp -d)"
  RUNS="$REPO.runs" # 검사가 실제로 돌았는지 세는 파일 (저장소 밖)
  : >"$RUNS"
  git -C "$REPO" init -q
  git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  mkdir -p "$REPO/.claude" "$REPO/src" "$REPO/tests"
}

conf() { printf '%s\n' "$@" >"$REPO/.claude/harness.conf"; }

commit_all() {
  git -C "$REPO" -c core.autocrlf=false add -A
  git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m c
}

# run <stdin-json> → OUT, ERR, RC 설정
run() {
  OUT="$(printf '%s' "$1" | CLAUDE_PROJECT_DIR="$REPO" bash "$VERIFY" 2>"$REPO.err")"
  RC=$?
  ERR="$(cat "$REPO.err")"
}

runs() { wc -l <"$RUNS" | tr -d ' '; }

check() { # check <이름> <조건식 결과(0/1)>
  if [ "$2" = "0" ]; then
    pass=$((pass + 1))
    echo "  ✓ $1"
  else
    fail=$((fail + 1))
    echo "  ✗ $1  (rc=$RC runs=$(runs))"
    printf '    stdout: %s\n    stderr: %s\n' "$OUT" "$ERR"
  fi
}

ok() { "$@" && echo 0 || echo 1; }

echo "verify.sh"

# 1. 설정 파일 없음 → 아무것도 안 함
new_repo
echo x >"$REPO/src/a.ts"
run '{}'
check "설정 없으면 통과" "$(ok [ "$RC" = 0 ])"

# 2. ENABLED=0
conf "CHECK_CMD='echo r >> $RUNS; exit 1'" 'WATCH_PATHS="src/"' 'ENABLED=0'
run '{}'
check "ENABLED=0 이면 통과, 검사 안 돎" "$(ok [ "$RC" = 0 ] && [ "$(runs)" = 0 ])"

# 3. 감시 경로 밖 변경만 → 건너뜀
new_repo
conf "CHECK_CMD='echo r >> $RUNS; exit 1'" 'WATCH_PATHS="src/"'
commit_all
echo x >"$REPO/README.md"
run '{}'
check "감시 경로 밖 변경은 건너뜀" "$(ok [ "$RC" = 0 ] && [ "$(runs)" = 0 ])"

# 4. 실패 → exit 2, 고친 뒤 재시도(stop_hook_active)에도 다시 검사, 한도 넘으면 멈춤
echo x >"$REPO/src/a.ts"
run '{}'
check "검사 실패 → exit 2" "$(ok [ "$RC" = 2 ] && grep -q '1/3' <<<"$ERR")"
run '{"stop_hook_active": true}'
check "재시도에도 다시 검사 (2/3)" "$(ok [ "$RC" = 2 ] && [ "$(runs)" = 2 ])"
run '{"stop_hook_active":true}'
check "재시도 3/3" "$(ok [ "$RC" = 2 ] && [ "$(runs)" = 3 ])"
run '{"stop_hook_active":true}'
check "한도 초과 → 루프 멈추고 사용자에게 알림" "$(ok [ "$RC" = 0 ] && grep -q systemMessage <<<"$OUT" && [ "$(runs)" = 3 ])"

# 5. 새 턴은 실패 횟수를 0부터
run '{}'
check "새 턴은 실패 횟수 초기화 (1/3)" "$(ok [ "$RC" = 2 ] && grep -q '1/3' <<<"$ERR")"

# 6. 통과 → 같은 상태면 다시 안 돎, 바뀌면 다시 돎
conf "CHECK_CMD='echo r >> $RUNS'" 'WATCH_PATHS="src/"'
: >"$RUNS"
run '{}'
check "검사 통과 → exit 0" "$(ok [ "$RC" = 0 ] && [ "$(runs)" = 1 ])"
run '{}'
check "이미 통과한 상태면 건너뜀" "$(ok [ "$RC" = 0 ] && [ "$(runs)" = 1 ])"
echo y >>"$REPO/src/a.ts"
run '{}'
check "내용이 바뀌면 다시 검사" "$(ok [ "$RC" = 0 ] && [ "$(runs)" = 2 ])"

# 7. 시간 초과
if timeout --version 2>/dev/null | grep -q coreutils; then
  conf "CHECK_CMD='sleep 5'" 'WATCH_PATHS="src/"' 'TIMEOUT_SEC=1'
  run '{}'
  check "시간 초과 → exit 2 + 안내" "$(ok [ "$RC" = 2 ] && grep -q '초를 넘겨' <<<"$ERR")"
else
  echo "  - 시간 초과 테스트 건너뜀 (GNU timeout 없음)"
fi

# 8. 기존 테스트 파일만 수정 → 한 번 경고, 같은 상태면 다시 안 함
new_repo
conf "CHECK_CMD='true'" 'WATCH_PATHS="src/ tests/"'
echo 'expect(1)' >"$REPO/tests/a.test.ts"
echo 'code' >"$REPO/src/a.ts"
commit_all
echo 'expect(2)' >"$REPO/tests/a.test.ts"
run '{}'
check "테스트만 수정 → 경고 (exit 2)" "$(ok [ "$RC" = 2 ] && grep -q 'tests/a.test.ts' <<<"$ERR")"
run '{"stop_hook_active": true}'
check "같은 상태는 다시 경고 안 함" "$(ok [ "$RC" = 0 ])"

# 9. 기능 코드도 같이 바뀌면 경고 없음
echo 'code2' >"$REPO/src/a.ts"
run '{}'
check "기능 코드도 바뀌면 경고 없음" "$(ok [ "$RC" = 0 ])"

# 10. 새 테스트 파일 추가만 → 경고 없음
new_repo
conf "CHECK_CMD='true'" 'WATCH_PATHS="src/ tests/"'
commit_all
echo 'new' >"$REPO/tests/b.test.ts"
run '{}'
check "새 테스트 추가만은 경고 없음" "$(ok [ "$RC" = 0 ])"

# 11. TEST_GUARD=0
new_repo
conf "CHECK_CMD='true'" 'WATCH_PATHS="tests/"' 'TEST_GUARD=0'
echo a >"$REPO/tests/a.test.ts"
commit_all
echo b >"$REPO/tests/a.test.ts"
run '{}'
check "TEST_GUARD=0 이면 경고 없음" "$(ok [ "$RC" = 0 ])"

# 12. 커밋이 없는 새 저장소에서도 동작
REPO="$(mktemp -d)"
RUNS="$REPO.runs"
: >"$RUNS"
git -C "$REPO" init -q
mkdir -p "$REPO/.claude" "$REPO/src"
conf "CHECK_CMD='echo r >> $RUNS; exit 1'"
echo x >"$REPO/src/a.ts"
run '{}'
check "커밋 없는 저장소에서도 검사" "$(ok [ "$RC" = 2 ] && [ "$(runs)" = 1 ])"

# 13. CRLF 로 저장된 설정 파일
new_repo
printf "CHECK_CMD='echo r >> %s'\r\nWATCH_PATHS=\"src/\"\r\nENABLED=1\r\n" "$RUNS" >"$REPO/.claude/harness.conf"
echo x >"$REPO/src/a.ts"
run '{}'
check "CRLF 설정 파일도 읽음" "$(ok [ "$RC" = 0 ] && [ "$(runs)" = 1 ])"

# 14. 상태 파일이 작업 트리에 남지 않음
check "상태는 .git 안에만 (작업 트리 깨끗)" "$(ok [ ! -e "$REPO/.claude/.harness-state" ] && [ -d "$REPO/.git/harness" ])"

echo
echo "결과: ${pass} 통과, ${fail} 실패"
[ "$fail" = 0 ]
