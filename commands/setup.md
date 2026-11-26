---
description: 이 프로젝트에 하네스를 처음 세팅한다 — 진단 → 수준 선택(기본/표준/전체) → 설치 → 확인 → 안내
argument-hint: '[선택: basic | standard | full]'
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, Agent, AskUserQuestion
---

`harness-init` 스킬을 불러 그 절차대로 이 프로젝트의 하네스를 초기 세팅한다.

- `$ARGUMENTS`가 `basic` / `standard` / `full` 이면 "세팅 수준" 질문은 건너뛰고 그 수준으로 진행한다 (각각 기본 1~2 / 표준 1~6·8~9 / 전체 1~10).
- 비어 있으면 진단 결과를 보여준 뒤 수준을 묻는다.
