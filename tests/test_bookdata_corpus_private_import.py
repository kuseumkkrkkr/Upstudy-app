"""Opt-in local corpus test. No network DB, provider calls or publication."""
import hashlib
import json
import os
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


@pytest.mark.skipif(not os.getenv('BOOKDATA_PRIVATE_FIXTURE'), reason='Local private corpus not provided')
def test_each_canonical_author_book_imports_and_reloads_without_loss(monkeypatch):
    from api import index as api
    rows = {}

    class Store:
        def request(self, method, path, *, query=None, body=None, prefer=None):
            assert path == 'canary_user_kv'
            if method == 'POST':
                assert prefer == 'resolution=ignore-duplicates,return=minimal'
                rows.setdefault((body['user_id'], body['key']), body['value'])
                return None
            assert method == 'GET'
            user = query['user_id'].removeprefix('eq.')
            key = query['key'].removeprefix('eq.')
            value = rows.get((user, key))
            return [{'value': value}] if value else []

    monkeypatch.setattr(api, '_data_api', lambda: Store())
    api.app.dependency_overrides[api._current_user] = lambda: 'private-corpus-test-owner'
    entries = json.loads(Path(os.environ['BOOKDATA_PRIVATE_FIXTURE']).read_text(encoding='utf-8'))
    try:
        with TestClient(api.app) as client:
            for entry in entries:
                source = json.dumps(entry['book'], ensure_ascii=False, separators=(',', ':'))
                response = client.post('/textbooks/import', json={
                    'source': source, 'sha256': hashlib.sha256(source.encode()).hexdigest()})
                assert response.status_code == 201, entry['path']
                saved = response.json()
                assert saved['chapters'] == entry['book']['chapters'], entry['path']
                loaded = client.get('/textbooks/' + saved['textbook_id'])
                assert loaded.status_code == 200 and loaded.json() == saved, entry['path']
        assert len(rows) == len(entries)
    finally:
        api.app.dependency_overrides.pop(api._current_user, None)
