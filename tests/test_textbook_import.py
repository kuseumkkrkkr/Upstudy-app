"""Synthetic BookData only; user manuscripts are never copied into test fixtures."""
import copy
import hashlib
import importlib
import json
import threading
import time
from concurrent.futures import ThreadPoolExecutor

import jwt
import pytest
from fastapi.testclient import TestClient
from api.textbook_import import parse_import, validate_book, validate_expression


def draft():
    graph = {'items': [{'id': 'parabola', 'type': 'function', 'expression': 'x*x/(4*p)'}],
             'settings': {'parameters': [{'id': 'p', 'value': 2, 'min': .5, 'max': 3, 'step': .5}]}}
    return {'title': 'Synthetic private prototype', 'category': 'concept_textbook_prototype',
            'curriculum_version': '2022', 'standard_codes': ['12기하01-01'],
            'chapters': [{'title': 'Chapter', 'sections': [{'title': 'Explanation', 'paragraphs': ['Keep this text'], 'graph': graph}],
                          'pages': [{'id': 'experiment', 'template': 'experiment', 'title': 'Experiment', 'blocks': [
                              {'type': 'graph', 'title': 'Plot', 'text': 'Keep graph explanation', 'graph': graph},
                              {'type': 'question', 'text': 'A display-only question'},
                              {'type': 'answer', 'text': 'A display-only answer'}]}]}]}


def body(book=None):
    source = json.dumps(book or draft(), ensure_ascii=False)
    return {'source': source, 'sha256': hashlib.sha256(source.encode()).hexdigest()}


def test_exact_source_and_known_structure_are_preserved():
    payload = body()
    book, digest = parse_import(payload['source'], payload['sha256'])
    assert book == draft() and digest == payload['sha256']
    with pytest.raises(ValueError, match='SHA-256'):
        parse_import(payload['source'] + ' ', payload['sha256'])
    unsupported = draft()
    unsupported['chapters'][0]['pages'][0]['blocks'][0]['html'] = '<script>bad()</script>'
    with pytest.raises(ValueError, match='unsupported fields'):
        validate_book(unsupported)
    unsupported = draft()
    unsupported['chapters'][0]['pages'][0]['blocks'][0]['type'] = 'interactive-quiz'
    with pytest.raises(ValueError, match='unsupported type'):
        validate_book(unsupported)


def test_import_sha256_is_canonical_across_lf_and_crlf():
    source = json.dumps(draft(), ensure_ascii=False, indent=2)
    crlf_source = source.replace("\n", "\r\n")
    canonical_digest = hashlib.sha256(source.encode("utf-8")).hexdigest()
    book, digest = parse_import(crlf_source, canonical_digest)
    assert book == draft()
    assert digest == canonical_digest


@pytest.mark.parametrize('expression', ["window.alert(1)", "x.constructor", "__import__('os')", "[x][0]", "x if x else 2", "(lambda:1)()", "sin(x, x=2)", "True", "1; alert(1)"])
def test_graph_rejects_executable_or_unknown_expression(expression):
    with pytest.raises(ValueError):
        validate_expression(expression, ['p'])


@pytest.mark.parametrize('expression', ['x*x/(4*p)', 'y = sin(x) + pi', 'sqrt(abs(x))+max(p, 1)', 'exp(-x^2)', '1e-3*x'])
def test_supported_arithmetic_is_accepted(expression):
    validate_expression(expression, ['p'])


@pytest.mark.parametrize('version,activity_kind', [(1, None), (2, 'quiz'), (2, 'discreteExperiment'), (2, 'statisticsEstimator')])
def test_import_retries_and_owner_scope(monkeypatch, version, activity_kind):
    module = importlib.import_module('api.index')
    secret = 'textbook-import-test-secret-32-chars-minimum'
    monkeypatch.setenv('OMJ_JWT_SECRET', secret)

    class Store:
        def __init__(self):
            self.rows, self.lock = {}, threading.Lock()

        def request(self, method, path, *, query=None, body=None, prefer=None):
            assert path == 'canary_user_kv'
            with self.lock:
                if method == 'POST':
                    assert prefer in ('resolution=ignore-duplicates,return=minimal', 'resolution=merge-duplicates,return=minimal')
                    self.rows.setdefault((body['user_id'], body['key']), body['value'])
                    return None
                user = query['user_id'].removeprefix('eq.')
                key = query['key']
                if key.startswith('eq.'):
                    value = self.rows.get((user, key[3:]))
                    return [{'value': value}] if value else []
                return [{'key': key, 'value': value} for (owner, key), value in self.rows.items() if owner == user]

    store = Store()
    monkeypatch.setattr(module, '_data_api', lambda: store)
    def headers(user):
        return {'Authorization': 'Bearer ' + jwt.encode({'sub': user, 'exp': int(time.time()) + 300}, secret, algorithm='HS256')}
    with TestClient(module.app) as client:
        source_book = draft()
        if version == 2:
            source_book['schema_version'] = 2
            activity = ({'id':'experiment-owner-scope','kind':'discreteExperiment','prompt':'Event frequency',
                         'experiment':{'outcomes':[{'label':'A','success':True},{'label':'B','success':False}]}}
                        if activity_kind == 'discreteExperiment' else
                        {'id':'quiz-owner-scope','kind':'quiz','prompt':'Half?','answer':.5,
                         'correct_feedback':'Yes','incorrect_feedback':'Retry'})
            if activity_kind == 'statisticsEstimator':
                activity = {'id':'statistics-owner-scope','kind':'statisticsEstimator','prompt':'Sample mean',
                            'statistics':{'mode':'mean','sample_values':[2,4,6]}}
            source_book['chapters'][0]['pages'][0]['blocks'].append({
                'type':'activity', 'activity':activity})
        payload = body(source_book)
        with ThreadPoolExecutor(max_workers=8) as pool:
            responses = list(pool.map(lambda _: client.post('/textbooks/import', json=payload, headers=headers('owner')), range(24)))
        assert all(response.status_code == 201 for response in responses)
        books = [response.json() for response in responses]
        assert all(book == books[0] for book in books)
        assert len(store.rows) == 1
        saved = books[0]
        assert saved['chapters'] == source_book['chapters']
        assert saved.get('schema_version', 1) == version
        assert saved['curriculum_version'] == '2022' and saved['category'] == 'concept_textbook_prototype'
        assert client.get('/textbooks/' + saved['textbook_id'], headers=headers('owner')).json() == saved
        assert client.get('/textbooks/' + saved['textbook_id'], headers=headers('other')).status_code == 404
        assert client.post('/textbooks/import', json=payload).status_code == 401
        corrupt = copy.deepcopy(payload)
        corrupt['sha256'] = '0' * 64
        assert client.post('/textbooks/import', json=corrupt, headers=headers('owner')).status_code == 422
        assert len(store.rows) == 1
        if version == 2:
            created = client.post('/textbooks', json=source_book, headers=headers('owner'))
            assert created.status_code == 201, created.text
            assert created.json()['schema_version'] == 2
            assert created.json()['chapters'] == source_book['chapters']
            created_id = created.json()['textbook_id']
            assert client.get('/textbooks/' + created_id, headers=headers('owner')).json()['chapters'] == source_book['chapters']
            assert client.get('/textbooks/' + created_id, headers=headers('other')).status_code == 404
            assert client.post('/textbooks', json={**source_book, 'script': 'not allowed'}, headers=headers('owner')).status_code == 422
