#!/usr/bin/env bash
# harness-init — 규칙 문서(docs/specs/*.md)와 "마지막으로 코드에 반영한 스냅샷"을 비교한다.
#
# 사용법
#   spec-status.sh [이름|경로]        반영 안 된 규칙 변경을 자세히 출력 (없으면 출력 없음)
#   spec-status.sh --brief [이름]     한 줄 요약 (calculator: +R10 ~R7 -R3)
#   spec-status.sh --mark <이름|경로> 이 문서를 "반영 완료"로 표시 (스냅샷 갱신)
#   spec-status.sh --mark-all         모든 문서를 반영 완료로 표시 (기존 프로젝트 기준선 잡기)
#
# 규칙 줄 형식: "- R<번호> 내용"  (번호는 재사용·재배열하지 않는다)
# 스냅샷: $SYNC_DIR/<이름>.md — 저장소에 커밋해 다른 컴퓨터와 공유한다.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

SPECS_DIR="docs/specs"
SYNC_DIR=".claude/harness-synced"
conf=".claude/harness.conf"
if [ -f "$conf" ]; then
  # `. <(...)` 는 macOS 기본 bash 3.2 에서 아무것도 읽지 않으므로 eval 로 읽는다.
  eval "$(tr -d '\r' <"$conf")"
fi

mode="full"
target=""
case "${1:-}" in
  --brief) mode="brief"; target="${2:-}" ;;
  --mark) mode="mark"; target="${2:-}" ;;
  --mark-all) mode="mark-all" ;;
  -h | --help) sed -n '2,12p' "$0"; exit 0 ;;
  *) target="${1:-}" ;;
esac

# 이름 또는 경로 → 문서 경로
resolve() {
  if [ -f "$1" ]; then printf '%s\n' "$1"
  elif [ -f "$SPECS_DIR/$1.md" ]; then printf '%s\n' "$SPECS_DIR/$1.md"
  else return 1
  fi
}

# 문서 경로 → 이름 (SPECS_DIR 기준 상대경로, .md 제외)
name_of() {
  local p="${1#./}"
  p="${p#"$SPECS_DIR"/}"
  printf '%s\n' "${p%.md}"
}

# 규칙 줄만 "R번호<TAB>내용"으로 뽑는다
rules_of() {
  [ -f "$1" ] || return 0
  tr -d '\r' <"$1" | awk '
    /^[[:space:]]*[-*][[:space:]]+(\*\*)?R[0-9]+/ {
      line = $0
      match(line, /R[0-9]+/)
      id = substr(line, RSTART, RLENGTH)
      text = substr(line, RSTART + RLENGTH)
      gsub(/^[*:.)[:space:]]+/, "", text)
      gsub(/[[:space:]]+$/, "", text)
      gsub(/[[:space:]]+/, " ", text)
      print id "\t" text
    }'
}

# 두 규칙 목록 비교 → "+|~|-<TAB>R번호<TAB>내용" (번호순)
diff_rules() {
  awk -F'\t' '
    FILENAME == ARGV[1] { old[$1] = $2; next }   # NR==FNR 은 앞 파일이 비면 깨진다
    { new[$1] = $2 }
    END {
      for (k in new) {
        if (!(k in old)) print "+\t" k "\t" new[k]
        else if (old[k] != new[k]) print "~\t" k "\t" new[k]
      }
      for (k in old) if (!(k in new)) print "-\t" k "\t" old[k]
    }' <(rules_of "$1") <(rules_of "$2") | sort -t "$(printf '\t')" -k2,2V
}

mark() {
  local spec="$1" snap
  snap="$SYNC_DIR/$(name_of "$spec").md"
  mkdir -p "$(dirname "$snap")"
  cp "$spec" "$snap"
  echo "✓ 반영 완료로 표시: $(name_of "$spec") → $snap"
}

specs() {
  [ -d "$SPECS_DIR" ] || return 0
  find "$SPECS_DIR" -type f -name '*.md' | sort
}

case "$mode" in
  mark)
    [ -n "$target" ] || { echo "사용법: spec-status.sh --mark <이름|경로>" >&2; exit 1; }
    spec="$(resolve "$target")" || { echo "문서를 찾을 수 없다: $target" >&2; exit 1; }
    mark "$spec"
    exit 0
    ;;
  mark-all)
    specs | while IFS= read -r s; do mark "$s"; done
    exit 0
    ;;
esac

if [ -n "$target" ]; then
  list="$(resolve "$target")" || { echo "문서를 찾을 수 없다: $target" >&2; exit 1; }
else
  list="$(specs)"
fi

# 문서에서 사라진 스냅샷 (문서 자체를 지운 경우)
removed_docs=""
if [ -z "$target" ] && [ -d "$SYNC_DIR" ]; then
  removed_docs="$(find "$SYNC_DIR" -type f -name '*.md' | sort | while IFS= read -r snap; do
    n="${snap#"$SYNC_DIR"/}"
    [ -f "$SPECS_DIR/$n" ] || printf '%s\n' "${n%.md}"
  done)"
fi

printf '%s\n' "$list" | while IFS= read -r spec; do
  [ -n "$spec" ] || continue
  name="$(name_of "$spec")"
  snap="$SYNC_DIR/$name.md"
  changes="$(diff_rules "$snap" "$spec")"
  [ -n "$changes" ] || continue
  if [ "$mode" = "brief" ]; then
    printf '%s: %s\n' "$name" "$(printf '%s\n' "$changes" | awk -F'\t' '{printf "%s%s%s", (NR>1?" ":""), $1, $2}')"
  else
    if [ -f "$snap" ]; then label="변경"; else label="새 문서 (아직 반영한 적 없음)"; fi
    printf '%s (%s) — %s\n' "$name" "$spec" "$label"
    printf '%s\n' "$changes" | awk -F'\t' '{
      kind = ($1 == "+") ? "추가" : ($1 == "~") ? "수정" : "삭제"
      printf "  %s %s [%s] %s\n", $1, $2, kind, $3
    }'
  fi
done

if [ -n "$removed_docs" ]; then
  printf '%s\n' "$removed_docs" | while IFS= read -r n; do
    if [ "$mode" = "brief" ]; then printf '%s: 문서 삭제됨\n' "$n"
    else printf '%s — 문서 삭제됨 (스냅샷: %s/%s.md). 관련 테스트·코드 정리 필요\n' "$n" "$SYNC_DIR" "$n"
    fi
  done
fi
exit 0
