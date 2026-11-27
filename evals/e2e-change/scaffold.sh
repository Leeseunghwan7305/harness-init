#!/usr/bin/env bash
set -e
git init -q
git config user.email eval@example.com
git config user.name eval
mkdir -p .claude/harness-synced docs/specs src tests
printf '%s\n' '{ "name": "calc", "type": "module", "scripts": { "test": "node --test" } }' > package.json
printf '%s\n' 'CHECK_CMD="npm test"' 'WATCH_PATHS=""' > .claude/harness.conf
# 마지막으로 반영한 문서 (스냅샷)
printf '%s\n' '# 계산기' '' '- R1 add(2, 3) 은 5' '- R2 add 에 숫자가 아닌 값이 오면 에러' '- R3 add(0.1, 0.2) 는 0.3' > .claude/harness-synced/계산기.md
# 지금 문서: R2 수정, R3 삭제, R4 추가
printf '%s\n' '# 계산기' '' '- R1 add(2, 3) 은 5' '- R2 add 에 숫자가 아닌 값이나 NaN 이 오면 에러' '- R4 sub(5, 3) 은 2' > docs/specs/계산기.md
cat > src/calc.js <<'JS'
export function add(a, b) {
  if (typeof a !== 'number' || typeof b !== 'number') throw new Error('number only');
  return Math.round((a + b) * 1e12) / 1e12;
}
JS
cat > tests/calc.test.js <<'JS'
import test from 'node:test';
import assert from 'node:assert/strict';
import { add } from '../src/calc.js';
test('R1: add(2, 3) 은 5', () => assert.equal(add(2, 3), 5));
test('R2: 숫자가 아니면 에러', () => assert.throws(() => add('2', 3)));
test('R3: add(0.1, 0.2) 는 0.3', () => assert.equal(add(0.1, 0.2), 0.3));
JS
git add -A && git commit -qm "계산기 v1"
