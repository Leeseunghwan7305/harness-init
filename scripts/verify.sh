#!/usr/bin/env bash
# harness 플러그인 — Stop 훅 검증 게이트 (2단계: 루프 닫기)
#
# 프로젝트에 .claude/harness.conf 가 있을 때만 동작한다 (옵트인).
# 없으면 아무 것도 하지 않고 통과 → 플러그인을 켜 둬도 다른 프로젝트에 영향 없음.
#
# .claude/harness.conf 예시 (/harness-init:setup 이 만들어 준다):
#   CHECK_CMD="npm run check"          # 타입 + 린트 + 테스트를 한 번에 (1단계)
#   WATCH_PATHS="src/ tests/"          # 이 경로가 바뀐 턴에만 검사. 비우면 모든 변경
#   TAIL_LINES=30                      # 실패 시 AI에게 보여줄 출력 줄 수
#   ENABLED=1                          # 0 이면 잠시 끄기
#
# 실패하면 exit 2 → 턴 종료를 막고 stderr 를 Claude 에게 전달한다 (= 고치고 다시 끝내라).
set -uo pipefail

input="$(cat 2>/dev/null || true)"

# 무한 반복 방지: 이미 이 훅 때문에 다시 도는 중이면 통과
case "$input" in
  *'"stop_hook_active":true'* | *'"stop_hook_active": true'*) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

conf=".claude/harness.conf"
[ -f "$conf" ] || exit 0

CHECK_CMD=""
WATCH_PATHS=""
TAIL_LINES=30
ENABLED=1
# shellcheck disable=SC1090
. "$conf"

[ "$ENABLED" = "1" ] || exit 0
if [ -z "$CHECK_CMD" ]; then
  echo "harness: $conf 에 CHECK_CMD 가 비어 있다 — /harness-init:setup 으로 설정하라." >&2
  exit 0
fi

# 코드가 안 바뀐 턴(대화만 한 턴)은 건너뜀
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  changed="$( { git diff --name-only HEAD; git diff --name-only --cached; git ls-files --others --exclude-standard; } 2>/dev/null | sort -u )"
  [ -n "$changed" ] || exit 0
  if [ -n "$WATCH_PATHS" ]; then
    hit=0
    for p in $WATCH_PATHS; do
      if printf '%s\n' "$changed" | grep -q "^${p}"; then hit=1; break; fi
    done
    [ "$hit" = "1" ] || exit 0
  fi
fi

echo "▶ harness verify: $CHECK_CMD" >&2
if ! out="$(bash -c "$CHECK_CMD" 2>&1)"; then
  {
    echo "✗ 검사 실패 — 끝내기 전에 고쳐라. (테스트를 고쳐서 통과시키지 말고 기능 코드를 고칠 것)"
    echo "  명령: $CHECK_CMD"
    printf '%s\n' "$out" | tail -n "$TAIL_LINES"
  } >&2
  exit 2
fi
echo "✓ harness verify 통과" >&2
exit 0
