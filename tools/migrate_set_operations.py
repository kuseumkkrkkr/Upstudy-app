"""Explicit private candidate: python -m tools.migrate_set_operations. Originals untouched."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from tools.build_public_textbooks import prepare

SOURCE_HTML_SHA256 = 'e485b82083d57703f0a3e4c4eae8a3e344a1873f2f31ac5c891e355f3e24c70c'
PAGE_ID = 'common-math-2-sets-experiment'


def definitions():
    return [
        {'id': PAGE_ID + '-native', 'kind': 'setOperations',
         'prompt': '각 원소의 A/B 포함 여부와 연산을 바꾸어 결과를 비교하세요.',
         'universe': [1, 2, 3, 4, 5, 6], 'set_a': [1, 2, 3], 'set_b': [3, 4, 5],
         'operation': 'intersection', 'hints': []},
        {'id': PAGE_ID + '-counterexample', 'kind': 'quiz',
         'prompt': '별도 사례: A={1,2,3}, B={2,3,4}입니다. A⊆B일까요?',
         'options': ['참', '거짓'], 'correct_index': 1,
         'correct_feedback': '맞아요. 1은 A에는 있지만 B에는 없으므로 A⊆B가 거짓임을 보이는 반례입니다.',
         'incorrect_feedback': '다시 확인해 보세요. A의 모든 원소가 B에도 있어야 포함관계가 참입니다. A에만 있는 원소를 찾아보세요.'},
    ]


def migrate(source, html_source):
    if not isinstance(source, str) or not isinstance(html_source, bytes):
        raise ValueError('Original JSON text and HTML bytes required')
    if hashlib.sha256(html_source).hexdigest() != SOURCE_HTML_SHA256:
        raise ValueError('Source HTML changed; re-review required')
    prepare(source)
    result = json.loads(source)
    pages = [p for c in result['chapters'] for p in c.get('pages', [])
             if p.get('id') == PAGE_ID and p.get('template') == 'experiment']
    if len(pages) != 1:
        raise ValueError('Expected one explicit source experiment page')
    blocks = pages[0]['blocks']
    expected = definitions()
    existing = [b['activity'] for b in blocks if b.get('activity', {}).get('id') in {d['id'] for d in expected}]
    if existing:
        if existing != expected:
            raise ValueError('Existing source activities conflict or are incomplete')
        return result
    # Explicit upgrade only after strict original validation, with all source fields retained.
    result['schema_version'] = 2
    blocks[1:1] = [{'type': 'activity', 'activity': d} for d in expected]
    result.setdefault('metadata', {}).setdefault('native_activity_migrations', []).append({
        'page_id': PAGE_ID, 'kind': 'setOperations', 'source_html_sha256': SOURCE_HTML_SHA256,
        'source_book_sha256': hashlib.sha256(source.replace('\r\n', '\n').encode()).hexdigest(),
        'publication_approved': False})
    prepare(json.dumps(result, ensure_ascii=False))
    return result


def main():
    root = Path('D:/AIFlow-Workspace/Projects/Aiflow/Upstudy-hotfix')
    if Path.cwd().resolve() != root.resolve() or subprocess.check_output([
        'git', '-c', f'safe.directory={root.as_posix()}', 'branch', '--show-current'], text=True).strip() != 'hotfix':
        raise SystemExit('Run only from guarded D: hotfix')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-book', type=Path, required=True)
    parser.add_argument('--source-html', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.output.resolve().is_relative_to(root / 'build/temp'):
        raise SystemExit('Private candidate output must stay in build/temp')
    candidate = migrate(args.source_book.read_text(encoding='utf-8-sig'), args.source_html.read_bytes())
    with args.output.open('x', encoding='utf-8') as target:
        json.dump(candidate, target, ensure_ascii=False, indent=2)
    print('Private set candidate created; no public approval or source mutation.')


if __name__ == '__main__':
    main()
