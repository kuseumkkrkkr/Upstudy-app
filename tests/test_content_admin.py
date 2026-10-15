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
        self.login_attempts = 0

    def request(self, method, path, *, query=None, body=None, **_):
        if path == 'rpc/claim_content_admin_login':
            self.login_attempts += 1
            return self.login_attempts <= 10
        if path == 'content_admin_accounts':
            user = query.get('id', 'eq.admin-user').removeprefix('eq.')
            row = {'id':user, 'session_version':1, 'active':True, 'salt':'test-salt-for-separated-admin-db-01',
                'password_hash':hashlib.pbkdf2_hmac('sha256', b'StrongAdminTest123', b'test-salt-for-separated-admin-db-01',600_000).hex()}
            return [row] if user in self.members and query.get('username', 'eq.admin') == 'eq.admin' else []
        if path == 'canary_content':
            return list(self.rows.values())
        assert path == 'rpc/admin_write_content'
        key = (body['p_actor'], body['p_key'])
        identity = {**body}
        if body.get('p_operation') in {'archive','restore'}:
            identity.pop('p_payload', None)
        if key in self.receipts:
            original, result = self.receipts[key]
            return result if original == identity else {'error': 'idempotency_conflict'}
        previous = self.rows.get(body['p_id'])
        if (previous or {}).get('version', 0) != body['p_version']:
            return {'error': 'version_conflict'}
        result = {'id': body['p_id'], 'version': body['p_version'] + 1, 'archived': body['p_archived']}
        self.rows[body['p_id']] = {**result, 'payload': body['p_payload']}
        self.receipts[key] = (identity, result)
        self.writes += 1
        return result


