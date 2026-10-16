"""Private source-mapped coordinate candidate; python -m tools.migrate_coordinate_point."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from tools.build_public_textbooks import prepare

SOURCE_HTML_SHA256 = '4235767cff3d3bbbea8585712be8b3f35faa791d4dc74e7594a3ea1aed568d9e'
PAGE_ID = 'ms1-coordinate-experiment'


def definitions():
    return [
        {'id': PAGE_ID + '-native', 'kind': 'coordinatePoint',
         'prompt': '점 A를 끌거나 방향키·x/y 조절값으로 움직여 보세요.', 'x': -2, 'y': 3,
         'hints': ['별도 사례 C=(-4,0): C는 x축 위에 있어 y=0입니다. 축 위의 점은 사분면이 아니라 축 위에 있다고 말합니다.']},
        {'id': PAGE_ID + '-quiz', 'kind': 'quiz', 'prompt': '점 B=(3,-2)는 어디에 있을까요?',
         'options': ['제1사분면', '제2사분면', '제3사분면', '제4사분면'], 'correct_index': 3,
         'correct_feedback': '맞아요. x는 양수라 오른쪽, y는 음수라 아래이므로 제4사분면입니다.',
         'incorrect_feedback': '다시 보세요. 첫째 수는 오른쪽/왼쪽, 둘째 수는 위/아래를 정합니다.'},
        {'id': PAGE_ID + '-exercise', 'kind': 'disclosure', 'prompt': '독립 연습과 정답',
         'content': '1. (2,-5)의 위치를 부호로 설명하라.\n2. x좌표가 0인 점은 어느 축 위에 있는가?\n정답: 제4사분면. y축 위.'},
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
    result['schema_version'] = 2
    blocks[1:1] = [{'type': 'activity', 'activity': d} for d in expected]
    result.setdefault('metadata', {}).setdefault('native_activity_migrations', []).append({
        'page_id': PAGE_ID, 'kind': 'coordinatePoint', 'source_html_sha256': SOURCE_HTML_SHA256,
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
    print('Private coordinate candidate created; original reference graph retained; no publication.')


if __name__ == '__main__':
    main()
