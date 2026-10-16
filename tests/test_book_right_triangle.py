import copy
import hashlib
import json
import pytest
from api.book_activity import validate_activity
from api.textbook_import import parse_import, validate_book


def triangle():
    return {'id': 'triangle', 'kind': 'rightTriangle', 'prompt': 'Compare lengths',
            'a': 6, 'b': 8, 'hints': ['Compare the squares']}


def book():
    return {'schema_version': 2, 'title': 'Synthetic', 'chapters': [{
        'title': 'Chapter', 'pages': [{'id': 'p', 'title': 'Explore',
        'template': 'experiment', 'blocks': [{'type': 'activity', 'activity': triangle()}]}]}]}


def test_import_preserves_definition_and_v1_never_silently_downgrades():
    value = book()
    source = json.dumps(value)
    digest = hashlib.sha256(source.encode()).hexdigest()
    parsed, actual_digest = parse_import(source, digest)
    assert parsed == value and actual_digest == digest
    assert validate_book(value) == value
    old = copy.deepcopy(value)
    old['schema_version'] = 1
    with pytest.raises(ValueError):
        validate_book(old)


@pytest.mark.parametrize('value', [None, True, 0, 13, 6.0, '6', float('nan'), float('inf')])
@pytest.mark.parametrize('field', ['a', 'b'])
def test_strict_integer_leg_bounds(value, field):
    with pytest.raises(ValueError):
        validate_activity({**triangle(), field: value})


def test_no_imported_script_answer_or_learner_state():
    for field in ['script', 'html', 'c', 'student_id', 'input', 'state']:
        with pytest.raises(ValueError):
            validate_activity({**triangle(), field: 'forbidden'})
    for a in (1, 12):
        for b in (1, 12):
            assert validate_activity({**triangle(), 'a': a, 'b': b})['a'] == a
