---
description: 하네스 현황 — 3단계(켜기 · 만들기 · 넓히기) 중 어디까지 됐는지, 기능별 상태, 다음 할 일 하나
allowed-tools: Read, Grep, Glob, Bash
---

읽기 전용으로 현재 프로젝트를 훑어 현황을 보여준다. 아무것도 고치지 않는다.

## 점검

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/detect.mjs"
```

| 단계 | 무엇으로 판단하나 |
| --- | --- |
| **1. 켜기** | `.claude/harness.conf`가 있고 `ENABLED=1`인가, `CHECK_CMD`가 지금 통과하는가 (한 번 돌린다) |
| **2. 만들기** | `docs/specs/`(또는 `SPECS_DIR`)의 문서마다 `spec-status.sh --state <이름>` 결과, 테스트 이름에 그 R번호가 있는가 |
| **3. 넓히기** (선택) | eval: `llm`이 true일 때 골든 세트·채점 스크립트가 있는가 (false면 "해당 없음"). CI: `.github/workflows/`에서 check를 도는가 |

## 출력

1. 단계 표: ✅ 됨 / ⚠️ 일부 / ❌ 안 됨 / — 해당 없음, 근거(파일 경로).
2. 기능 표: 기능 · 상태(문서대로 반영됨 / 문서 바뀜 · 반영 전 / 아직 안 만듦 / 자유 글 · 규칙 전) · 규칙 수 · 보고서 경로(있으면).
3. **다음에 할 일 1개**:
   - 1단계가 안 됐으면 무조건 `/harness-init:setup`.
   - 바뀐 문서가 있으면 `/harness-init:make <그 기능>`.
   - 없으면 다음 기능을 `/harness-init:make <기능>`으로, 또는 (해당되면) 3단계.

내부 용어(Stop 훅, sync, 스냅샷, verifier)는 쓰지 않는다.
