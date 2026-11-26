// harness eval 채점기 템플릿 — 필드별 정확도
//
// 사용법:
//   node score.mjs <fixtures-dir> <predictions-dir>
//   fixtures-dir   : <이름>.expected.json  (정답)
//   predictions-dir: <이름>.json           (운영 코드와 같은 함수로 만든 결과)
//
// 프로젝트에 복사해서 고쳐 쓴다. 실제로는 predictions를 파일로 받지 말고
// 운영 LLM 함수를 직접 import 해 돌리는 runner를 앞에 붙이는 것을 권장한다.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

/** 문자열 정규화: 공백·대소문자·전각 차이를 무시 */
export const norm = (v) =>
  String(v ?? '')
    .normalize('NFKC')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();

/** 배열은 순서 무시 F1, 나머지는 정규화 후 일치(1/0) */
export function scoreField(expected, actual) {
  if (Array.isArray(expected)) {
    const e = new Set(expected.map(norm));
    const a = new Set((Array.isArray(actual) ? actual : []).map(norm));
    if (e.size === 0 && a.size === 0) return 1;
    const tp = [...a].filter((x) => e.has(x)).length;
    const p = a.size ? tp / a.size : 0;
    const r = e.size ? tp / e.size : 0;
    return p + r ? (2 * p * r) / (p + r) : 0;
  }
  if (expected !== null && typeof expected === 'object') {
    const keys = Object.keys(expected);
    if (keys.length === 0) return 1;
    const sub = keys.map((k) => scoreField(expected[k], actual?.[k]));
    return sub.reduce((s, x) => s + x, 0) / sub.length;
  }
  return norm(expected) === norm(actual) ? 1 : 0;
}

/** 케이스 하나: 필드별 점수 */
export function scoreCase(expected, actual) {
  return Object.fromEntries(Object.keys(expected).map((k) => [k, scoreField(expected[k], actual?.[k])]));
}

function main([fixturesDir, predDir]) {
  if (!fixturesDir || !predDir) {
    console.error('usage: node score.mjs <fixtures-dir> <predictions-dir>');
    process.exit(1);
  }
  const names = readdirSync(fixturesDir)
    .filter((f) => f.endsWith('.expected.json'))
    .map((f) => f.replace(/\.expected\.json$/, ''));
  const totals = {};
  const failures = [];
  let skipped = 0;
  for (const name of names) {
    const expected = JSON.parse(readFileSync(join(fixturesDir, `${name}.expected.json`), 'utf8'));
    let actual;
    try {
      actual = JSON.parse(readFileSync(join(predDir, `${name}.json`), 'utf8'));
    } catch {
      skipped++;
      failures.push(`${name}: 예측 없음 (건너뜀)`);
      continue;
    }
    for (const [field, s] of Object.entries(scoreCase(expected, actual))) {
      (totals[field] ??= []).push(s);
      if (s < 1) failures.push(`${name}.${field}: ${s.toFixed(2)}`);
    }
  }
  console.log(`케이스 ${names.length}개 (건너뜀 ${skipped})\n`);
  console.log('필드'.padEnd(24) + '정확도');
  for (const [field, arr] of Object.entries(totals)) {
    const avg = arr.reduce((s, x) => s + x, 0) / arr.length;
    console.log(field.padEnd(24) + `${(avg * 100).toFixed(1)}%`);
  }
  if (failures.length) console.log(`\n실패/부분 일치\n- ${failures.join('\n- ')}`);
}

if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith('score.mjs')) {
  main(process.argv.slice(2));
}
