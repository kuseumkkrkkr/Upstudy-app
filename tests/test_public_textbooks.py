"""Synthetic public books only: publication must never depend on private drafts."""
import json
import hashlib
import threading
from concurrent.futures import ThreadPoolExecutor

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from api import public_textbooks as public
from tools.build_public_textbooks import build, prepare


def source():
    return {'title': 'Public synthetic book', 'chapters': [
        {'title': 'Chapter', 'sections': [{'title': 'Section', 'paragraphs': ['Preserved text']}]}]}


class Storage:
    def __init__(self):
        self.rows = {}; self.lock = threading.Lock()

    def request(self, method, path, *, query, body=None, prefer=None):
        assert path == 'canary_user_kv'
        with self.lock:
            if method == 'POST':
                assert prefer == 'resolution=ignore-duplicates,return=minimal'
                self.rows.setdefault((body['user_id'], body['key']), body['value'])
                return None
            owner = query['user_id'].removeprefix('eq.')
            requested = query['key']
            rows = [{'key': key, 'value': value} for (user, key), value in sorted(self.rows.items())
                if user == owner and (key == requested[3:] if requested.startswith('eq.')
                else key.startswith(requested.removeprefix('like.').removesuffix('*')))]
            offset = int(query.get('offset', '0'))
            return rows[offset:offset + int(query.get('limit', '500'))]


@pytest.fixture
def setup(tmp_path, monkeypatch):
    entry = prepare(json.dumps(source()))
    path = tmp_path / 'published.json'
    path.write_text(json.dumps({'version': 1, 'books': [entry]}), encoding='utf-8')
    monkeypatch.setattr(public, 'BUNDLE', path)
    public.books.cache_clear()
    store = Storage(); app = FastAPI()
    def user():
        return 'owner-a'
    public.install(app, lambda: store, user)
    with TestClient(app) as client:
        yield client, store, 'published-' + entry['sha256']
    public.books.cache_clear()


def test_free_acquire_is_durable_idempotent_and_owner_scoped(setup):
    client, storage, book_id = setup
    assert client.get('/marketplace/textbooks').json()['items'][0]['price_points'] == 0
    assert 'chapters' not in client.get('/marketplace/textbooks').json()['items'][0]
    with pytest.raises(Exception) as error:
        public.get_owned(lambda: storage, 'owner-a', book_id)
    assert error.value.status_code == 403
    storage.rows[('owner-a', 'textbook.private.existing')] = 'never overwrite'
    url = f'/marketplace/textbooks/{book_id}/purchase'
    with ThreadPoolExecutor(max_workers=20) as pool:
        responses = list(pool.map(lambda _: client.post(url), range(200)))
    assert all(r.status_code == 200 and r.json()['owned'] for r in responses)
    assert len(storage.rows) == 2
    assert storage.rows[('owner-a', 'textbook.private.existing')] == 'never overwrite'
    assert public.library(lambda: storage, 'owner-b') == []
    assert public.library(lambda: storage, 'owner-a')[0]['textbook_id'] == book_id
    assert public.get_owned(lambda: storage, 'owner-a', book_id)['chapters'] == source()['chapters']
    assert client.post('/marketplace/textbooks/../private/purchase').status_code == 404
    assert client.post('/marketplace/textbooks/published-' + 'a'*64 + '/purchase').status_code == 404


def test_bundle_hash_is_enforced(setup):
    public.books.cache_clear()
    bundle = json.loads(public.BUNDLE.read_text())
    bundle['books'][0]['source'] += ' '
    public.BUNDLE.write_text(json.dumps(bundle))
    with pytest.raises(ValueError, match='SHA-256'):
        public.books()


def test_annotations_preserved_but_unknown_runtime_never_dropped(tmp_path):
    book = source(); book['metadata'] = {'review': 'pending'}
    book['chapters'][0]['unitTitle'] = 'Original unit'
    entry = prepare(json.dumps(book))
    assert entry['source_metadata']['annotations']['book']['metadata']['review'] == 'pending'
    assert entry['source_metadata']['annotations']['chapters'][0]['unitTitle'] == 'Original unit'
    assert json.loads(entry['source'])['chapters'][0]['sections'] == book['chapters'][0]['sections']
    book['chapters'][0]['arbitrary_js'] = 'alert(1)'
    with pytest.raises(ValueError, match='arbitrary_js'):
        prepare(json.dumps(book))
    (tmp_path / 'valid_BookData.json').write_text(json.dumps(source()))
    (tmp_path / 'invalid_BookData.json').write_text(json.dumps(book))
    report, _ = build(tmp_path)
    assert report['files'] == 2 and report['valid'] == 1 and len(report['errors']) == 1


