# Changelog

## 0.6.0 — 2026-11-27

### 더 쉽게 — 명령 3개, 3단계
- **`/harness-init:make <기능 | 문서>`**: 만들기·고치기를 한 명령으로. 문서 상태를 보고 스스로 고른다 — 없음 → 초안, 자유 글 → 규칙 정리, 새 규칙 → 처음부터, 바뀜 → 바뀐 규칙만, 그대로 → 끝. 보고서·데모 영상은 묻지 않고 만든다. 마지막 보고에서 내부 용어(verifier · sync · 스냅샷 · Stop 훅)를 쓰지 않는다.
- **자유 문서 지원**: 규칙 줄 없이 아무렇게나 쓴 `계산기.md`도 OK — 글은 그대로 두고 `## 규칙` 절을 붙여 확인받는다. 루트 등 `docs/specs` 밖 문서는 옮겨 온다.
- **`harness-make` 스킬**: 하네스가 켜진 프로젝트에서 "계산기 만들어줘"라고 말해도 make 흐름을 탄다.
- **10단계 → 3단계** (켜기 · 만들기 · 넓히기). setup의 기본/표준/전체 선택 제거 — 질문 없이 켜기만 하고, 나머지는 make가 필요할 때 한다. `status`도 3단계 기준.
- **`scripts/detect.mjs`**: Node(npm·pnpm·yarn·bun) · Python(uv·poetry) · Go · Rust · Gradle · Maven · Makefile을 보고 check 명령·감시 경로를 추측해 `harness.conf`를 채운다 (있으면 안 건드림). 화면·E2E·LLM·CI 여부도 진단.
- `spec-status.sh --state <이름>`: missing / freeform / new / changed / synced.
- 문서 변경 알림이 `make`를 제안. 나머지 명령은 "고급"으로 남김 (그대로 동작).

### 고침
- `spec-status.sh`에 문서를 절대 경로로 넘기면 이름을 못 뽑아 `--mark`가 엉뚱한 스냅샷을 만들던 버그.

## 0.5.1 — 2026-11-26

### 고침
- **macOS 기본 bash 3.2에서 Stop 훅·sync 알림이 조용히 꺼지던 문제**: `. <(tr -d '\r' <conf)`가 bash 3.2에서는 아무것도 읽지 않아 `CHECK_CMD`가 비어 보이고 검사를 건너뛰었다 (exit 0이라 통과처럼 보임). `verify.sh` · `spec-reminder.sh` · `spec-status.sh`를 `eval "$(tr -d '\r' <conf)"`로 바꿈. CRLF 제거 동작은 그대로.
- CI 훅 테스트 매트릭스에 `macos-latest` 추가 — `/bin/bash`(3.2)로 돌려 같은 종류의 회귀를 잡는다.

## 0.5.0 — 2026-11-26

### 데모 영상
- **`/harness-init:demo <기능>`** (`scripts/demo.mjs`): 규칙 번호가 붙은 E2E 테스트를 Playwright로 녹화 → 규칙별 장면(`clips/*.webm`) + 이어 재생 페이지(`index.html`: 자막 · 목록 · 속도 · 장면마다 결과 화면 1.2초 유지) + ffmpeg가 있으면 `demo.mp4`(자막 트랙).
- 프로젝트 Playwright 설정 위에 녹화 옵션만 덮어쓴 설정을 따로 만들어 실행 (설정 파일 수정 없음). 프로젝트에 설치된 Playwright CLI를 node로 직접 실행해 Windows에서도 셸 없이 동작.
- 제작 과정 보고서에 "데모 영상" 섹션, 일지에 `video` 이벤트.
- 실제 Playwright 1.65 + Chromium으로 계산기 예제 6개 규칙 녹화·재생 확인 (로컬). CI는 가짜 리포트로 조립 단계만 검사.

## 0.4.0 — 2026-11-26

