import hashlib
import json
import pytest
from api.book_activity import validate_activity
from tests.test_textbook_create_contract import setup
from tools.migrate_coordinate_point import definitions, migrate, PAGE_ID


@pytest.mark.parametrize('change', [
    {'content': None}, {'content': ''}, {'content': True}, {'content': ['text']},
    {'content': 'x' * 2001}, {'onclick': 'run()'}, {'html': '<script/>'},
])
def test_disclosure_rejects_invalid_content_and_executable_fields(change):
    with pytest.raises(ValueError):
        validate_activity({**definitions()[2], **change})


def test_coordinate_source_activities_survive_authenticated_create_import_read(setup):
    _, client, _ = setup
    book = {'schema_version': 2, 'title': 'Synthetic coordinate source', 'chapters': [{'title': 'Chapter',
        'pages': [{'id': PAGE_ID, 'template': 'experiment', 'blocks': [
            {'type': 'activity', 'activity': d} for d in definitions()]}]}]}
    source = json.dumps(book)
    for route, body in [('/textbooks', book), ('/textbooks/import', {
            'source': source, 'sha256': hashlib.sha256(source.encode()).hexdigest()})]:
        response = client.post(route, json=body)
        assert response.status_code == 201, response.text
        saved = response.json()
        assert saved['chapters'] == book['chapters']
        assert client.get('/textbooks/' + saved['textbook_id']).json() == saved
    assert client.post('/textbooks', json={**book, 'schema_version': 1}).status_code == 422


def test_explicit_migration_keeps_static_reference_graph_and_review_state(monkeypatch):
    html = b'<synthetic coordinate source>'
    monkeypatch.setattr('tools.migrate_coordinate_point.SOURCE_HTML_SHA256', hashlib.sha256(html).hexdigest())
    blocks = [{'type': 'lead', 'text': 'Original'}, {'type': 'graph', 'graph': {'items': [
        {'id': 'ref', 'type': 'scatter', 'xValues': [-2], 'yValues': [3]}],
        'settings': {'showAxes': True, 'showGrid': True, 'lockViewport': True, 'degreeMode': False,
                     'viewport': {'left': -5, 'right': 5, 'top': 5, 'bottom': -5}}}}]
    original = {'title': 'Synthetic source', 'metadata': {'teacher_review_status': 'pending'}, 'chapters': [
        {'title': 'Chapter', 'intro': ['Keep'], 'sections': [{'title': 'Section', 'paragraphs': ['Keep']}],
         'pages': [{'id': PAGE_ID, 'template': 'experiment', 'blocks': blocks}]}]}
    raw = json.dumps(original)
    result = migrate(raw, html)
    migrated = result['chapters'][0]['pages'][0]['blocks']
    assert migrated[:1] + migrated[4:] == blocks
    assert result['chapters'][0]['sections'] == original['chapters'][0]['sections']
    assert 'schema_version' not in original and result['schema_version'] == 2
    assert result['metadata']['teacher_review_status'] == 'pending'
    assert result['metadata']['native_activity_migrations'][0]['publication_approved'] is False
    assert migrate(json.dumps(result), html) == result
    with pytest.raises(ValueError, match='Source HTML changed'):
        migrate(raw, html + b'changed')
    migrated.pop(3)
    with pytest.raises(ValueError, match='incomplete'):
        migrate(json.dumps(result), html)
