#!/usr/bin/env bash
set -e
git init -q
mkdir -p .claude/harness-synced docs/specs src tests
printf '%s\n' '{ "name": "todo", "type": "module", "scripts": { "test": "node --test" } }' > package.json
printf '%s\n' 'CHECK_CMD="npm test"' 'WATCH_PATHS=""' 'MODE=auto' > .claude/harness.conf
printf '%s\n' '# 할일' '' '- R1 할 일을 추가하면 목록 맨 아래에 붙는다' '- R2 할 일을 삭제하면 목록에서 사라진다' > .claude/harness-synced/할일.md
printf '%s\n' '# 할일' '' '- R1 할 일을 추가하면 목록 맨 아래에 붙는다' '- R2 할 일을 삭제하면 목록에서 사라진다' '- R3 다른 사용자의 할 일은 삭제할 수 없다 (권한 오류)' > docs/specs/할일.md
cat > src/todo.js <<'JS'
export function createStore() {
  const items = [];
  return {
    add: (owner, text) => { const it = { id: items.length + 1, owner, text }; items.push(it); return it; },
    remove: (user, id) => { const i = items.findIndex((x) => x.id === id); if (i >= 0) items.splice(i, 1); },
    list: () => items.slice(),
  };
}
JS
cat > tests/todo.test.js <<'JS'
import test from 'node:test';
import assert from 'node:assert/strict';
import { createStore } from '../src/todo.js';
test('R1: 추가하면 맨 아래', () => { const s = createStore(); s.add('a', 'x'); s.add('a', 'y'); assert.equal(s.list().at(-1).text, 'y'); });
test('R2: 삭제하면 사라짐', () => { const s = createStore(); const it = s.add('a', 'x'); s.remove('a', it.id); assert.equal(s.list().length, 0); });
JS
