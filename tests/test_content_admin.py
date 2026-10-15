"""Admin authorization and catalog integration. SQL concurrency needs real PostgreSQL."""
import hashlib
import importlib
import sqlite3
import time
from pathlib import Path

import jwt
import pytest
from fastapi.testclient import TestClient

from api import content_admin


class Store:
    def __init__(self):
        self.members = {'admin-user'}
        self.rows = {}
        self.receipts = {}
        self.writes = 0

    def request(self, method, path, *, query=None, body=None, **_):
        if path == 'canary_content_admins':
            user = query['user_id'].removeprefix('eq.')
            return [{'user_id': user}] if user in self.members else []
        if path == 'canary_content':
            return list(self.rows.values())
        assert path == 'rpc/admin_write_content'
        key = (body['p_actor'], body['p_key'])
        if key in self.receipts:
            original, result = self.receipts[key]
            return result if original == body else {'error': 'idempotency_conflict'}
        previous = self.rows.get(body['p_id'])
        if (previous or {}).get('version', 0) != body['p_version']:
            return {'error': 'version_conflict'}
        result = {'id': body['p_id'], 'version': body['p_version'] + 1, 'archived': body['p_archived']}
        self.rows[body['p_id']] = {**result, 'payload': body['p_payload']}
        self.receipts[key] = (body, result)
        self.writes += 1
        return result


@pytest.fixture
def setup(monkeypatch):
    api = importlib.import_module('api.index')
    monkeypatch.setenv('CONTENT_ADMIN_ENABLED', 'true')
    monkeypatch.setenv('CONTENT_ADMIN_API_KEY_SHA256', hashlib.sha256(b'test-key-not-a-production-secret').hexdigest())
    monkeypatch.setenv('OMJ_JWT_SECRET', 'test-only-secret-12345678901234567890')
    store = Store()
    monkeypatch.setattr(api, '_data_api', lambda: store)
    with sqlite3.connect(Path(__file__).resolve().parents[1] / 'data/content/question-bank-v1.sqlite') as db:
        question_id = db.execute('select quest_id from quest_header limit 1').fetchone()[0]
    def headers(user='admin-user', key='test-key-not-a-production-secret'):
        return {'Authorization': 'Bearer ' + jwt.encode({'sub':user,'exp':int(time.time())+60},
                'test-only-secret-12345678901234567890', algorithm='HS256'), 'X-Admin-Api-Key':key,
                'X-Idempotency-Key':'request-1'}
    payload = dict(id='admin-test-paper', kind='exam', title='<script>literal title</script>',
                   problem_ids=[question_id], version=0)
    return api, store, TestClient(api.app), headers, payload


def test_account_and_key_both_required_fail_closed(setup, monkeypatch):
    api, store, client, headers, payload = setup
    assert client.get('/admin/api/content').status_code == 401
    assert client.get('/admin/api/content', headers=headers(key='wrong')).status_code == 403
    assert client.get('/admin/api/content', headers=headers(user='student')).status_code == 403
    for method, path in [('put','/admin/api/content/admin-test-paper'),
                         ('delete','/admin/api/content/admin-test-paper?version=0'),
                         ('post','/admin/api/content/admin-test-paper/restore?version=1')]:
        options = {'json': payload} if method == 'put' else {}
        assert getattr(client, method)(path, headers=headers(user='student'), **options).status_code == 403
    assert client.get('/admin/api/content', headers=headers()).status_code == 200
    store.members.clear()
    assert client.put('/admin/api/content/admin-test-paper', json=payload, headers=headers()).status_code == 403
    assert store.writes == 0
    monkeypatch.delenv('CONTENT_ADMIN_API_KEY_SHA256')
    assert client.get('/admin/api/content', headers=headers()).status_code == 503
    monkeypatch.delenv('CONTENT_ADMIN_ENABLED')
    assert client.get('/admin/api/content', headers=headers()).status_code == 503


def test_create_runtime_archive_preserves_owned_content(setup):
    api, store, client, headers, payload = setup
    path = '/admin/api/content/' + payload['id']
    result = client.put(path, json=payload, headers=headers())
    assert result.status_code == 200, result.text
    assert result.json()['version'] == 1
    assert client.put(path, json=payload, headers=headers()).json() == result.json()
    assert store.writes == 1
    listing = api._find_catalog_listing(payload['id'])
    assert api._build_marketplace_questions(listing)[0]['header']['quest_id'] == payload['problem_ids'][0]
    assert api._build_marketplace_exam_status(listing)['items'][0]['quest_id'] == payload['problem_ids'][0]
    archived_headers = {**headers(), 'X-Idempotency-Key': 'archive-1'}
    assert client.delete(path+'?version=0', headers=archived_headers).status_code == 409
    assert client.delete(path+'?version=1', headers=archived_headers).status_code == 200
    assert client.delete(path+'?version=1', headers=archived_headers).status_code == 200
    assert api._find_catalog_listing(payload['id'], include_archived=False) is None
    assert api._find_catalog_listing(payload['id']) is not None
    assert store.writes == 2
    restore_headers = {**headers(), 'X-Idempotency-Key':'restore-1'}
    assert client.post(path+'/restore?version=2', headers=restore_headers).status_code == 200
    assert api._find_catalog_listing(payload['id'], include_archived=False) is not None


def test_invalid_input_and_missing_key_never_write(setup):
    _, store, client, headers, payload = setup
    path = '/admin/api/content/' + payload['id']
    h = headers(); h.pop('X-Idempotency-Key')
    assert client.put(path, json=payload, headers=h).status_code == 422
    for overrides in [{'problem_ids':['missing-question']}, {'id':'../x'}, {'price_points':-1}, {'problem_ids':payload['problem_ids']*2}]:
        assert client.put(path, json={**payload, **overrides}, headers=headers()).status_code == 422
    assert store.writes == 0


def test_ui_is_no_store_and_does_not_persist_credentials(setup):
    _, _, client, _, _ = setup
    response = client.get('/admin')
    assert response.status_code == 200
    assert response.headers['cache-control'] == 'no-store'
    assert "frame-ancestors 'none'" in response.headers['content-security-policy']
    source = client.get('/admin/app.js').text
    assert '.textContent =' in source and '.innerHTML' not in source
    assert 'localStorage.' not in source and 'sessionStorage.' not in source


def test_migration_privileges_and_transaction_guards():
    sql = (Path(__file__).resolve().parents[1] / 'deploy/vercel/supabase_content_admin.sql').read_text(encoding='utf-8')
    assert sql.count('enable row level security') == 3
    assert 'primary key (actor, request_key)' in sql
    assert 'pg_advisory_xact_lock' in sql and 'version_conflict' in sql
    assert 'delete from' not in sql.lower()
    assert 'from public,anon,authenticated' in sql
