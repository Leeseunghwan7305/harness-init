---
description: 기능 하나의 제작 과정 보고서(HTML)를 만든다 — 규칙별 결과·과정·망가뜨려 보기·자동 검사·커밋·캡처를 한 장으로
argument-hint: <기능이름>
allowed-tools: Read, Bash, Glob
---

`$ARGUMENTS` 기능의 제작 과정 보고서를 만든다.

1. 재료를 확인한다:
   - 규칙 문서 `docs/specs/$ARGUMENTS.md` (또는 `SPECS_DIR`)
   - 작업 일지 `.harness/journal/$ARGUMENTS.jsonl` — 없으면 "일지 없이 문서와 커밋만으로 만든다"고 알린다
2. 생성한다:
   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/scripts/report.mjs" $ARGUMENTS
   ```
   Node가 없으면 설치를 안내하고 멈춘다.
3. 출력된 경로(`.harness/reports/$ARGUMENTS.html`)를 사용자에게 알려준다. 파일 하나에 캡처까지 들어 있어 그대로 공유할 수 있다고 덧붙인다.
4. 보고서의 핵심을 3줄로 요약한다: 판정, 통과 규칙 수, 눈여겨볼 것(망가뜨려도 통과한 규칙, 자동 검사가 여러 번 막힌 구간, 사람이 확인할 것).
