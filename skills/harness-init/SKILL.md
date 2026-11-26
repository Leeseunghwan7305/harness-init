---
name: harness-init
description: 프로젝트에 AI 작업 검증 하네스를 처음 세팅하는 초기화 마법사. 프로젝트를 진단해 10단계 도입 현황을 보여주고, 사용자가 고른 수준(기본/표준/전체)만큼 check 명령·Stop 훅·규칙 문서·규칙별 테스트·verifier·eval·CI를 순서대로 깐다. "하네스 세팅/초기화/깔아줘", "harness init", "검증 루프 만들어줘" 같은 요청에 사용한다.
---

# harness-init — 하네스 초기 세팅

목표: 이 프로젝트에서 AI가 "다 됐어요"라고 말하기 전에 **스스로 확인하게** 만든다.
하네스 = 📏 기준 · 🔍 검사기 · 🔁 루프 · 🧾 보고. 하나라도 빠지면 안 돈다.

전체 흐름은 **진단 → 선택 → 설치 → 확인 → 안내** 다섯 단계다. 순서를 건너뛰지 않는다.

---

## 1. 진단 (읽기 전용)

아무것도 만들기 전에 프로젝트를 훑는다.

- 언어·패키지 매니저·모노레포 여부 (`package.json`, `pnpm-workspace.yaml`, `pyproject.toml`, `go.mod`, `build.gradle*`, `Cargo.toml` …)
- 이미 있는 타입검사·린트·테스트 도구와 명령, 지금 통과하는지 (한 번 돌려 본다. 오래 걸리면 시간도 잰다)
- 이미 있는 하네스: `.claude/settings.json`의 Stop 훅, `.claude/agents/`, `.claude/commands/`, `.claude/harness.conf`
- 화면이 있는가 (웹/앱 프레임워크) → 5단계 해당 여부
- LLM 호출 코드가 있는가 (`anthropic`, `openai`, `@ai-sdk`, `langchain` 등) → 7단계 해당 여부
- CI 설정 (`.github/workflows/`, `.gitlab-ci.yml`)
- git 상태: 미커밋 변경이 있으면 **내가 만들지 않은 변경은 건드리지 않는다**고 기억해 둔다

결과를 아래 표로 보여준다. `상태`는 ✅ 있음 / ⚠️ 일부 / ❌ 없음 / — 해당 없음, `근거`는 파일 경로.

| 순서 | 할 일 | 시간 | 효과 | 상태 | 근거 |
| --- | --- | --- | --- | --- | --- |
| 1 | 빠른 검사 + `check` 명령 | 반나절 | ★★★ | | |
| 2 | Stop 훅으로 루프 닫기 | 1시간 | ★★★ | | |
| 3 | 기능 하나의 규칙 문서 | 10분 | ★★ | | |
| 4 | 규칙별 테스트 + 망가뜨려 보기 | 1~2시간 | ★★★ | | |
| 5 | 캡처 검사 | 1시간 | ★★ | | |
| 6 | 독립 검사 서브에이전트 | 30분 | ★★ | | |
| 7 | eval (AI 기능 있을 때만) | 반나절 | ★★★ | | |
| 8~9 | 보고 형식 + 명령 파일 | 30분 | ★ 편의 | | |
| 10 | CI | 반나절 | ★★ | | |

> 6·8·9는 이 플러그인에 `verifier` 에이전트·`harness-report` 스킬·`/harness-init:check-feature`로 이미 들어 있다. 설치만 하면 ✅.

## 2. 선택

AskUserQuestion으로 **두 가지만** 묻는다 (진단으로 알 수 있는 건 묻지 않는다).

1. **세팅 수준**
   - **기본 (1~2단계)** (추천) — check 명령 + Stop 훅. 가장 싸고 체감이 크다. 여기서 멈춰도 된다.
   - **표준 (1~6, 8~9)** — 기본 + 첫 기능 하나로 규칙 문서·테스트·캡처·독립 검사 한 바퀴.
   - **전체 (1~10)** — 표준 + eval(AI 기능 있으면) + CI.
2. **첫 기능** (표준/전체일 때만) — 진단에서 찾은 주요 기능 2~3개를 후보로 제시. "기능 하나로 한 바퀴 돌려 보고 넓힌다"가 원칙이다.

이미 ✅인 단계는 기본으로 건너뛴다. 덮어쓰지 않는다.

## 3. 설치

고른 단계만, **순서대로** 진행한다. 단계마다 무엇을 만들/바꿀지 먼저 한 줄로 말하고 진행한다.

### 1단계 — 빠른 검사 + `check`

| 언어 | 타입/정적 | 린트 | 테스트 |
| --- | --- | --- | --- |
| TypeScript | `tsc --noEmit` | ESLint | Vitest / Jest / node:test |
| Python | mypy / pyright | ruff | pytest |
| Go | go vet | golangci-lint | go test |
| Java/Kotlin | 컴파일러 | ktlint / Checkstyle | JUnit |
| Rust | cargo check | clippy | cargo test |

- 없는 도구만 추가한다. 기존 설정을 갈아엎지 않는다.
- 셋을 **명령 하나**로 묶는다: Node면 `package.json`의 `"check"`, Python이면 `Makefile`의 `check:` 또는 `scripts/check.sh`.
- 중요한 correctness 규칙이 `warn`이면 `error`로 올리자고 제안한다 (AI는 warn을 무시하기 쉽다).
- `check`를 돌려 통과시킨다. 기존 실패가 많으면 목록을 보여주고 지금 고칠지 묻는다.
- 1~2분 넘으면 느린 부분(E2E 등)은 check에서 빼고 별도 명령으로 둔다.

