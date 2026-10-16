import hashlib
import json
import pytest
from api.book_activity import validate_activity
from api.textbook_import import parse_import, migrate_v1_to_v2
from tests.test_textbook_create_contract import setup
from tools.migrate_polynomial_area import migrate, PAGE_ID


def activity():
    return {'id': 'synthetic-area', 'kind': 'polynomialArea', 'prompt': 'Compare expansion',
            'a': 3, 'b': 2, 'hints': []}


@pytest.mark.parametrize('change', [
    {'a': True}, {'b': 2.0}, {'a': 0}, {'b': 9}, {'a': '3'}, {'a': None},
    {'script': 'alert(1)'}, {'answer': 6}, {'expression': 'eval(x)'},
])
def test_invalid_parameters_are_rejected_not_dropped(change):
    with pytest.raises(ValueError):
        validate_activity({**activity(), **change})


def test_v2_create_import_read_roundtrip_preserves_definition(setup):
    _, client, _ = setup
    book = {'schema_version': 2, 'title': 'Synthetic polynomial', 'chapters': [
        {'title': 'Chapter', 'pages': [{'template': 'experiment', 'blocks': [
            {'type': 'activity', 'activity': activity()}]}]}]}
    source = json.dumps(book)
    digest = hashlib.sha256(source.encode()).hexdigest()
    parsed, actual = parse_import(source, digest)
    assert parsed == book and actual == digest
    for route, body in [('/textbooks', book), ('/textbooks/import', {'source': source, 'sha256': digest})]:
        result = client.post(route, json=body)
        assert result.status_code == 201, result.text
        saved = result.json()
        assert saved['chapters'] == book['chapters']
        assert client.get('/textbooks/' + saved['textbook_id']).json() == saved
    # Existing V1 content keeps its identity; activities are never silently inserted.
    assert client.post('/textbooks', json={**book, 'schema_version': 1}).status_code == 422
    old = {'title': 'Legacy', 'chapters': [{'title': 'Chapter', 'sections': []}]}
    upgraded = migrate_v1_to_v2(old)
    assert upgraded == {**old, 'schema_version': 2}
    assert old.get('schema_version') is None


def test_explicit_candidate_migration_retains_original_blocks_reviews_and_identity(monkeypatch):
    blocks = [{'type': 'lead', 'text': 'Original explanation'}, {'type': 'answer', 'text': 'Original note'}]
    book = {'schema_version': 2, 'title': 'Synthetic migration',
            'metadata': {'teacher_review_status': 'pending'}, 'chapters': [{'title': 'Chapter', 'pages': [
                {'id': PAGE_ID, 'template': 'experiment', 'blocks': blocks}]}]}
    html = b'<input type="range" id="a" min="1" max="8">'
    html_digest = hashlib.sha256(html).hexdigest()
    monkeypatch.setattr('tools.migrate_polynomial_area.SOURCE_HTML_SHA256', html_digest)
    raw = json.dumps(book, indent=2)
    original_digest = hashlib.sha256(raw.encode()).hexdigest()
    candidate = migrate(raw, html)
    migrated = candidate['chapters'][0]['pages'][0]['blocks']
    assert migrated[0] == blocks[0] and migrated[2:] == blocks[1:]
    assert len(book['chapters'][0]['pages'][0]['blocks']) == 2
    assert candidate['metadata']['teacher_review_status'] == 'pending'
    evidence = candidate['metadata']['native_activity_migrations'][0]
    assert evidence['source_book_sha256'] == original_digest and evidence['publication_approved'] is False
    assert evidence['source_html_sha256'] == html_digest
    assert migrate(json.dumps(candidate), html) == candidate
    assert migrate(raw + ' ', html)['metadata']['native_activity_migrations'][0]['source_book_sha256'] != original_digest
    with pytest.raises(ValueError, match='Source HTML changed'):
        migrate(raw, html + b'changed')
    with pytest.raises(ValueError, match='Original JSON text and HTML bytes required'):
        migrate(book, html)
