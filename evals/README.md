# harness-init eval

명령 문서(프롬프트)를 고친 뒤 **Claude가 여전히 절차대로 움직이는지** 확인하는 `claude plugin eval` 묶음이에요.
스크립트는 `tests/*.test.sh`가 확인하고, 여기서는 명령 문서를 따르는 Claude의 행동을 확인해요.

## 케이스

| 케이스 | 층 | 확인하는 것 |
| --- | --- | --- |
| `smoke-make-trigger` | smoke | 하네스가 켜진 프로젝트에서 "계산기.md 보고 만들어줘" → `harness-make` 스킬 발동, 자유 글이면 규칙 정리부터 |
| `smoke-trivial-no-make` | smoke | 오타 수정 같은 사소한 요청엔 make 흐름을 안 탄다 |
| `smoke-no-conf` | smoke | 하네스가 꺼진 프로젝트에선 평소처럼 처리하고 하네스를 마음대로 켜지 않는다 |
| `smoke-changed-only` | smoke | 문서가 바뀌면 바뀐 규칙(~R2 -R3 +R4)만 다루고 삭제는 먼저 묻는다 |
| `smoke-setup-conflict` | smoke | 기존 Stop 훅이 있으면 덮어쓰지 않고 고르게 묻는다. 수준은 묻지 않는다 |
| `e2e-freeform-build` | e2e | 자유 글 → 규칙 · 원문 유지 · 망가뜨려 보기 일지 · 독립 검사 · 반영 표시 · 보고서 · 내부 용어 안 씀 (결과 파일로 채점) |
| `e2e-change` | e2e | 바뀐 규칙만 실제로 반영: R4 테스트·구현 생김, R3 테스트 지워짐, R1 테스트 그대로, 반영 표시 갱신 |

- **smoke**: 읽기 전용으로 돌려 "무엇을 어떤 순서로 할지"를 채점해요. 어디서든 돌고(Windows 포함) 싸요. 케이스당 약 $0.1~0.2예요.
- **e2e**: 실제로 코드를 쓰고 명령을 돌려요. Bash를 가둘 샌드박스가 필요해서 **Linux · macOS · WSL2에서만** 돌아가요. 케이스당 약 $1~2예요.

## 돌리기

```bash
# smoke — 명령 문서를 고칠 때마다 (약 $1.5, 1~2분)
claude plugin eval . --tag smoke --scaffold --ablation none --trust-plugin -j 4

# e2e — 릴리스 전에 (Linux / macOS / WSL2)
claude plugin eval . --tag e2e --scaffold --ablation none --trust-plugin --allow-tools Bash Write Edit
```

- `--scaffold`: 케이스마다 `scaffold.sh`로 임시 프로젝트를 만들어요(직접 쓴 스크립트라서 켜요).
- `--ablation none`: 플러그인 없는 비교 실행을 건너뛰어 비용을 반으로 줄여요.
- 결과는 `evals/results/`에 쌓이고 git에는 올라가지 않아요.
- 케이스 하나만 돌리려면 `--case <이름>`을 써요(여러 번 주면 마지막 것만 적용돼요).

## 믿을 만한가

- 플러그인을 일부러 망가뜨려 확인했어요. `harness-make` 스킬 설명을 망가뜨리면 `smoke-make-trigger`가 실패해요. make 절차를 "문서 바뀜 → 처음부터 다시"로 바꾸면 `smoke-changed-only`가 2번 중 1번 실패해요.
- Claude의 행동은 확률적이라서 한 번 통과가 보장은 아니에요. 케이스마다 `runs: 2`로 두고, 하나라도 실패하면 전체를 실패로 봐요(기본 기준 1.0).
- e2e 채점은 "아무것도 안 하면 실패"하는지 확인했어요. 준비만 된 상태에서는 6개 중 "R1 그대로"만 통과해요.
