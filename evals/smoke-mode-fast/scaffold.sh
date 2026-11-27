#!/usr/bin/env bash
set -e
git init -q
mkdir -p .claude/harness-synced docs/specs src tests
printf '%s\n' '{ "name": "calc", "type": "module", "scripts": { "test": "node --test" } }' > package.json
printf '%s\n' 'CHECK_CMD="npm test"' 'WATCH_PATHS=""' 'MODE=auto' > .claude/harness.conf
printf '%s\n' '# 계산기' '' '- R1 add(2, 3) 은 5' '- R2 add 에 숫자가 아닌 값이 오면 에러' > .claude/harness-synced/계산기.md
printf '%s\n' '# 계산기' '' '- R1 add(2, 3) 은 5' '- R2 add 에 숫자가 아닌 값이 오면 에러' '- R3 sub(5, 3) 은 2' > docs/specs/계산기.md
cat > src/calc.js <<'JS'
export function add(a, b) {
  if (typeof a !== 'number' || typeof b !== 'number') throw new Error('number only');
  return a + b;
}
JS
cat > tests/calc.test.js <<'JS'
import test from 'node:test';
import assert from 'node:assert/strict';
import { add } from '../src/calc.js';
test('R1: add(2, 3) 은 5', () => assert.equal(add(2, 3), 5));
test('R2: 숫자가 아니면 에러', () => assert.throws(() => add('2', 3)));
JS
