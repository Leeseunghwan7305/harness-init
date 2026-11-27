#!/usr/bin/env bash
# harness-init — 제작 과정 일지에 한 줄 기록한다 (보고서 재료).
#
# 사용법: journal.sh <기능> <이벤트> [규칙번호|-] [내용...]
#
# 이벤트
#   spec            규칙 문서 작성/수정            (규칙 생략 가능)
#   test            규칙 테스트 작성               내용: 테스트 이름/파일
#   red             테스트가 먼저 실패함을 확인    내용: 실패 요약
#   impl            기능 구현                      내용: 무엇을 바꿨나 (파일)
#   green           테스트 통과
#   mutant-killed   망가뜨려 보기 → 테스트가 잡음  내용: 무엇을 망가뜨렸나
#   mutant-survived 망가뜨려도 통과 (테스트 부실)  내용: 무엇을 망가뜨렸나
#   fix             문제 수정                      내용: 무엇을 고쳤나
#   shot            화면 캡처                      내용: 이미지 경로
#   verify          검사 결과 (verifier 등)        내용: "✅ 화면까지" 처럼 판정 + 확인 깊이
#   todo            사람이 확인할 것               내용: 확인할 내용
#   verdict         전체 판정                      내용: "✅ 통과" / "❌ 실패" / "⚠️ 부분 통과"
#   mode            확인 강도 (make 가 시작할 때)  내용: "빠름" 또는 "꼼꼼"
#   note            기타 메모
#   video           데모 영상 생성 (demo.mjs 가 자동 기록) 내용: 재생 페이지 경로
#
# 기록 위치: .harness/journal/<기능>.jsonl (저장소에 커밋해 팀과 공유)
set -uo pipefail

if [ "$#" -lt 2 ]; then
  sed -n '2,23p' "$0" >&2
  exit 1
fi

feature="$1"
event="$2"
rule="${3:--}"
shift 2
[ "$#" -gt 0 ] && shift
detail="$*"

case "$event" in
  spec | test | red | impl | green | mutant-killed | mutant-survived | fix | shot | verify | todo | verdict | mode | note | video) ;;
  *) echo "journal: 모르는 이벤트 '$event' (journal.sh 로 목록 확인)" >&2; exit 1 ;;
esac
case "$rule" in
  - | R[0-9]*) ;;
  *) echo "journal: 규칙 번호는 R<번호> 또는 - 여야 한다: '$rule'" >&2; exit 1 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 1

json_str() {
  local s="${1//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/}"
  s="${s//$'\n'/\\n}"
  printf '"%s"' "$s"
}

commit=""
if command -v git >/dev/null 2>&1; then
  commit="$(git rev-parse --short HEAD 2>/dev/null || true)"
fi
[ "$rule" = "-" ] && rule=""

dir=".harness/journal"
mkdir -p "$(dirname "$dir/$feature.jsonl")"
printf '{"ts":%s,"event":%s,"rule":%s,"detail":%s,"commit":%s}\n' \
  "$(json_str "$(date -u +%Y-%m-%dT%H:%M:%SZ)")" \
  "$(json_str "$event")" \
  "$(json_str "$rule")" \
  "$(json_str "$detail")" \
  "$(json_str "$commit")" >>"$dir/$feature.jsonl"
