---
name: harness-init
description: 프로젝트에 AI 작업 검증 하네스를 처음 켜는 초기화. 질문 없이 프로젝트를 진단해 check 명령과 자동 검사(Stop 훅)를 켜고, 이후엔 /harness-init:make 하나로 기능을 만들게 안내한다. "하네스 세팅/초기화/깔아줘", "harness init", "검증 루프 만들어줘" 같은 요청에 사용한다.
---

# harness-init — 하네스 켜기

목표: 이 프로젝트에서 AI가 "다 됐어요"라고 말하기 전에 **스스로 확인하게** 만든다.

하네스는 **3단계**다. setup은 1단계만 하고, 2·3단계는 필요할 때 따라온다.

| 단계 | 하는 일 | 명령 |
| --- | --- | --- |
| **1. 켜기** | check 명령(타입·린트·테스트) + 자동 검사(끝내기 전에 check) + 문서 변경 알림 | `/harness-init:setup` (지금) |
| **2. 만들기** | 규칙 문서 → 규칙별 테스트 + 일부러 망가뜨려 보기 → 구현 → 화면 확인 → 독립 검사 → 보고서·영상 | `/harness-init:make <기능>` |
| **3. 넓히기** (선택) | AI 기능 품질 점수(eval) · PR마다 검사(CI) | `/harness-init:eval` · `/harness-init:ci` |

흐름: **진단 → 켜기 → 확인 → 안내.** 사용자에게 수준을 고르게 하지 않는다. 물어보는 건 "진단으로 알 수 없고, 틀리면 되돌리기 어려운 것"뿐이다.

---

## 1. 진단 (읽기 전용)

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/detect.mjs"
```

JSON으로 `stack`, `checkCmd`(추측), `watch`, `missing`(없는 검사), `ui`, `llm`, `e2e`, `ci`, `conf`가 나온다. 이걸 바탕으로 추가 확인:

- 추측한 `checkCmd`를 **실제로 한 번 돌린다** (시간도 잰다). 통과/실패/시간을 기록.
- 이미 있는 하네스: `.claude/settings.json`의 Stop 훅, `.claude/harness.conf`. 같은 일을 하는 Stop 훅이 있으면 둘 중 하나만 쓰자고 알리고 고르게 한다 (이때만 묻는다).
- git 상태: 미커밋 변경이 있으면 **내가 만들지 않은 변경은 건드리지 않는다**고 기억해 둔다.

## 2. 켜기

단계마다 무엇을 만들/바꿀지 한 줄로 말하고 진행한다.

### check 명령

- `checkCmd`가 이미 하나로 묶인 명령(`npm run check`, `make check` 등)이면 그대로 쓴다.
- 아니면 있는 검사를 **명령 하나**로 묶는다: Node면 `package.json`의 `"check"`, Python이면 `Makefile`의 `check:` 또는 `scripts/check.sh`. 묶었으면 conf의 `CHECK_CMD`도 그 명령으로.
- `missing`에 있는 검사(타입/린트/테스트)는 **추가를 제안만** 한다 (기본 설정 한 벌, 기존 설정은 갈아엎지 않음). 테스트 도구가 아예 없으면 추가한다 — 2단계(만들기)에 꼭 필요하다.

  | 언어 | 타입/정적 | 린트 | 테스트 |
  | --- | --- | --- | --- |
  | TypeScript | `tsc --noEmit` | ESLint | Vitest / node:test |
  | Python | mypy / pyright | ruff | pytest |
  | Go | go vet | golangci-lint | go test |
  | Rust | cargo check | clippy | cargo test |

- check가 **실패**하면 실패 목록을 보여주고 지금 고칠지 묻는다. 1~2분 넘게 걸리면 느린 부분(E2E 등)을 check에서 빼고 별도 명령으로 둔다.

### 자동 검사 (Stop 훅) + 문서 알림

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/detect.mjs" --write
```

`.claude/harness.conf`를 만든다 (이미 있으면 건드리지 않음). 위에서 check 명령을 새로 묶었으면 `CHECK_CMD`를 고친다.
이 파일이 있는 프로젝트에서만 플러그인의 훅이 돈다:
- 끝내기 전에 check를 돌려 실패하면 고칠 때까지 턴이 안 끝난다 (3번 연속 실패면 멈추고 사람에게 알림).
- 규칙 문서가 바뀌고 반영 안 됐으면 다음 대화에서 "반영할까요?"를 제안한다.

`docs/specs/`(또는 `SPECS_DIR`)에 **이미 규칙 문서가 있고 구현도 돼 있으면** 기준선을 잡는다: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/spec-status.sh" --mark-all`. 구현이 됐는지 불확실하면 이때만 묻는다.

### 프로젝트 지시문

`CLAUDE.md`(없으면 `AGENTS.md`, 둘 다 없으면 새로 `CLAUDE.md`)에 `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE-harness.md`의 내용을 `## 하네스` 절로 추가한다 (`{{CHECK_CMD}}` 채움). 비슷한 절이 있으면 합친다. `llm`이 false면 eval 줄은 뺀다.

### .gitignore

`.harness/reports/`와 `.harness/demo/`를 추가한다 (언제든 다시 만들 수 있다). 일지 `.harness/journal/`과 `.claude/harness-synced/`는 커밋 대상.

## 3. 확인

- `check` 한 번, `echo '{}' | CLAUDE_PROJECT_DIR="$PWD" bash "${CLAUDE_PLUGIN_ROOT}/scripts/verify.sh"` 한 번 → 둘 다 종료코드 0.
- `git status`로 이번 세팅이 만든/바꾼 파일 목록을 뽑는다.

## 4. 안내 (마지막 보고)

내부 용어(Stop 훅, fingerprint, 스냅샷, verifier)는 쓰지 않는다.

```
판정: ✅ 하네스 켜짐

켜진 것
- check: `npm run check` (12초) ✅ 통과
- 자동 검사: src/ tests/ 가 바뀐 턴은 끝내기 전에 check — ✅ 동작 확인
- 문서 알림: docs/specs/ 가 바뀌면 "반영할까요?" 제안

만든/바꾼 파일
- .claude/harness.conf, CLAUDE.md (하네스 절), .gitignore

사람이 확인할 것
- [ ] 린트가 없어요 — 추가할까요? (추천: ESLint 기본 설정)

이제 이렇게 쓰세요
- 기능 만들기·고치기: /harness-init:make 계산기   (또는 "계산기 만들어줘")
  · 문서가 없으면 초안부터, 자유롭게 쓴 계산기.md 도 OK
- 지금 상태: /harness-init:status
```

`ui`/`e2e`를 보고 한 줄 덧붙인다: 화면이 있는데 E2E가 없으면 "Playwright를 넣으면 기능마다 데모 영상도 만들어 드려요". `llm`이 true면 "AI 기능 품질 점수는 `/harness-init:eval`".

## 지켜야 할 것

- 커밋·푸시는 사용자가 요청할 때만. 커밋할 때는 이번에 만든 파일만 경로로 `git add`.
- 기존 설정·훅·워크플로를 덮어쓰지 않는다. 읽고 보강한다.
- 통과시키려고 테스트 기대값이나 린트 규칙을 몰래 낮추지 않는다.
- 막히면 추측으로 메우지 말고 무엇이 불확실한지 말하고 묻는다.