### 2단계 — Stop 훅

이 플러그인에 Stop 훅이 내장돼 있고 **`.claude/harness.conf`가 있을 때만** 동작한다.
`${CLAUDE_PLUGIN_ROOT}/templates/harness.conf`를 `.claude/harness.conf`로 복사해 채운다.

- `CHECK_CMD` = 1단계 명령, `WATCH_PATHS` = 소스 경로들.
- 프로젝트에 같은 일을 하는 Stop 훅이 이미 있으면 **둘 중 하나만** 쓰자고 알리고 사용자가 고르게 한다.
- 확인: `echo '{}' | CLAUDE_PROJECT_DIR="$PWD" bash "${CLAUDE_PLUGIN_ROOT}/scripts/verify.sh"` → 종료코드 0.
- 같은 설정으로 **문서 sync 알림 훅**(UserPromptSubmit)도 켜진다 — 규칙 문서가 바뀌고 반영 안 됐으면 Claude가 "sync 할까요?"를 제안한다. 원치 않으면 `SPEC_REMINDER=0`.
- `docs/specs/`(또는 `SPECS_DIR`)에 **이미 규칙 문서가 있고 구현도 돼 있다면**, 기준선을 잡을지 묻는다: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/spec-status.sh" --mark-all`. 안 잡으면 전부 "새 문서"로 보여 첫 sync가 전체 재검증이 된다.

### 3~5단계 — 첫 기능 한 바퀴 (표준/전체)

첫 기능으로 아래 명령 파일의 절차를 그대로 따른다 (`${CLAUDE_PLUGIN_ROOT}/commands/` 에서 읽는다).
- 3: `spec.md` → `docs/specs/<기능>.md`. 추측한 규칙은 `(확인 필요)` 표시 후 **사용자 확인을 받고** 다음으로.
- 4: `rule-tests.md` → 규칙별 테스트 + 망가뜨려 보기.
- 5: `visual.md` → 화면이 없으면 건너뛰고 "해당 없음"으로 기록.

### 6·8·9단계 — 플러그인 내장

- `verifier` 서브에이전트로 첫 기능을 검사해 동작을 보여준다 (구현 설명은 넘기지 않는다).
- 결과를 `harness-report` 형식으로 보고해 형식을 보여준다.

### 7단계 — eval (전체 + AI 기능 있을 때)

`eval.md` 절차. 골든 세트는 최소 10개부터, 정답은 사용자 검토.

### 10단계 — CI (전체)

`ci.md` 절차. `${CLAUDE_PLUGIN_ROOT}/templates/ci/harness.yml` 기반. CI에는 결정적인 검사만.

### 공통 — 프로젝트 지시문에 하네스 규칙 추가

`CLAUDE.md`(없으면 `AGENTS.md`, 둘 다 없으면 새로 `CLAUDE.md`)에 `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE-harness.md`의 내용을 `## 하네스` 절로 추가한다. 이미 비슷한 절이 있으면 합친다. 고른 수준에 없는 단계 줄은 뺀다.

### 공통 — 제작 과정 보고서 준비 (표준/전체)

- `.gitignore`에 `.harness/reports/`를 추가한다 (보고서는 언제든 다시 만들 수 있다). 일지 `.harness/journal/`은 커밋 대상.
- 첫 기능 한 바퀴를 돌 때 `rule-tests`의 일지 규칙대로 기록하고, 끝에 `node "${CLAUDE_PLUGIN_ROOT}/scripts/report.mjs" <기능>`으로 보고서를 만들어 경로를 안내한다.

## 4. 확인

- `check` 한 번, Stop 훅 스크립트 한 번 돌려 둘 다 통과하는지 본다.
- `git status`로 이번 세팅이 만든 파일 목록을 뽑는다.

## 5. 안내 (마지막 보고)

`harness-report` 형식으로:

```
판정: ✅ 하네스 세팅 완료 (기본 수준)

켜진 것
- 1 check: `npm run check` (12초) ✅ 통과
- 2 Stop 훅: .claude/harness.conf — src/ tests/ 변경 시 ✅ 동작 확인
- 6·8·9 verifier · harness-report · /harness-init:check-feature ✅ 플러그인 내장

만든/바꾼 파일
- package.json (check 스크립트), .claude/harness.conf, CLAUDE.md (하네스 절)

사람이 확인할 것
- [ ] 기존 린트 경고 23건을 error로 올릴지

다음에 할 일
- /harness-init:spec <기능>  → 3단계부터 한 기능씩
- 이후 수정은 문서를 고치고 /harness-init:sync
- /harness-init:status       → 언제든 현황 점검
```

## 지켜야 할 것

- 커밋·푸시는 사용자가 요청할 때만. 커밋할 때는 이번에 만든 파일만 경로로 `git add`.
- 기존 설정·훅·워크플로를 덮어쓰지 않는다. 읽고 보강한다.
- 통과시키려고 테스트 기대값이나 린트 규칙을 몰래 낮추지 않는다.
- 막히면 추측으로 메우지 말고 무엇이 불확실한지 말하고 묻는다.
