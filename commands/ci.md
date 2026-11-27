---
description: "(3단계 넓히기) check 명령을 PR마다 도는 CI(GitHub Actions 등)로 올린다"
argument-hint: '[선택: github | gitlab]'
allowed-tools: Read, Edit, Write, Grep, Glob, Bash
---

하네스의 결정적인 검사를 CI에 올린다.

## 순서

1. CI 종류를 정한다: `$ARGUMENTS` → 없으면 `.github/` / `.gitlab-ci.yml` 존재 여부로 판단, 둘 다 없으면 GitHub Actions.
2. 이미 있는 워크플로가 있으면 **읽고 보강**한다. 덮어쓰지 않는다.
3. GitHub Actions면 `${CLAUDE_PLUGIN_ROOT}/templates/ci/harness.yml`을 `.github/workflows/harness.yml`로 복사해 프로젝트에 맞게 고친다:
   - 런타임 설정(Node/pnpm, Python/uv 등)과 의존성 설치
   - `.claude/harness.conf`의 `CHECK_CMD`와 **같은 명령**을 돌린다 (로컬 훅과 CI가 같은 한 줄)
   - E2E·캡처 비교는 관련 경로가 바뀐 PR에서만 도는 별도 job (`paths` 필터)
   - 실패 시 테스트 리포트·캡처를 artifact로 업로드
4. YAML 문법을 검사한다 (가능하면 `actionlint`, 없으면 최소한 파싱 확인).

## 원칙

- **모든 PR**: 빠른 검사(check).
- **관련 파일 바뀐 PR만**: E2E, 캡처 비교.
- **CI에 넣지 않는 것**: AI 판단(캡처 보고 고치기, verifier, eval). 비용이 들고 결과가 매번 달라진다 — 로컬에서 한다.
- 비밀값이 필요한 단계는 `secrets`로만. 워크플로 파일에 키를 쓰지 않는다.

커밋·푸시는 사용자가 요청할 때만 한다.
