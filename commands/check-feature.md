---
description: "(고급 — 보통은 make) 새 기능 하나를 기준 문서대로 테스트·캡처·독립검사하고 정해진 형식으로 보고한다"
argument-hint: <기능이름>
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, Agent
---

`$ARGUMENTS` 기능을 하네스 전체 흐름으로 한 바퀴 돌린다. (`make`에서 불렸으면 make가 고른 확인 강도를 따른다 — 처음 만드는 기능은 보통 꼼꼼.)

1. `docs/specs/$ARGUMENTS.md`를 읽는다. 없으면 `/harness-init:spec`의 형식으로 초안을 만들고 **사용자 확인을 받은 뒤** 진행한다. 문서에 없는 동작은 추측하지 말고 "미확인"으로 둔다.
2. 규칙마다 테스트를 만들고 통과시킨다 — `/harness-init:rule-tests`의 절차(모킹 원칙, 망가뜨려 보기 포함)를 따른다. 테스트 기대값을 바꿔 통과시키지 않는다.
3. 프로젝트의 check 명령(`.claude/harness.conf`의 `CHECK_CMD`)을 돌려 전체가 통과하는지 확인한다.
4. 화면이 있는 기능이면 `/harness-init:visual`의 절차로 캡처를 보고 고친다 (최대 3회).
5. **verifier 서브에이전트**에게 검사시킨다. 넘기는 것은 기능 이름과 문서 경로뿐 — 구현 설명·내 판단은 넘기지 않는다.
6. verifier 결과와 내 결과를 합쳐 `harness-report` 형식으로 보고한다. 둘이 다르면 다르다고 그대로 적는다 (verifier의 ❌를 덮지 않는다).
7. 모든 규칙이 ✅이면 반영 완료로 표시한다: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/spec-status.sh" --mark $ARGUMENTS`. 이후 문서를 고치면 `/harness-init:sync`가 바뀐 규칙만 처리한다.
8. 진행 내내 `rule-tests`의 일지 규칙대로 `journal.sh`에 기록하고, verifier 결과는 규칙마다 `verify`, 사람 확인은 `todo`, 전체 판정은 `verdict`로 남긴다. 마지막에 `node "${CLAUDE_PLUGIN_ROOT}/scripts/report.mjs" $ARGUMENTS`로 제작 과정 보고서를 만들고 경로를 알려준다.
9. 화면 있는 기능이고 규칙 번호가 붙은 E2E가 있으면 데모 영상을 만든다 — `make`에서 불렸으면 묻지 않고, 직접 불렸으면 사용자에게 묻는다 (`/harness-init:demo $ARGUMENTS` 절차). 만들면 보고서를 다시 생성해 영상 섹션을 붙인다.
