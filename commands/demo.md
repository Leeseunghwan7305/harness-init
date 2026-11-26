---
description: 만든 기능을 영상으로 — 규칙 번호가 붙은 E2E 테스트를 녹화해 규칙별 장면 + 자막 재생 페이지(+ MP4)를 만든다
argument-hint: <기능이름> [-- playwright 인자]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

`$ARGUMENTS` 기능의 데모 영상을 만든다. 영상은 **"규칙대로 동작한다"는 증거**다 — 테스트가 실제로 화면을 조작하는 모습을 그대로 녹화한다.

## 1. 준비 확인

- `playwright.config.*`가 있고, 테스트 이름에 규칙 번호가 붙은 E2E 테스트(`test('R2: …')`)가 있어야 한다.
  - 없으면: 화면 있는 기능이면 `/harness-init:rule-tests`로 E2E를 먼저 만들자고 제안하고 멈춘다. 화면이 없는 기능(API·CLI)이면 영상 대신 제작 과정 보고서를 안내한다.
- 브라우저가 없으면 `npx playwright install chromium`을 안내한다.

## 2. 녹화 + 조립

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/demo.mjs" <기능>                    # 기본: 동작 500ms씩 느리게
node "${CLAUDE_PLUGIN_ROOT}/scripts/demo.mjs" <기능> --slowmo 800       # 더 천천히
node "${CLAUDE_PLUGIN_ROOT}/scripts/demo.mjs" <기능> -- e2e/calc.spec.ts # 특정 파일만
```

- 프로젝트 Playwright 설정은 그대로 두고, 녹화 옵션만 덮어쓴 설정을 `.harness/demo/<기능>/`에 따로 만들어 돌린다.
- ffmpeg가 있으면 `demo.mp4`(자막 트랙 포함)도 만든다. 없으면 건너뛰고 재생 페이지만 만든다.
- 테스트가 실패해도 영상은 만든다 — 실패 장면은 ❌로 표시된다. 실패가 있으면 그 사실을 먼저 알린다.

## 3. 확인 (직접 본다)

- `.harness/demo/<기능>/index.html`을 열어(또는 Playwright MCP로) **처음 몇 장면을 실제로 확인**한다: 영상이 재생되는지, 자막이 규칙과 맞는지, 화면이 너무 빨리 지나가지 않는지.
- 장면이 너무 짧으면(1초 미만) `--slowmo`를 올려 다시 만든다.

## 4. 마무리

- 제작 과정 보고서를 다시 만들어 영상 섹션을 붙인다: `node "${CLAUDE_PLUGIN_ROOT}/scripts/report.mjs" <기능>`
- 사용자에게 재생 페이지 경로, (있으면) MP4 경로, 장면 수와 통과 수를 알려준다.
- `.harness/demo/`는 크기가 커서 `.gitignore`를 권한다 (언제든 다시 만들 수 있다).
