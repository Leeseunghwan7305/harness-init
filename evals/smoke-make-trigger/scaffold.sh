#!/usr/bin/env bash
set -e
git init -q
mkdir -p .claude
printf '%s\n' '{ "name": "calc", "type": "module", "scripts": { "test": "node --test" } }' > package.json
printf '%s\n' 'CHECK_CMD="npm test"' 'WATCH_PATHS=""' > .claude/harness.conf
cat > 계산기.md <<'MD'
# 계산기

숫자 두 개랑 연산자(+ - * /)를 받아서 결과를 돌려주는 함수 하나 만들어줘.
0으로 나누면 에러 던지고, 숫자가 아닌 게 들어와도 에러.
MD
