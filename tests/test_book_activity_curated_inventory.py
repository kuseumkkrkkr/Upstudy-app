"""Static discovery must not be confused with a curated behavioral port."""
from collections import Counter
import json
from pathlib import Path
import re
from tools.migrate_polynomial_area import SOURCE_HTML_SHA256, PAGE_ID


def test_curated_inventory_counts_and_private_candidate_provenance():
    root = Path(__file__).resolve().parents[1]
    report = json.loads((root / 'design/student/audits/book-activity-source-inventory.json').read_text(encoding='utf-8'))
    assets = report['assets']
    assert len(assets) == report['asset_count'] == 106
    assert Counter(asset['status'] for asset in assets) == {
        'source_review_required_not_ported': 105,
        'private_candidate_local_reader_verified_not_published': 1}
    candidate = next(asset for asset in assets if asset['asset_id'] == 'html-d2b300ca0f76adab')
    assert candidate['sha256'] == SOURCE_HTML_SHA256
    assert PAGE_ID in candidate['manuscript_mapping']
    evidence = candidate['verification_evidence']
    assert re.fullmatch('[0-9a-f]{64}', evidence['source_book_sha256'])
    assert re.fullmatch('[0-9a-f]{64}', evidence['candidate_sha256'])
    assert evidence['publication_approved'] is False
    assert evidence['production_reader_verified'] is False
    for asset in assets:
        if asset is not candidate:
            assert asset['manuscript_mapping'] == 'unresolved_until_explicit_source_index'
    capabilities = json.loads((root / 'design/student/audits/book-activity-capabilities.json').read_text(encoding='utf-8'))
    assert capabilities['all_sources_ported'] is False
    assert len(capabilities['unsupported_families']) == 9
