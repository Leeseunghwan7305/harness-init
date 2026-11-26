# Changelog

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
