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

## 수정은 문서부터 — `/harness-init:sync`

기능을 바꾸고 싶으면 "코드 짜줘" 대신 **규칙 문서를 고친다.**

```text
1. docs/specs/calculator.md 수정       (- R10 % 버튼은 100으로 나눈다  추가)
2. Claude 에게 아무 말이나 걸면        → "R10 이 아직 반영 안 됐어요. sync 할까요?"   (알림 훅)
3. /harness-init:sync  (또는 "응")     → 바뀐 규칙만 테스트 → 구현 → 검사 → 보고
```

- 비교 기준은 마지막 커밋이 아니라 **마지막으로 반영한 스냅샷**(`.claude/harness-synced/`) — 문서를 먼저 커밋해도 놓치지 않는다. 스냅샷은 코드와 같이 커밋한다.
- 삭제된 규칙·`(확인 필요)` 규칙·충돌은 진행 전에 묻는다. 바뀐 규칙이 모두 ✅일 때만 반영 완료로 표시된다.
- 규칙 번호는 **재사용·재배열하지 않는다** (R3을 지웠으면 다음 규칙은 R11). 번호가 곧 테스트 이름이다.
- 이미 구현된 기능에 문서를 처음 붙이는 경우: `bash <플러그인>/scripts/spec-status.sh --mark-all`로 기준선을 잡는다 (`setup`이 물어본다).

## 제작 과정 보고서 — `/harness-init:report <기능>`

기능을 만들면서 Claude가 남긴 일지로 **어떻게 만들어졌는지**를 HTML 한 장으로 보여준다.

| 들어가는 것 | 재료 |
| --- | --- |
| 판정 · 규칙 통과 수 · 망가뜨려 보기 잡은 수 · 자동 검사 통과/막힘 · 커밋 수 | 전부 |
| 규칙별 결과 · **과정 아이콘**(🧪→🔴→🛠→🟢→🧨) · 확인 깊이 · 테스트 · 커밋 | 규칙 문서 + 일지 + git |
| 사람이 확인할 것 | 일지 `todo` |
| 타임라인 (일지 · 커밋 · Stop 훅 자동 검사를 시간순으로) | 일지 + git + `.git/harness/checks.jsonl` |
| 캡처 (파일 안에 내장 — 파일 하나로 공유) | 일지 `shot` |

- 일지: `.harness/journal/<기능>.jsonl` — `rule-tests` · `sync` · `check-feature`가 단계마다 `scripts/journal.sh`로 자동 기록. **커밋해서 팀과 공유.**
- 보고서: `.harness/reports/<기능>.html` — 언제든 다시 만들 수 있으니 `.gitignore` 권장 (`setup`이 추가).
- 망가뜨려도 통과한 규칙은 "통과"로 세지 않는다 (⚠️ 테스트 부실).
- `check-feature` · `sync`는 끝날 때 보고서를 자동으로 만든다.

## 데모 영상 — `/harness-init:demo <기능>`

규칙 번호가 붙은 E2E 테스트(`test('R2: 2 + 3 = 5', …)`)를 **녹화**해서 만든 기능을 영상으로 보여준다.

```text
.harness/demo/<기능>/
  index.html     규칙 순서대로 이어 재생 (자막 · 목록 · 속도 조절 · 장면마다 결과 화면 1.2초 유지)
  clips/*.webm   규칙별 장면
  demo.mp4       ffmpeg 가 있으면 한 편으로 합친 영상 (자막 트랙 포함)
```

- 프로젝트 Playwright 설정은 건드리지 않고, 녹화 옵션(영상 켜기 · 동작 느리게 `--slowmo`)만 덮어쓴 설정으로 따로 돌린다.
- 실패한 테스트도 장면으로 남기고 ❌로 표시한다. 제작 과정 보고서에 영상 섹션이 붙는다.
- 화면 있는 앱만 해당. 영상은 "규칙대로 동작한다"는 증거이고, 좋은 화면인지는 사람이 본다.
- 크기가 크니 `.harness/demo/`는 `.gitignore` 권장.

## Stop 훅은 옵트인

플러그인을 켜도 **`.claude/harness.conf`가 있는 프로젝트에서만** 검사가 돈다 (`templates/harness.conf` 참고).

| 상황 | 훅 동작 |
| --- | --- |
| 검사 실패 | `exit 2` → Claude가 메시지를 읽고 고친 뒤 다시 끝내려 한다 |
| 고친 뒤 다시 끝내려 함 | **다시 검사**한다. `MAX_RETRIES`(기본 3)번 연속 실패하면 루프를 멈추고 사용자에게 알림 |
| 감시 경로에 변경 없음 / 마지막 통과 상태와 같음 | 건너뜀 (미커밋 변경이 남아 있어도 대화만 한 턴엔 안 돎) |
| `TIMEOUT_SEC`(기본 180초) 초과 | 실패로 보고 "느린 검사를 빼라"고 안내 |
| 기존 테스트 파일만 수정, 기능 코드는 그대로 | 통과해도 한 번 경고 — 기대값을 바꿔 통과시킨 의심 (`TEST_GUARD=0`으로 끔) |

- 상태는 `.git/harness/`에 저장해 작업 트리를 더럽히지 않는다.
- 빠른 검사만 넣을 것. 1~2분 넘으면 결국 훅을 끄게 된다.
- 프로젝트에 이미 자체 Stop 훅이 있으면 둘 중 하나만 쓴다.

## 개발

```bash
bash tests/verify.test.sh      # Stop 훅 시나리오 테스트
bash tests/spec-sync.test.sh   # 문서 diff · 알림 훅 테스트
bash tests/report.test.sh      # 일지 · 보고서 · 검사 기록 테스트 (node 필요)
bash tests/demo.test.sh        # 데모 영상 조립 테스트 (Playwright 없이 가짜 리포트로)
claude plugin validate .       # 매니페스트 검사
```

CI가 PR마다 shellcheck · 훅 테스트(ubuntu + windows) · JSON 검사를 돌린다. 변경은 `CHANGELOG.md`에 기록하고 `plugin.json`의 version을 올린다.

## 라이선스

MIT

## 흔한 함정 5가지

1. AI가 테스트를 고쳐서 통과시킴 → verifier가 "기대값만 바뀐 diff"를 의심한다. 망가뜨려 보기로 확인.
2. 처음부터 전부 자동화하려다 지침 → 기본 수준으로 시작, 기능 하나씩 넓힌다.
3. 기준 문서가 낡음 → 기획이 바뀌면 문서부터.
4. 느린 검사를 훅에 넣음 → 훅에는 check만.
5. "통과"만 보고 믿음 → 항상 "어디까지 확인했는지"를 같이 받는다.
