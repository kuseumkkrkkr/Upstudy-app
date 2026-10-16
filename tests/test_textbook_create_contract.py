"""Synthetic creation contract, not real PostgreSQL concurrency evidence."""
import copy
import importlib
import json
from concurrent.futures import ThreadPoolExecutor

import pytest
from fastapi.testclient import TestClient
from tests.test_public_textbooks import Storage
from tests.test_textbook_import import draft


@pytest.fixture
def setup(monkeypatch):
    api = importlib.import_module('api.index')
    store = Storage()
    monkeypatch.setattr(api, '_data_api', lambda: store)
    # Owner is taken only from authenticated server context, never request JSON.
    api.app.dependency_overrides[api._current_user] = lambda: 'synthetic-owner'
    try:
        with TestClient(api.app) as client:
            yield api, client, store
    finally:
        api.app.dependency_overrides.pop(api._current_user, None)


def v2():
    book = draft()
    book.update(schema_version=2, tags=['tag-' + str(i) for i in range(48)])
    book['chapters'][0].update(tags=['chapter-tag'], standard_codes=['synthetic-code'])
    book['chapters'][0]['pages'][0]['blocks'].append({'type': 'activity', 'activity': {
        'id': 'synthetic-quiz', 'kind': 'quiz', 'prompt': 'One plus one?', 'answer': 2,
        'correct_feedback': 'Yes', 'incorrect_feedback': 'Try again'}})
    return book


def test_v2_create_is_owner_scoped_and_idempotent_without_resetting_progress(setup):
    api, client, store = setup
    book = v2()
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda _: client.post('/textbooks', json=book), range(24)))
    assert all(r.status_code == 201 for r in results)
    saved = results[0].json()
    assert all(r.json() == saved for r in results)
    assert len(store.rows) == 1 and saved['chapters'] == book['chapters']
    assert saved['tags'] == book['tags'] and saved['schema_version'] == 2
    assert client.get('/textbooks/' + saved['textbook_id']).json() == saved
    assert saved in client.get('/textbooks').json()['textbooks']
    key = ('synthetic-owner', api._PRIVATE_TEXTBOOK_PREFIX + saved['textbook_id'])
    saved['progress'] = .75
    store.rows[key] = json.dumps(saved)
    assert client.post('/textbooks', json=book).json()['progress'] == .75
    api.app.dependency_overrides[api._current_user] = lambda: 'other-owner'
    assert client.get('/textbooks/' + saved['textbook_id']).status_code == 404
    assert client.post('/textbooks', json=book).json()['textbook_id'] != saved['textbook_id']


def test_creation_rejects_public_approval_claims_and_invalid_data_before_storage(setup):
    _, client, store = setup
    for field in ('publication', 'created_by', 'price_points', 'rights_status', 'teacher_review_status', 'math_review_status'):
        assert client.post('/textbooks', json={**v2(), field: 'approved'}).status_code == 422
    invalid = copy.deepcopy(v2())
    invalid['chapters'][0]['sections'][0]['graph']['items'][0]['expression'] = 'window.alert(1)'
    assert client.post('/textbooks', json=invalid).status_code == 422
    assert client.post('/textbooks', content=b' ' * (512 * 1024 + 1)).status_code == 413
    assert not store.rows
    for key in ('textbook.private.forged', 'TEXTBOOK.PRIVATE.forged', 'textbook.public.owned.forged'):
        url = '/user/storage/' + key
        assert client.put(url, json={'value': '{}'}).status_code == 403
        assert client.get(url).status_code == 403
        assert client.delete(url).status_code == 403
    assert not store.rows


def test_creation_fails_closed_when_persistence_cannot_be_verified(setup, monkeypatch):
    api, client, _ = setup
    class LostWrite:
        def request(self, *args, **kwargs):
            return []
    monkeypatch.setattr(api, '_data_api', lambda: LostWrite())
    assert client.post('/textbooks', json=v2()).status_code == 503
    api.app.dependency_overrides.pop(api._current_user)
    assert client.post('/textbooks', json=v2()).status_code == 401
