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
