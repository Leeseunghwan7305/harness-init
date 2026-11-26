---
description: 이 프로젝트의 하네스 도입 현황을 10단계 로드맵 기준으로 점검하고 다음 할 일을 추천한다
allowed-tools: Read, Grep, Glob, Bash
---

읽기 전용으로 현재 프로젝트를 훑어 하네스 도입 현황표를 만든다. 아무것도 고치지 않는다.

## 점검 항목

| 순서 | 할 일 | 시간 | 효과 | 무엇으로 판단하나 | 명령 |
| --- | --- | --- | --- | --- | --- |
| 1 | 빠른 검사 + `check` 명령 | 반나절 | ★★★ | 타입·린트·테스트 도구 + 하나로 묶은 명령이 있는가, 실제로 통과하는가 | `/harness-init:setup` |
| 2 | Stop 훅으로 루프 닫기 | 1시간 | ★★★ | `.claude/harness.conf`(ENABLED=1) 또는 `.claude/settings.json`의 Stop 훅 | `/harness-init:setup` |
| 3 | 기능 하나의 규칙 문서 | 10분 | ★★ | `docs/specs/*.md`에 R번호 규칙이 있는가 | `/harness-init:spec` |
| 4 | 규칙별 테스트 + 망가뜨려 보기 | 1~2시간 | ★★★ | 테스트 이름에 R번호가 있는가, 규칙 대비 몇 % 커버 | `/harness-init:rule-tests` |
| 5 | 캡처 검사 | 1시간 | ★★ | Playwright/스크린샷 설정, 기준 캡처 (화면 없는 프로젝트는 N/A) | `/harness-init:visual` |
| 6 | 독립 검사 서브에이전트 | 30분 | ★★ | 이 플러그인의 `verifier` 또는 프로젝트 `.claude/agents/`의 읽기 전용 검사 에이전트 | (플러그인 포함) |
| 7 | eval (AI 기능 있을 때만) | 반나절 | ★★★ | LLM 호출 코드가 있는가 → 골든 세트·채점 스크립트가 있는가 | `/harness-init:eval` |
| 8~9 | 보고 형식 + 명령 파일 | 30분 | ★ | 이 플러그인의 `harness-report` 스킬, `/harness-init:check-feature` | (플러그인 포함) |
| 10 | CI | 반나절 | ★★ | `.github/workflows/`, `.gitlab-ci.yml`에서 check를 도는가 | `/harness-init:ci` |

추가로 `bash "${CLAUDE_PLUGIN_ROOT}/scripts/spec-status.sh" --brief`를 돌려 **코드에 반영 안 된 규칙 문서 변경**이 있으면 표 아래에 보여주고 `/harness-init:sync`를 안내한다.

## 출력

1. 위 표에 `상태` 열(✅ 완료 / ⚠️ 일부 / ❌ 없음 / — 해당 없음)과 근거(파일 경로)를 붙여 보여준다.
2. **다음에 할 일 1개**를 추천한다: 아직 안 된 단계 중 순서가 가장 앞선 것. 1~2단계가 안 됐으면 무조건 그것부터.
3. "1~2단계만 해도 체감이 큽니다. 거기서 멈춰도 괜찮고, 필요할 때 하나씩 붙이면 됩니다." 를 상기시킨다.