def test_real_routes_require_auth_and_keep_reader_owner_boundary(setup, monkeypatch):
    from api import index as api
    _, storage, book_id = setup
    monkeypatch.setattr(api, '_data_api', lambda: storage)
    with TestClient(api.app) as client:
        for path in ('/marketplace/textbooks', '/marketplace/textbooks/owned'):
            assert client.get(path).status_code == 401
        assert client.post(f'/marketplace/textbooks/{book_id}/purchase').status_code == 401
        api.app.dependency_overrides[api._current_user] = lambda: 'owner-a'
        try:
            assert client.get('/textbooks/' + book_id).status_code == 403
            assert client.post(f'/marketplace/textbooks/{book_id}/purchase',
                               json={'price_points': -10000, 'user_id': 'owner-b'}).status_code == 200
            assert client.get('/textbooks/' + book_id).json()['chapters'] == source()['chapters']
            assert client.get('/marketplace/textbooks/owned').json()['items'][0]['textbook_id'] == book_id
            assert not any(owner == 'owner-b' for owner, _ in storage.rows)
            api.app.dependency_overrides[api._current_user] = lambda: 'owner-b'
            assert client.get('/textbooks/' + book_id).status_code == 403
        finally:
            api.app.dependency_overrides.pop(api._current_user, None)


def test_explicit_approval_subset_never_leaks_sibling_drafts(tmp_path):
    selected = json.dumps(source())
    (tmp_path / 'approved_BookData.json').write_text(selected, encoding='utf-8')
    (tmp_path / 'private_BookData.json').write_text('{"private":"never publish"}', encoding='utf-8')
    manifest = {'version': 1, 'files': [{
        'path': 'approved_BookData.json', 'sha256': hashlib.sha256(selected.encode()).hexdigest(),
        'publication_approved': True, 'rights_status': 'cleared', 'teacher_review_status': 'approved'}]}
    report, entries = build(tmp_path, manifest)
    assert report == {'files': 1, 'valid': 1, 'errors': []}
    assert len(entries) == 1 and 'private' not in entries[0]['source']
    (tmp_path / 'approved_BookData.json').write_text(selected + ' ', encoding='utf-8')
    with pytest.raises(ValueError, match='Approved source changed'):
        build(tmp_path, manifest)
    manifest['files'][0]['teacher_review_status'] = 'pending'
    with pytest.raises(ValueError, match='approval is incomplete'):
        build(tmp_path, manifest)


def test_approved_but_invalid_runtime_blocks_the_release(tmp_path):
    invalid = json.dumps({**source(), 'arbitrary_js': 'alert(1)'})
    (tmp_path / 'invalid_BookData.json').write_text(invalid)
    manifest = {'version': 1, 'files': [{
        'path': 'invalid_BookData.json', 'sha256': hashlib.sha256(invalid.encode()).hexdigest(),
        'publication_approved': True, 'rights_status': 'cleared', 'teacher_review_status': 'approved'}]}
    report, entries = build(tmp_path, manifest)
    assert report['valid'] == 0 and len(report['errors']) == 1 and entries == []
    manifest['files'][0]['path'] = '../outside.json'
    with pytest.raises(ValueError, match='outside the source root'):
        build(tmp_path, manifest)


def test_empty_bundle_never_queries_ownership_storage(tmp_path, monkeypatch):
    monkeypatch.setattr(public, 'BUNDLE', tmp_path / 'absent.json')
    public.books.cache_clear()
    def unavailable():
        raise AssertionError('An empty catalogue does not require an ownership query')
    app = FastAPI()
    public.install(app, unavailable, lambda: 'owner-a')
    try:
        with TestClient(app) as client:
            assert client.get('/marketplace/textbooks').json() == {'items': []}
            assert client.get('/marketplace/textbooks/owned').json() == {'items': []}
    finally:
        public.books.cache_clear()
