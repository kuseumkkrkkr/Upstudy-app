import hashlib
import json
import pytest
from api.book_activity import validate_activity
from tests.test_textbook_create_contract import setup
from tools.migrate_set_operations import definitions, migrate, PAGE_ID


@pytest.mark.parametrize('change', [
    {'universe': [True, 2, 3, 4, 5, 6]}, {'universe': [1, 2]},
    {'set_a': [1, 1]}, {'set_b': [7]}, {'set_a': [True]}, {'set_b': [1.0]},
    {'set_a': None}, {'operation': 'eval'}, {'html': '<script/>'},
])
def test_set_payload_rejects_invalid_or_executable_data(change):
    with pytest.raises(ValueError):
        validate_activity({**definitions()[0], **change})


def test_create_import_and_read_preserve_exact_v2_definition(setup):
    _, client, _ = setup
    book = {'schema_version': 2, 'title': 'Synthetic set test', 'chapters': [{'title': 'Chapter',
        'pages': [{'id': PAGE_ID, 'template': 'experiment', 'blocks': [
            {'type': 'activity', 'activity': d} for d in definitions()]}]}]}
    source = json.dumps(book)
    for route, body in [('/textbooks', book), ('/textbooks/import', {'source': source,
            'sha256': hashlib.sha256(source.encode()).hexdigest()})]:
        response = client.post(route, json=body)
        assert response.status_code == 201, response.text
        saved = response.json()
        assert saved['chapters'] == book['chapters']
        assert client.get('/textbooks/' + saved['textbook_id']).json() == saved
    assert client.post('/textbooks', json={**book, 'schema_version': 1}).status_code == 422


def test_private_migration_retains_every_source_block_and_pending_review(monkeypatch):
    html = b'<synthetic set source>'
    monkeypatch.setattr('tools.migrate_set_operations.SOURCE_HTML_SHA256', hashlib.sha256(html).hexdigest())
    original = {'title': 'Synthetic original', 'metadata': {'teacher_review_status': 'pending'},
        'chapters': [{'title': 'Chapter', 'pages': [{'id': PAGE_ID, 'template': 'experiment',
            'blocks': [{'type': 'lead', 'text': 'Original'}, {'type': 'answer', 'text': 'Retain'}]}]}]}
    raw = json.dumps(original)
    result = migrate(raw, html)
    assert result['schema_version'] == 2 and 'schema_version' not in original
    blocks = result['chapters'][0]['pages'][0]['blocks']
    assert blocks[:1] + blocks[3:] == original['chapters'][0]['pages'][0]['blocks']
    assert result['metadata']['teacher_review_status'] == 'pending'
    assert result['metadata']['native_activity_migrations'][0]['publication_approved'] is False
    assert migrate(json.dumps(result), html) == result
    with pytest.raises(ValueError, match='Source HTML changed'):
        migrate(raw, html + b'changed')
    result['chapters'][0]['pages'][0]['blocks'].pop(2)
    with pytest.raises(ValueError, match='incomplete'):
        migrate(json.dumps(result), html)
