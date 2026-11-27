---
description: "(고급 — 보통은 make) 화면 상태를 캡처해 직접 보고, 규칙 문서와 다르거나 어색한 곳을 고친다 (최대 3회)"
argument-hint: <기능이름> [URL]
allowed-tools: Read, Edit, Write, Grep, Glob, Bash
---

테스트는 "동작"을 보지 "모양"은 못 본다. `$ARGUMENTS` 기능의 화면을 캡처해 눈으로 검사한다.

## 순서

1. `docs/specs/<기능>.md`를 읽고, 캡처할 **화면 상태 목록**을 만든다 (기본 / 입력 중 / 오류 / 로딩 / 빈 상태 / 모바일 폭 등 — 규칙마다 최소 하나).
2. 개발 서버가 떠 있는지 확인한다. 없으면 프로젝트의 dev 명령으로 띄운다 (백그라운드).
3. 상태마다 캡처한다:
   - Playwright MCP 도구가 있으면 그것으로 이동·조작·스크린샷.
   - 없으면 Playwright 스크립트(`page.screenshot`)로 `artifacts/screens/<기능>/<상태>.png`에 저장.
4. 캡처를 **Read로 직접 열어 본다.** 확인할 것: 잘린 버튼·텍스트, 겹침, 대비 부족, 가로 스크롤, 규칙 문서와 다른 문구, 다크모드.
   - `docs/specs/<기능>/` 이나 `design/`에 시안 PNG(Figma 내보내기)나 이전에 커밋한 기준 캡처가 있으면 나란히 비교한다.
5. 문제를 고치고 다시 캡처한다. **최대 3회.** 3번 안에 안 맞으면 멈추고 "기준이 애매하다"고 보고한다 — 무엇이 애매한지 적는다.

## 마무리

- 마음에 드는 캡처는 기준 캡처로 커밋할지 사용자에게 묻는다. 다음부터는 그게 시안이다.
- Playwright를 쓰는 프로젝트면 `toHaveScreenshot` 픽셀 비교 테스트 추가를 제안한다 (실수로 바뀐 곳을 자동으로 잡음).
- 보고는 `harness-report` 형식: 상태별 ✅/❌, 고친 것, 캡처 경로, 사람이 볼 것.

## 일지 남기기

캡처마다 `bash "${CLAUDE_PLUGIN_ROOT}/scripts/journal.sh" <기능> shot R2 artifacts/screens/<기능>/<상태>.png` — 보고서에 이미지가 들어간다. 고친 것은 `fix`로 기록한다.
