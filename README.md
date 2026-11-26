# harness-init

어느 프로젝트든 **처음 하네스를 세팅**하는 Claude Code 플러그인.
AI가 "다 됐어요"라고 말하기 전에 스스로 확인하게 만든다.

하네스 = 📏 기준 · 🔍 검사기 · 🔁 루프 · 🧾 보고

## 설치

```text
/plugin marketplace add Leeseunghwan7305/harness-init
/plugin install harness-init@harness-init
```

## 시작

```text
/harness-init:setup            # 진단 → 수준 선택 → 설치 → 확인 → 안내
/harness-init:setup basic      # 바로 기본(1~2단계)으로
```

"하네스 세팅해줘"라고 말해도 `harness-init` 스킬이 같은 흐름을 탄다.

### 세팅 수준

| 수준 | 단계 | 이런 때 |
| --- | --- | --- |
| **기본** (추천) | 1~2 | 처음. check 명령 + Stop 훅만으로도 체감이 크다 |
| **표준** | 1~6, 8~9 | 기능 하나로 규칙 문서 → 테스트 → 캡처 → 독립 검사 한 바퀴 |
| **전체** | 1~10 | 표준 + eval(AI 기능 있을 때) + CI |

## 10단계 ↔ 구성 요소

| 순서 | 할 일 | 시간 | 효과 | 구성 요소 |
| --- | --- | --- | --- | --- |
| 1 | 빠른 검사 + `check` 명령 | 반나절 | ★★★ | `setup`이 세팅 |
| 2 | Stop 훅으로 루프 닫기 | 1시간 | ★★★ | 내장 훅 `scripts/verify.sh` + `.claude/harness.conf` |
| 3 | 기능 하나의 규칙 문서 | 10분 | ★★ | `/harness-init:spec <기능>` |
| 4 | 규칙별 테스트 + 망가뜨려 보기 | 1~2시간 | ★★★ | `/harness-init:rule-tests <기능>` |
| 5 | 캡처 검사 | 1시간 | ★★ | `/harness-init:visual <기능>` |
| 6 | 독립 검사 서브에이전트 | 30분 | ★★ | `verifier` 에이전트 (읽기 전용) |
| 7 | eval (AI 기능 있을 때만) | 반나절 | ★★★ | `/harness-init:eval` + `templates/eval/score.mjs` |
| 8~9 | 보고 형식 + 명령 파일 | 30분 | ★ 편의 | `harness-report` 스킬 + `/harness-init:check-feature <기능>` |
| 10 | CI | 반나절 | ★★ | `/harness-init:ci` + `templates/ci/harness.yml` |

현황 점검·다음 할 일 추천: `/harness-init:status`

## Stop 훅은 옵트인

플러그인을 켜도 **`.claude/harness.conf`가 있는 프로젝트에서만** 검사가 돈다 (`templates/harness.conf` 참고).

- 실패 → `exit 2` → Claude가 메시지를 읽고 고친 뒤 다시 끝내려 한다.
- `stop_hook_active`면 통과(무한 반복 방지), 변경 없는 턴은 건너뜀, `WATCH_PATHS` 밖 변경도 건너뜀.
- 빠른 검사만 넣을 것. 1~2분 넘으면 결국 훅을 끄게 된다.
- 프로젝트에 이미 자체 Stop 훅이 있으면 둘 중 하나만 쓴다.

## 흔한 함정 5가지

1. AI가 테스트를 고쳐서 통과시킴 → verifier가 "기대값만 바뀐 diff"를 의심한다. 망가뜨려 보기로 확인.
2. 처음부터 전부 자동화하려다 지침 → 기본 수준으로 시작, 기능 하나씩 넓힌다.
3. 기준 문서가 낡음 → 기획이 바뀌면 문서부터.
4. 느린 검사를 훅에 넣음 → 훅에는 check만.
5. "통과"만 보고 믿음 → 항상 "어디까지 확인했는지"를 같이 받는다.
