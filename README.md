# harness-init

어느 프로젝트든 **처음 하네스를 세팅**하는 Claude Code 플러그인.
AI가 "다 됐어요"라고 말하기 전에 스스로 확인하게 만든다.

하네스 = 📏 기준 · 🔍 검사기 · 🔁 루프 · 🧾 보고

## 설치

```text
/plugin marketplace add Leeseunghwan7305/harness-init
/plugin install harness-init@harness-init
```

## 쓰는 법 — 명령 3개

```text
/harness-init:setup            처음 한 번. 질문 없이 진단해서 켠다
/harness-init:make 계산기       만들기 · 고치기 전부 (또는 그냥 "계산기 만들어줘")
/harness-init:status           지금 상태와 다음 할 일
```

### 만들기

```text
1. 계산기.md 를 아무렇게나 쓴다        "숫자 두 개 더하기 빼기. 0으로 나누면 오류 표시."
2. /harness-init:make 계산기.md     → 글을 규칙 목록(R1, R2 …)으로 정리 → 애매한 것만 한 번 물어봄
                                    → 규칙별 테스트 → 구현 → 일부러 망가뜨려 보기 → 화면 확인 → 독립 검사
                                    → 보고서 + (E2E 있으면) 데모 영상
```

문서가 없으면 초안부터 쓰고, 이미 규칙 문서가 있으면 바로 만든다.

### 고치기

```text
1. docs/specs/계산기.md 수정          (- R10 % 버튼은 100으로 나눈다  추가)
2. /harness-init:make 계산기          → 바뀐 규칙만 다시 테스트 → 구현 → 검사 → 보고서
   (아무 말이나 걸어도 Claude 가 "반영할까요?" 하고 먼저 물어본다)
```

- 지운 규칙 · `(확인 필요)` 규칙 · 충돌은 진행 전에 묻는다.
- 규칙 번호는 **재사용하지 않는다** (R3을 지웠으면 다음 규칙은 R11). 번호가 곧 테스트 이름이다.

## 3단계

| 단계 | 하는 일 | 명령 |
| --- | --- | --- |
| **1. 켜기** | check 명령(타입 · 린트 · 테스트) + 끝내기 전 자동 검사 + 문서 변경 알림 | `setup` |
| **2. 만들기** | 규칙 문서 → 규칙별 테스트 + 망가뜨려 보기 → 구현 → 화면 확인 → 독립 검사 → 보고서 · 영상 | `make` |
| **3. 넓히기** (선택) | AI 기능 품질 점수(eval) · PR마다 검사(CI) | `eval` · `ci` |

<details>
<summary>고급 — make 가 안에서 쓰는 명령들 (따로 불러도 된다)</summary>

| 명령 | 하는 일 |
| --- | --- |
| `spec <기능>` | 규칙 문서만 쓰기 |
| `check-feature <기능>` | 새 기능 처음부터 (테스트 → 구현 → 검사 → 보고) |
| `sync [기능]` | 문서에서 바뀐 규칙만 반영 |
| `rule-tests <기능>` | 규칙별 테스트 + 망가뜨려 보기만 |
| `visual <기능>` | 화면 캡처 확인만 (최대 3회) |
| `report <기능>` | 제작 과정 보고서만 |
| `demo <기능>` | 데모 영상만 |

`verifier` 에이전트(독립 검사, 읽기 전용) · `harness-report` 스킬(보고 형식) · `harness-make` 스킬("만들어줘"를 make 흐름으로)도 들어 있다.
</details>

### setup 이 알아서 채우는 것

`scripts/detect.mjs`가 프로젝트를 보고 `.claude/harness.conf`를 채운다 (있으면 안 건드림).

| 프로젝트 | check 명령 (추측) |
| --- | --- |
| Node (npm · pnpm · yarn · bun) | `check` 스크립트가 있으면 그것, 없으면 있는 `typecheck` · `lint` · `test`를 묶음 |
| Python (uv · poetry · pip) | `ruff` · `mypy` · `pytest` 중 쓰는 것 |
| Go · Rust · Gradle · Maven | `go vet + go test` · `cargo clippy + test` · `gradle check` · `mvn verify` |
| `Makefile`에 `check:` | `make check` 우선 |

추측한 명령은 실제로 한 번 돌려 확인하고, 없는 검사(린트 등)는 추가를 제안한다.

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
- `make`는 끝날 때 보고서(와 가능하면 영상)를 자동으로 만든다.

## 데모 영상 — `/harness-init:demo <기능>`

규칙 번호가 붙은 E2E 테스트(`test('R2: 2 + 3 = 5', …)`)를 **녹화**해서 만든 기능을 영상으로 보여준다.

```text
.harness/demo/<기능>/
  index.html     규칙 순서대로 이어 재생 (자막 · 목록 · 속도 조절 · 장면마다 결과 화면 1.2초 유지)
  clips/*.webm   규칙별 장면
  demo.mp4       ffmpeg 가 있으면 한 편으로 합친 영상 (자막 트랙 포함, 장면마다 결과 화면 1.2초 유지)
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
bash tests/detect.test.sh      # 프로젝트 진단 · conf 자동 채우기 테스트
claude plugin validate .       # 매니페스트 검사

# 명령 문서(프롬프트)를 고쳤으면 — Claude 가 여전히 절차대로 움직이는지 (evals/README.md)
claude plugin eval . --tag smoke --scaffold --ablation none --trust-plugin -j 4
```

CI가 PR마다 shellcheck · 훅 테스트(ubuntu + windows) · JSON 검사를 돌린다. 변경은 `CHANGELOG.md`에 기록하고 `plugin.json`의 version을 올린다.

## 라이선스

MIT

## 흔한 함정 5가지

1. AI가 테스트를 고쳐서 통과시킴 → verifier가 "기대값만 바뀐 diff"를 의심한다. 망가뜨려 보기로 확인.
2. 처음부터 전부 자동화하려다 지침 → 켜기만 하고, 기능 하나씩 make 로 넓힌다.
3. 기준 문서가 낡음 → 기획이 바뀌면 문서부터.
4. 느린 검사를 훅에 넣음 → 훅에는 check만.
5. "통과"만 보고 믿음 → 항상 "어디까지 확인했는지"를 같이 받는다.
