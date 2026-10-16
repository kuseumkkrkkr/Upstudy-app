import json
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from api.book_activity import validate_activity
from api import public_textbooks as public
from tools.build_public_textbooks import prepare
from tests.test_public_textbooks import Storage


def activity():
    return {'id': 'synthetic-root', 'kind': 'squareRootNumberLine',
            'prompt': 'Locate the square root', 'min': 1, 'max': 25, 'hints': []}


@pytest.mark.parametrize('change', [{'min': True}, {'max': 25.0}, {'min': 0}, {'max': 26}, {'script': 'bad'}])
def test_rejects_invalid_bounds_and_executable_fields(change):
    with pytest.raises(ValueError):
        validate_activity({**activity(), **change})


def test_synthetic_public_catalogue_acquisition_and_reader_preserve_activity(tmp_path, monkeypatch):
    book = {'schema_version': 2, 'title': 'Synthetic root practice', 'chapters': [
        {'title': 'Root', 'pages': [{'template': 'experiment', 'blocks': [
            {'type': 'activity', 'activity': activity()}]}]}]}
    entry = prepare(json.dumps(book))
    bundle = tmp_path / 'synthetic.json'
    bundle.write_text(json.dumps({'version': 1, 'books': [entry]}), encoding='utf-8')
    monkeypatch.setattr(public, 'BUNDLE', bundle)
    public.books.cache_clear()
    storage = Storage()
    app = FastAPI()
    public.install(app, lambda: storage, lambda: 'test-owner')
    try:
        with TestClient(app) as client:
            catalogue = client.get('/marketplace/textbooks').json()['items']
            book_id = catalogue[0]['textbook_id']
            assert client.post('/marketplace/textbooks/' + book_id + '/purchase').status_code == 200
            saved = public.get_owned(lambda: storage, 'test-owner', book_id)
            assert saved['chapters'] == book['chapters']
            assert saved['schema_version'] == 2
    finally:
        public.books.cache_clear()
