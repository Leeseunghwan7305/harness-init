# Changelog

## 0.2.0 — 2026-11-26

### Stop 훅 보강 (`scripts/verify.sh`)
- **고친 뒤에도 다시 검사**: 이전에는 `stop_hook_active`면 무조건 통과시켜, 실패 후 Claude가 고친 결과를 검사하지 않았다. 이제 매번 다시 검사하고, `MAX_RETRIES`(기본 3)번 연속 실패하면 루프를 멈추고 사용자에게 알린다.
- **이번 상태 기준 변경 감지**: 감시 경로의 diff·미추적 파일로 상태 지문을 만들고, 마지막으로 통과한 상태와 같으면 건너뛴다. 미커밋 변경이 남아 있다고 대화만 한 턴마다 검사가 돌지 않는다.
- **시간 제한**: `TIMEOUT_SEC`(기본 180초). 넘기면 "느린 검사를 빼라"고 안내한다. 훅 자체 timeout은 600초.
- **테스트만 고쳐 통과시키기 경고**: 기존 테스트 파일만 수정되고 기능 코드는 그대로면 상태마다 한 번 경고한다 (`TEST_GUARD`, `TEST_PATTERN`). 새 테스트 추가만은 경고하지 않는다.
- `WATCH_PATHS`를 git pathspec으로 처리, 커밋이 없는 새 저장소 지원, 상태는 `.git/harness/`에 저장(작업 트리 깨끗).

### 레포
- MIT 라이선스, CHANGELOG, CI(shellcheck · 훅 테스트 · JSON 검사, ubuntu + windows).
- `tests/verify.test.sh` — 훅 시나리오 테스트.

## 0.1.0 — 2026-11-26

- 첫 공개: `/harness-init:setup` 초기 세팅 마법사, 단계별 명령(spec · rule-tests · visual · eval · ci · check-feature · status), `verifier` 에이전트, `harness-report` 스킬, Stop 훅, 템플릿.
