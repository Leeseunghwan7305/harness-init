#!/usr/bin/env bash
# harness-init — Stop 훅 검증 게이트 (2단계: 루프 닫기)
#
# 프로젝트에 .claude/harness.conf 가 있을 때만 동작한다 (옵트인).
# 설정 항목은 templates/harness.conf 참고 (/harness-init:setup 이 만들어 준다).
#
# 동작
#   - 감시 경로에 변경이 없거나, 마지막으로 통과한 상태와 같으면 건너뛴다.
#   - CHECK_CMD 실패/시간 초과 → exit 2 (턴 종료를 막고 stderr 를 Claude 에게 전달).
#   - 고친 뒤 다시 끝내려 할 때도 다시 검사한다. MAX_RETRIES 번 연속 실패하면 루프를 멈추고 사람에게 알린다.
#   - 통과했어도 기존 테스트 파일만 수정되고 기능 코드는 그대로면 한 번 경고한다 (테스트를 고쳐 통과시킨 의심).
#
# 상태는 git 디렉터리 안(.git/harness/)에 둔다 — 작업 트리를 더럽히지 않는다.
set -uo pipefail

input="$(cat 2>/dev/null || true)"
hook_active=0
case "$input" in
  *'"stop_hook_active":true'* | *'"stop_hook_active": true'*) hook_active=1 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

conf=".claude/harness.conf"
[ -f "$conf" ] || exit 0

# 기본값 (harness.conf 에서 덮어쓴다)
CHECK_CMD=""
WATCH_PATHS=""
TAIL_LINES=30
ENABLED=1
TIMEOUT_SEC=180
MAX_RETRIES=3
TEST_GUARD=1
TEST_PATTERN='(^|/)(tests?|__tests__|specs?)/|\.(test|spec)\.[^/]+$|_test\.[^/]+$|(^|/)test_[^/]+\.py$'
# Windows 편집기가 넣은 CR 을 지우고 읽는다 (값 끝에 \r 이 붙는 것 방지).
# shellcheck disable=SC1090
. <(tr -d '\r' <"$conf")

[ "$ENABLED" = "1" ] || exit 0

# 사용자에게 보이는 메시지 (Stop 훅 JSON 출력의 systemMessage)
json_str() {
  local s="${1//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf '"%s"' "$s"
}
notify_user() { printf '{"systemMessage": %s}\n' "$(json_str "$1")"; }

if [ -z "$CHECK_CMD" ]; then
  notify_user "harness: $conf 에 CHECK_CMD 가 비어 있어 검사를 건너뜀 — /harness-init:setup 으로 설정하세요."
  exit 0
fi

# ── 변경 감지 ─────────────────────────────────────────────
in_git=0
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git=1
fi

if [ "$in_git" = "1" ]; then
  state_dir="$(git rev-parse --git-path harness)"
else
  state_dir=".claude/.harness-state"
fi
mkdir -p "$state_dir" 2>/dev/null || true

fp=""
changed=""
modified=""
if [ "$in_git" = "1" ]; then
  base="HEAD"
  git rev-parse -q --verify HEAD >/dev/null 2>&1 || base="4b825dc642cb6eb9a060e54bf8d69288fbee4904" # 빈 트리
  # 감시 경로(pathspec) + 일지·스냅샷은 코드 변경이 아니므로 제외
  read -r -a pathspec <<<"$WATCH_PATHS"
  pathspec+=(":(exclude).harness" ":(exclude).claude/harness-synced")
  tracked="$(git diff --relative --name-only "$base" -- "${pathspec[@]}" 2>/dev/null)"
  modified="$(git diff --relative --name-only --diff-filter=M "$base" -- "${pathspec[@]}" 2>/dev/null)"
  untracked="$(git ls-files --others --exclude-standard -- "${pathspec[@]}" 2>/dev/null)"
  changed="$(printf '%s\n%s\n' "$tracked" "$untracked" | sed '/^$/d' | sort -u)"

  if [ -z "$changed" ]; then
    rm -f "$state_dir/fails"
    exit 0
  fi

  # 현재 상태 지문: 감시 경로 diff + 미추적 파일 내용 + 검사 명령
  fp="$(
    {
      printf '%s\n' "$CHECK_CMD"
      git diff --relative --binary "$base" -- "${pathspec[@]}" 2>/dev/null
      printf '%s\n' "$untracked" | while IFS= read -r f; do
        [ -f "$f" ] && printf '%s %s\n' "$f" "$(git hash-object -- "$f")"
      done
    } | git hash-object --stdin
  )"
  if [ -n "$fp" ] && [ "$fp" = "$(cat "$state_dir/last_ok" 2>/dev/null)" ]; then
    exit 0 # 이 상태는 이미 통과했다
  fi
