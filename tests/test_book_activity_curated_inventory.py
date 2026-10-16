"""Static discovery must not be confused with a curated behavioral port."""
from collections import Counter
import json
from pathlib import Path
import re
from tools.migrate_polynomial_area import SOURCE_HTML_SHA256, PAGE_ID
from tools.migrate_set_operations import SOURCE_HTML_SHA256 as SET_SHA256, PAGE_ID as SET_PAGE_ID
from tools.migrate_coordinate_point import SOURCE_HTML_SHA256 as POINT_SHA256, PAGE_ID as POINT_PAGE_ID


def test_curated_inventory_counts_and_private_candidate_provenance():
    root = Path(__file__).resolve().parents[1]
    report = json.loads((root / 'design/student/audits/book-activity-source-inventory.json').read_text(encoding='utf-8'))
    assets = report['assets']
    assert len(assets) == report['asset_count'] == 106
    assert Counter(asset['status'] for asset in assets) == {
        'source_review_required_not_ported': 103,
        'private_candidate_local_reader_verified_not_published': 3}
    reviewed = {'html-d2b300ca0f76adab': (SOURCE_HTML_SHA256, PAGE_ID),
                'html-244e439259c143b2': (SET_SHA256, SET_PAGE_ID),
                'html-3050dd8407807a29': (POINT_SHA256, POINT_PAGE_ID)}
    for asset_id, (digest, page_id) in reviewed.items():
        candidate = next(asset for asset in assets if asset['asset_id'] == asset_id)
        assert candidate['sha256'] == digest
        assert page_id in candidate['manuscript_mapping']
        evidence = candidate['verification_evidence']
        assert re.fullmatch('[0-9a-f]{64}', evidence['source_book_sha256'])
        assert re.fullmatch('[0-9a-f]{64}', evidence['candidate_sha256'])
        assert evidence['publication_approved'] is False
        assert evidence['production_reader_verified'] is False
    for asset in assets:
        if asset['asset_id'] not in reviewed:
            assert asset['manuscript_mapping'] == 'unresolved_until_explicit_source_index'
    capabilities = json.loads((root / 'design/student/audits/book-activity-capabilities.json').read_text(encoding='utf-8'))
    assert capabilities['all_sources_ported'] is False
    assert len(capabilities['unsupported_families']) == 9
    set_scope = capabilities['kinds']['setOperations']
    proof = json.loads((root / 'design/student/audits/evidence/2026-10-17-set-operations/fixed-preview-browser-bundle.json').read_text(encoding='utf-8'))
    assert proof['deploymentId'] == set_scope['preview_deployment']
    assert proof['sha256'] == set_scope['preview_bundle_sha256']
    assert proof['bytes'] == 5763257 and proof['status'] == 200
    assert proof['mimeType'] == 'application/javascript'
    assert proof['fromDiskCache'] is False and proof['fromServiceWorker'] is False
    point_scope = capabilities['kinds']['coordinatePoint']
    point_proof = json.loads((root / 'design/student/audits/evidence/2026-10-17-coordinate-source/preview-browser-bundle.json').read_text(encoding='utf-8'))
    assert point_proof['deployment_id'] == point_scope['preview_deployment']
    assert point_proof['js_sha256'] == point_scope['preview_bundle_sha256']
    assert point_proof['js_bytes'] == 5764824 and point_proof['status'] == 200
    assert point_proof['mime'] == 'application/javascript'
    assert point_proof['disk_cache'] is False and point_proof['service_worker'] is False
    assert point_proof['root_url'].startswith('https://aiflow-web-canary-5obgs9007-')
    assert all((root / 'design/student/audits/evidence/2026-10-17-coordinate-source' / name).is_file() for name in point_proof['screenshots'])
