"""Explicit private migration; run `python -m tools.migrate_polynomial_area`.

Module invocation from the guarded checkout is required; direct script invocation
is not supported. No author package or sys.path mutation is needed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from tools.build_public_textbooks import prepare

SOURCE_HTML_SHA256 = '9fc6663e58368d8dd25d4ae9e2dea8d9eed0da10d9c702be72689460550046ef'
PAGE_ID = 'ms31-22-polynomial-product-experiment'


def migrate(source, html_source):
    """Retain every source block/review annotation; append a registered activity."""
    if not isinstance(source, str) or not isinstance(html_source, bytes):
        raise ValueError('Original JSON text and HTML bytes required')
    html_sha256 = hashlib.sha256(html_source).hexdigest()
    if html_sha256 != SOURCE_HTML_SHA256:
        raise ValueError('Source HTML changed; re-review behavior before migration')
    prepare(source)  # Strict duplicate/nonfinite/structure validation before migration.
    original_sha256 = hashlib.sha256(source.replace('\r\n', '\n').encode()).hexdigest()
    result = json.loads(source)
    if result.get('schema_version') != 2:
        raise ValueError('Explicit BookData V2 required')
    pages = [page for chapter in result.get('chapters', []) for page in chapter.get('pages', [])
             if page.get('id') == PAGE_ID and page.get('template') == 'experiment']
    if len(pages) != 1:
        raise ValueError('Expected exactly one source experiment page')
    definition = {'id': PAGE_ID + '-native', 'kind': 'polynomialArea',
                  'prompt': 'a와 b를 바꾸며 전개식의 두 계수를 비교하세요.',
                  'a': 3, 'b': 2, 'hints': []}
    existing = [block.get('activity') for block in pages[0]['blocks']
                if block.get('activity', {}).get('id') == definition['id']]
    if existing:
        if existing != [definition]:
            raise ValueError('Existing activity conflicts with the reviewed source')
        prepare(json.dumps(result, ensure_ascii=False))
        return result
    pages[0]['blocks'].insert(1, {'type': 'activity', 'activity': definition})
    result.setdefault('metadata', {}).setdefault('native_activity_migrations', []).append({
        'page_id': PAGE_ID, 'kind': 'polynomialArea', 'source_html_sha256': html_sha256.lower(),
        'source_book_sha256': original_sha256, 'publication_approved': False})
    prepare(json.dumps(result, ensure_ascii=False))
    return result


def main():
    root = Path('D:/AIFlow-Workspace/Projects/Aiflow/Upstudy-hotfix')
    if Path.cwd().resolve() != root.resolve() or subprocess.check_output([
        'git', '-c', f'safe.directory={root.as_posix()}', 'branch', '--show-current'], text=True).strip() != 'hotfix':
        raise SystemExit('Run only from the guarded D: hotfix checkout')
    parser = argparse.ArgumentParser(prog='python -m tools.migrate_polynomial_area', description=__doc__)
    parser.add_argument('--source-book', type=Path, required=True)
    parser.add_argument('--source-html', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.output.resolve().is_relative_to(root / 'build/temp'):
        raise SystemExit('Private candidate output must stay in build/temp')
    raw = args.source_book.read_text(encoding='utf-8-sig')
    candidate = migrate(raw, args.source_html.read_bytes())
    with args.output.open('x', encoding='utf-8') as target:
        json.dump(candidate, target, ensure_ascii=False, indent=2)
    print('Private candidate created; original files unchanged; publication not approved.')


if __name__ == '__main__':
    main()
