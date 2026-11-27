---
type: regex
target: {source: file, path: tests/calc.test.js}
pattern: "R3"
match: not_contains
---
삭제된 R3 테스트는 (허락받았으니) 지워져야 한다.
