import copy
import json
from pathlib import Path
import pytest
from api.book_activity import validate_activity
from api.book_function_explorer import validate_explorer
from api.textbook_import import validate_book
from tools.build_public_textbooks import prepare
from tools.audit_bookdata_roundtrip import audit

FIXTURE = Path(__file__).resolve().parents[1] / 'test/fixtures/function_explorers.json'


def activities():
    return [p['blocks'][0]['activity'] for p in json.loads(FIXTURE.read_text(encoding='utf-8'))['chapters'][0]['pages']]


@pytest.mark.parametrize('activity', activities())
def test_three_fixed_formulas_accept_only_their_numeric_contract(activity):
    original = copy.deepcopy(activity)
    assert validate_activity(activity) == original
    assert activity == original
    for payload in (None, [], {**activity['explorer'], 'script': 'not executable'},
                    {**activity['explorer'], 'initial_a': True}):
        with pytest.raises(ValueError):
            validate_activity({**activity, 'explorer': payload})
    with pytest.raises(ValueError):
        validate_activity({**activity, 'onclick': 'bad'})


@pytest.mark.parametrize('index,change', [
    (0, {'a_values': [0,1]}), (0, {'a_values': [1,1]}),
    (0, {'initial_a': 3}), (0, {'a_values': [.00001,1]}),
    (0, {'initial_b': .2}), (0, {'b_step': .000001}),
    (0, {'min_b': 3}), (0, {'max_c': float('inf')}),
    (1, {'h_step': 0}), (1, {'initial_k': -4}),
    (2, {'bases': [1,2]}), (2, {'bases': [-2,2]}),
    (2, {'bases': [1e-100,2]}), (2, {'step': .3}),
    (2, {'initial_exponent': .1}), (2, {'min_exponent': -5}),
    (2, {'bases': [10**1000, 2]}), (2, {'initial_base': True}),
])
def test_invalid_ranges_types_complexity_and_overflow_rejected(index, change):
    activity = activities()[index]
    with pytest.raises(ValueError):
        validate_explorer(activity['kind'], {**activity['explorer'], **change})


def test_lossless_explicit_metadata_migration_and_roundtrip(tmp_path):
    source = FIXTURE.read_text(encoding='utf-8')
    original = json.loads(source)
    entry = prepare(source)
    runtime = json.loads(entry['source'])
    assert runtime == original
    assert runtime['candidate_standard_codes'] == ['candidate-only']
    assert runtime['chapters'][0]['candidate_standard_codes'] == []
    assert runtime['chapters'][0]['source_html_reference'] == 'synthetic-reference.html'
    assert entry['source_metadata']['annotations']['chapters'] == [{}]
    (tmp_path/'Synthetic_BookData.json').write_text(source, encoding='utf-8')
    report, _ = audit(tmp_path)
    assert report['passed'] == 1 and report['blocked'] == 0
    assert (tmp_path/'Synthetic_BookData.json').read_text(encoding='utf-8') == source
    with pytest.raises(ValueError):
        validate_book({**original, 'schema_version': 1})
    with pytest.raises(ValueError):
        prepare(json.dumps({**original, 'unregistered_metadata': {}}))
