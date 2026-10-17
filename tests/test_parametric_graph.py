"""Local synthetic graph contract; no DB, publication or external AI."""
import copy
import json
from pathlib import Path
import pytest
from api.textbook_import import validate_book


def book():
    return json.loads(Path('test/fixtures/parametric_reader.json').read_text(encoding='utf-8'))


def test_parametric_contract_preserves_bounded_expressions_and_trace():
    candidate = book()
    before = copy.deepcopy(candidate)
    validate_book(candidate)
    assert candidate == before


@pytest.mark.parametrize('field,value', [
    ('xExpression', 'window.alert(1)'), ('yExpression', 't.__class__'),
    ('xExpression', 'x+1'), ('yExpression', '__import__("os")'),
    ('tMin', True), ('tMax', float('nan')), ('tMax', -2),
    ('traceParameterId', 'missing'), ('traceParameterId', {}),
])
def test_invalid_parametric_input_is_rejected(field, value):
    candidate = book()
    candidate['chapters'][0]['pages'][0]['blocks'][1]['graph']['items'][0][field] = value
    with pytest.raises(ValueError):
        validate_book(candidate)


def test_trace_domain_and_independent_variable_do_not_conflict():
    for field, value in [('min', -3), ('id', 't')]:
        candidate = book()
        candidate['chapters'][0]['pages'][0]['blocks'][1]['graph']['settings']['parameters'][0][field] = value
        with pytest.raises(ValueError):
            validate_book(candidate)


def canonical_book():
    candidate = book()
    item = candidate['chapters'][0]['pages'][0]['blocks'][1]['graph']['items'][0]
    item.pop('tMin')
    item.pop('tMax')
    item.update(xExpression='u^2', yExpression='u^3',
                parameterRange=dict(id='u', min=-2, max=2, step=0.05))
    return candidate


def test_canonical_range_is_non_mutating_and_legacy_aliases_must_match():
    validate_book(json.loads(Path('test/fixtures/canonical_parametric_reader.json').read_text(encoding='utf-8')))
    candidate = canonical_book()
    before = copy.deepcopy(candidate)
    validate_book(candidate)
    assert candidate == before
    item = candidate['chapters'][0]['pages'][0]['blocks'][1]['graph']['items'][0]
    item.update(tMin=-2, tMax=2)
    validate_book(candidate)
    item['tMax'] = 3
    with pytest.raises(ValueError, match='conflicting range aliases'):
        validate_book(candidate)


@pytest.mark.parametrize('field,value', [
    ('id', 'window'), ('id', 'x'), ('id', 'u.constructor'),
    ('min', True), ('max', float('inf')), ('step', 0), ('step', 5),
    ('futureField', 'not executable'),
])
def test_invalid_canonical_range_is_rejected(field, value):
    candidate = canonical_book()
    candidate['chapters'][0]['pages'][0]['blocks'][1]['graph']['items'][0]['parameterRange'][field] = value
    with pytest.raises(ValueError):
        validate_book(candidate)


@pytest.mark.parametrize('field,value', [('type', 'future'), ('futureItem', {'data': 1})])
def test_client_preservation_does_not_expand_server_approval(field, value):
    candidate = canonical_book()
    candidate['chapters'][0]['pages'][0]['blocks'][1]['graph']['items'][0][field] = value
    with pytest.raises(ValueError, match='unsupported|parametric fields require parametric type'):
        validate_book(candidate)