@pytest.fixture
def setup(monkeypatch):
    api = importlib.import_module('api.index')
    monkeypatch.setenv('CONTENT_ADMIN_ENABLED', 'true')
    monkeypatch.setenv('CONTENT_ADMIN_API_KEY_SHA256', hashlib.sha256(b'test-key-not-a-production-secret').hexdigest())
    monkeypatch.setenv('OMJ_JWT_SECRET', 'test-only-secret-12345678901234567890')
    monkeypatch.setenv('ADMIN_JWT_SECRET', 'independent-admin-secret-for-tests-1234567890')
    store = Store()
    monkeypatch.setattr(api, '_admin_data_api', lambda: store)
    with sqlite3.connect(Path(__file__).resolve().parents[1] / 'data/content/question-bank-v1.sqlite') as db:
        question_id = db.execute('select quest_id from quest_header limit 1').fetchone()[0]
    def headers(user='admin-user', key='test-key-not-a-production-secret'):
        return {'Authorization': 'Bearer ' + jwt.encode({'sub':user,'exp':int(time.time())+60,
                'iat':int(time.time()), 'iss':'aiflow-content-admin', 'aud':'content-admin', 'session_version':1},
                'independent-admin-secret-for-tests-1234567890', algorithm='HS256'), 'X-Admin-Api-Key':key,
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


def test_archive_retry_keeps_original_result_after_later_metadata_edit(setup):
    _, store, client, headers, payload = setup
    path = '/admin/api/content/' + payload['id']
    assert client.put(path, json=payload, headers=headers()).status_code == 200
    archive_headers = {**headers(), 'X-Idempotency-Key':'archive-response-lost'}
    first = client.delete(path+'?version=1', headers=archive_headers)
    assert first.status_code == 200
    update_headers = {**headers(), 'X-Idempotency-Key':'later-edit'}
    assert client.put(path, json={**payload, 'version':2, 'title':'Changed later'}, headers=update_headers).status_code == 200
    retry = client.delete(path+'?version=1', headers=archive_headers)
    assert retry.status_code == 200, retry.text
    assert retry.json() == first.json()
    assert store.rows[payload['id']]['version'] == 3


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
    assert sql.count('enable row level security') == 4
    assert "to_regclass('public.canary_users')" in sql
    assert 'references public.canary_users' not in sql
    assert 'primary key (actor, request_key)' in sql
    assert 'pg_advisory_xact_lock' in sql and 'version_conflict' in sql
    assert 'delete from' not in sql.lower()
    assert 'from public,anon,authenticated' in sql


def test_enrollment_lookup_reads_catalog_once_per_request(setup, monkeypatch):
    api, _, _, _, _ = setup
    courses = [item for item in api.MARKETPLACE_CATALOG if item['kind'] == 'course'][:3]
    reads = []
    def catalog(**kwargs):
        reads.append(kwargs)
        return courses
    monkeypatch.setattr(api, '_effective_catalog', catalog)
    monkeypatch.setattr(api, '_load_owned_marketplace', lambda _: {item['id']:{} for item in courses})
    monkeypatch.setattr(api, '_load_course_enrollment_order', lambda _: [])
    monkeypatch.setattr(api, '_save_course_enrollment_order', lambda *_: None)
    assert len(api.list_enrolled_courses('admin-user')['items']) == len(courses)
    assert len(reads) == 1
    api.reorder_course_enrollments(api.CourseEnrollmentOrderRequest(course_ids=[item['asset_id'] for item in courses]), 'admin-user')
    assert len(reads) == 2


def test_admin_auth_does_not_use_student_accounts_or_tokens(setup, monkeypatch):
    api, store, client, headers, _ = setup
    def forbidden():
        raise AssertionError('Admin auth touched student database')
    monkeypatch.setattr(api, '_data_api', forbidden)
    login = client.post('/admin/api/login', json={'username':'admin','password':'StrongAdminTest123'}, headers=headers())
    assert login.status_code == 200, login.text
    token = login.json()['token']
    assert client.get('/auth/me', headers={'Authorization':'Bearer '+token}).status_code == 401
    assert client.get('/admin/api/content', headers={**headers(),'Authorization':'Bearer '+token}).status_code == 200
    student_token = jwt.encode({'sub':'admin-user','exp':int(time.time())+60},
        'test-only-secret-12345678901234567890',algorithm='HS256')
    assert client.get('/admin/api/content', headers={**headers(),'Authorization':'Bearer '+student_token}).status_code == 401
    assert client.post('/admin/api/login',json={'username':'admin','password':'wrong'},headers=headers()).status_code == 401
    store.login_attempts = 10
    assert client.post('/admin/api/login',json={'username':'admin','password':'StrongAdminTest123'},headers=headers()).status_code == 429


def test_separate_database_and_signing_key_cannot_reuse_student_settings(monkeypatch):
    api=importlib.import_module('api.index')
    monkeypatch.setenv('SUPABASE_URL','https://student-project.supabase.co')
    monkeypatch.setenv('SUPABASE_SERVICE_ROLE_KEY','student-service-key')
    monkeypatch.setenv('ADMIN_SUPABASE_URL','https://student-project.supabase.co/')
    monkeypatch.setenv('ADMIN_SUPABASE_SERVICE_ROLE_KEY','different-key')
    with pytest.raises(RuntimeError): api.SupabaseDataApi(admin_database=True)
    monkeypatch.setenv('ADMIN_SUPABASE_URL','https://admin-project.supabase.co')
    monkeypatch.setenv('ADMIN_SUPABASE_SERVICE_ROLE_KEY','student-service-key')
    with pytest.raises(RuntimeError): api.SupabaseDataApi(admin_database=True)
    monkeypatch.setenv('ADMIN_SUPABASE_SERVICE_ROLE_KEY','admin-only-key')
    assert api.SupabaseDataApi(admin_database=True).base_url == 'https://admin-project.supabase.co/rest/v1'
    monkeypatch.setenv('OMJ_JWT_SECRET','shared-key-123456789012345678901234567890')
    monkeypatch.setenv('ADMIN_JWT_SECRET','shared-key-123456789012345678901234567890')
    with pytest.raises(Exception) as error: content_admin.admin_secret()
    assert error.value.status_code == 503
