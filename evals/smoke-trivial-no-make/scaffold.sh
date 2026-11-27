#!/usr/bin/env bash
set -e
git init -q
mkdir -p .claude docs/specs
printf '%s\n' '{ "name": "calc", "type": "module", "scripts": { "test": "node --test" } }' > package.json
printf '%s\n' 'CHECK_CMD="npm test"' 'WATCH_PATHS=""' > .claude/harness.conf
printf '%s\n' '# calc' '' 'A tiny calculator. See teh docs.' > README.md
printf '%s\n' '# 계산기' '' '- R1 2 + 3 은 5' > docs/specs/계산기.md