fi

# ── 재시도 한도 ───────────────────────────────────────────
fails=0
if [ "$hook_active" = "1" ]; then
  fails="$(cat "$state_dir/fails" 2>/dev/null || echo 0)"
  case "$fails" in '' | *[!0-9]*) fails=0 ;; esac
  if [ "$fails" -ge "$MAX_RETRIES" ]; then
    rm -f "$state_dir/fails"
    notify_user "harness: 검사가 ${fails}번 연속 실패해 자동 수정 루프를 멈췄습니다. 사람 확인이 필요합니다 — 명령: $CHECK_CMD"
    exit 0
  fi
fi

# ── 검사 실행 ─────────────────────────────────────────────
# GNU timeout 만 쓴다 (Windows 의 timeout.exe 는 다른 프로그램이다).
if [ "${TIMEOUT_SEC:-0}" -gt 0 ] 2>/dev/null && timeout --version 2>/dev/null | grep -q coreutils; then
  out="$(timeout "$TIMEOUT_SEC" bash -c "$CHECK_CMD" 2>&1)"
else
  out="$(bash -c "$CHECK_CMD" 2>&1)"
fi
rc=$?

# 제작 과정 보고서용 자동 검사 기록 (로컬 전용, .git/harness/checks.jsonl)
log_check() {
  printf '{"ts":"%s","result":"%s","n":%s,"max":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$MAX_RETRIES" >>"$state_dir/checks.jsonl" 2>/dev/null || true
}

if [ "$rc" -ne 0 ]; then
  fails=$((fails + 1))
  printf '%s\n' "$fails" >"$state_dir/fails" 2>/dev/null || true
  if [ "$rc" -eq 124 ]; then log_check timeout "$fails"; else log_check fail "$fails"; fi
  {
    if [ "$rc" -eq 124 ]; then
      echo "✗ 검사가 ${TIMEOUT_SEC}초를 넘겨 중단됨 (${fails}/${MAX_RETRIES})."
      echo "  Stop 훅에는 빠른 검사만 둔다. 느린 부분(E2E·eval 등)을 CHECK_CMD 에서 빼거나, 원인을 찾아 고쳐라."
    else
      echo "✗ 검사 실패 (${fails}/${MAX_RETRIES}) — 끝내기 전에 고쳐라. 테스트 기대값을 바꿔 통과시키지 말고 기능 코드를 고칠 것."
    fi
    echo "  명령: $CHECK_CMD"
    printf '%s\n' "$out" | tail -n "$TAIL_LINES"
  } >&2
  exit 2
fi

rm -f "$state_dir/fails"
log_check pass 0
[ -n "$fp" ] && printf '%s\n' "$fp" >"$state_dir/last_ok" 2>/dev/null

# ── 테스트만 고쳐서 통과시켰는지 경고 (상태마다 한 번) ─────────
if [ "$TEST_GUARD" = "1" ] && [ "$in_git" = "1" ] && [ -n "$modified" ]; then
  mod_tests="$(printf '%s\n' "$modified" | grep -E "$TEST_PATTERN" || true)"
  src_changes="$(printf '%s\n' "$changed" | grep -vE "$TEST_PATTERN" || true)"
  if [ -n "$mod_tests" ] && [ -z "$src_changes" ] && [ "$fp" != "$(cat "$state_dir/guard_warned" 2>/dev/null)" ]; then
    printf '%s\n' "$fp" >"$state_dir/guard_warned" 2>/dev/null
    {
      echo "⚠ 검사는 통과했지만 기존 테스트 파일만 수정됐고 기능 코드는 그대로다:"
      printf '%s\n' "$mod_tests" | sed 's/^/  - /'
      echo "  기대값을 바꿔 통과시킨 게 아닌지 확인하라. 정당한 수정이면 왜 바꿨는지 사용자 보고에 적고 끝내라."
    } >&2
    exit 2
  fi
fi

echo "✓ harness verify 통과" >&2
exit 0
