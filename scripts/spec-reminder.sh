#!/usr/bin/env bash
# harness-init — UserPromptSubmit 훅: 규칙 문서가 바뀌었는데 코드에 반영(sync)되지 않았으면 Claude에게 알린다.
#
# - .claude/harness.conf 가 있는 프로젝트에서만 동작 (SPEC_REMINDER=0 이면 끔)
# - 같은 변경 상태에 대해서는 한 번만 알린다 (무시하면 다시 안 물어봄, 문서가 또 바뀌면 다시 알림)
# - stdout 이 이번 프롬프트의 추가 컨텍스트로 Claude 에게 전달된다
set -uo pipefail

cat >/dev/null 2>&1 || true

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
conf=".claude/harness.conf"
[ -f "$conf" ] || exit 0

ENABLED=1
SPEC_REMINDER=1
# `. <(...)` 는 macOS 기본 bash 3.2 에서 아무것도 읽지 않으므로 eval 로 읽는다.
eval "$(tr -d '\r' <"$conf")"
[ "$ENABLED" = "1" ] && [ "$SPEC_REMINDER" = "1" ] || exit 0

here="$(cd "$(dirname "$0")" && pwd)"
pending="$(bash "$here/spec-status.sh" --brief 2>/dev/null)"
[ -n "$pending" ] || exit 0

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  state_dir="$(git rev-parse --git-path harness)"
else
  state_dir=".claude/.harness-state"
fi
mkdir -p "$state_dir" 2>/dev/null || true

fp="$(bash "$here/spec-status.sh" 2>/dev/null | cksum | awk '{print $1}')"
[ "$fp" = "$(cat "$state_dir/spec_reminded" 2>/dev/null)" ] && exit 0
printf '%s\n' "$fp" >"$state_dir/spec_reminded" 2>/dev/null || true

cat <<EOF
[harness-init] 규칙 문서가 바뀌었는데 아직 코드에 반영(sync)되지 않았다:
$(printf '%s\n' "$pending" | sed 's/^/- /')
(+ 추가 / ~ 수정 / - 삭제)

사용자의 이번 요청을 먼저 처리하라. 이번 요청이 이 변경을 반영하라는 뜻이면 /harness-init:make 절차를 따른다 (그 문서 이름으로).
그렇지 않으면 응답 끝에 한 줄로 "규칙 문서 변경(위 요약)이 아직 반영 안 됐어요. 반영할까요? (/harness-init:make)" 라고만 제안한다.
EOF
exit 0
