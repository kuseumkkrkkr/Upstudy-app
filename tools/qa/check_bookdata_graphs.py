"""Read-only graph contract audit. Never copies, imports, or publishes the source."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from api.textbook_import import validate_book, validate_graph


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--expected-sha256', required=True)
    args = parser.parse_args()
    raw = args.source.read_bytes()
    canonical = raw.decode('utf-8-sig').replace('\r\n', '\n').encode('utf-8')
    digest = hashlib.sha256(canonical).hexdigest()
    if digest.lower() != args.expected_sha256.lower():
        raise SystemExit('Canonical UTF-8 source hash mismatch; not audited')
    book = json.loads(canonical)
    graphs, failures = 0, []
    for ci, chapter in enumerate(book.get('chapters', [])):
        for pi, page in enumerate(chapter.get('pages', [])):
            for bi, block in enumerate(page.get('blocks', [])):
                if block.get('graph') is None:
                    continue
                graphs += 1
                try:
                    validate_graph(block['graph'])
                except ValueError as error:
                    failures.append({'chapter': ci, 'page': pi, 'block': bi, 'error': str(error)})
    try:
        validate_book(book)
        book_error = None
    except ValueError as error:
        book_error = str(error)
    print(json.dumps({'canonical_sha256': digest, 'chapters': len(book.get('chapters', [])),
        'graphs': graphs, 'graph_failures': failures, 'book_error': book_error,
        'writes': 0}, ensure_ascii=False, indent=2))
    return 1 if failures or book_error else 0


if __name__ == '__main__':
    raise SystemExit(main())