### 제작 과정 보고서
- **`/harness-init:report <기능>`** → `.harness/reports/<기능>.html`: 판정 · 규칙별 결과와 과정 아이콘 · 확인 깊이 · 망가뜨려 보기 · 사람 확인 목록 · 타임라인(일지 + 커밋 + 자동 검사) · 캡처(파일 내장). 라이트/다크, 모바일 대응.
- **`scripts/journal.sh`**: 작업 일지(`.harness/journal/<기능>.jsonl`) 기록. `rule-tests` · `visual` · `sync` · `check-feature`가 단계마다 기록하고, `sync` · `check-feature`는 끝에 보고서를 만든다.
- Stop 훅이 검사 결과를 `.git/harness/checks.jsonl`에 기록 (로컬 전용).
- 망가뜨려도 통과한 규칙은 "통과"로 세지 않고 "⚠️ 통과 (테스트 부실)"로 표시.

### 고침
- Stop 훅 변경 감지에서 `.harness/`(일지)와 `.claude/harness-synced/`(스냅샷)를 제외 — 일지 기록만으로 검사가 다시 돌지 않는다.

## 0.3.0 — 2026-11-26

### 문서 중심 흐름 — "코드 짜줘" 대신 "문서 고치고 sync"
- **`/harness-init:sync`**: 규칙 문서를 마지막으로 반영한 스냅샷(`.claude/harness-synced/`)과 비교해 **바뀐 규칙만**(+추가 / ~수정 / -삭제) 테스트 → 구현 → 검사 → 보고. 삭제·`(확인 필요)`·충돌은 먼저 묻는다. 모두 ✅인 문서만 반영 완료로 표시.
- **UserPromptSubmit 알림 훅**(`scripts/spec-reminder.sh`): 문서 변경이 반영 안 됐으면 Claude가 응답 끝에 "sync 할까요?"를 제안. 같은 상태는 한 번만 알림. `SPEC_REMINDER=0`으로 끔.
- `scripts/spec-status.sh`: 규칙 단위 diff (번호순, 설명 문단·공백·CRLF·`**R1**:` 표기 차이 무시, 하위 폴더·문서 삭제 감지, `--mark`·`--mark-all`).
- 설정 추가: `SPECS_DIR`(기본 `docs/specs`), `SPEC_REMINDER`.
- `check-feature`가 끝나면 반영 완료 표시, `status`가 미반영 변경 표시, `spec` 문서에 "번호 재사용 금지" 규칙.

### 고침
- 테스트 도우미 `ok A && B`가 첫 조건만 판정하던 버그 — 0.2.0의 `verify.test.sh` 다중 조건 검사가 사실상 첫 조건만 보고 있었다. 망가뜨려 보기로 두 테스트 파일 모두 실제로 실패하는지 확인.

## 0.2.0 — 2026-11-26

### Stop 훅 보강 (`scripts/verify.sh`)
- **고친 뒤에도 다시 검사**: 이전에는 `stop_hook_active`면 무조건 통과시켜, 실패 후 Claude가 고친 결과를 검사하지 않았다. 이제 매번 다시 검사하고, `MAX_RETRIES`(기본 3)번 연속 실패하면 루프를 멈추고 사용자에게 알린다.
- **이번 상태 기준 변경 감지**: 감시 경로의 diff·미추적 파일로 상태 지문을 만들고, 마지막으로 통과한 상태와 같으면 건너뛴다. 미커밋 변경이 남아 있다고 대화만 한 턴마다 검사가 돌지 않는다.
- **시간 제한**: `TIMEOUT_SEC`(기본 180초). 넘기면 "느린 검사를 빼라"고 안내한다. 훅 자체 timeout은 600초.
- **테스트만 고쳐 통과시키기 경고**: 기존 테스트 파일만 수정되고 기능 코드는 그대로면 상태마다 한 번 경고한다 (`TEST_GUARD`, `TEST_PATTERN`). 새 테스트 추가만은 경고하지 않는다.
- `WATCH_PATHS`를 git pathspec으로 처리, 커밋이 없는 새 저장소 지원, 상태는 `.git/harness/`에 저장(작업 트리 깨끗).

### 레포
- MIT 라이선스, CHANGELOG, CI(shellcheck · 훅 테스트 · JSON 검사, ubuntu + windows).
- CI 템플릿·레포 CI: actions v5, Node 22 (Node 20 지원 종료).
- `tests/verify.test.sh` — 훅 시나리오 테스트.

## 0.1.0 — 2026-11-26

- 첫 공개: `/harness-init:setup` 초기 세팅 마법사, 단계별 명령(spec · rule-tests · visual · eval · ci · check-feature · status), `verifier` 에이전트, `harness-report` 스킬, Stop 훅, 템플릿.
