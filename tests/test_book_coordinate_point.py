import copy
import hashlib
import json
from pathlib import Path
import pytest
from api.book_activity import validate_activity
from api.textbook_import import parse_import, validate_book


def point():
    return {'id': 'point', 'kind': 'coordinatePoint', 'prompt': 'Move A',
            'x': -2, 'y': 3, 'hints': ['Horizontal, then vertical']}


def graph():
    return {'items': [
        {'id': 'f', 'type': 'function', 'expression': 'x*x/(4*p)'},
        {'id': 'line', 'type': 'line', 'xValues': [-1, 1], 'yValues': [2, 3]},
        {'id': 'scatter', 'type': 'scatter', 'xValues': [0], 'yValues': [4]},
    ], 'settings': {'parameters': [{'id': 'p', 'value': 2, 'min': .5, 'max': 3, 'step': .5}]}}


def book():
    return {'schema_version': 2, 'title': 'Synthetic', 'chapters': [{
        'title': 'Chapter', 'pages': [{'id': 'p', 'title': 'Explore', 'template': 'experiment',
        'blocks': [{'type': 'activity', 'activity': point()}, {'type': 'graph', 'graph': graph()}]}]}]}


def test_v2_import_and_old_graph_fields_are_lossless_v1_not_upgraded():
    value = book()
    original = copy.deepcopy(value)
    source = json.dumps(value)
    parsed, digest = parse_import(source, hashlib.sha256(source.encode()).hexdigest())
    assert parsed == original and digest == hashlib.sha256(source.encode()).hexdigest()
    old = copy.deepcopy(value)
    old['schema_version'] = 1
    with pytest.raises(ValueError): validate_book(old)
    old['chapters'][0]['pages'][0]['blocks'].pop(0)
    assert validate_book(old) == old  # Existing V1 function/line/scatter unchanged.


@pytest.mark.parametrize('value', [None, True, False, -6, 6, 2.0, '2', float('nan'), float('inf')])
@pytest.mark.parametrize('field', ['x', 'y'])
def test_coordinate_types_bounds(value, field):
    with pytest.raises(ValueError): validate_activity({**point(), field: value})


def test_all_121_points_and_forbidden_imported_state():
    for x in range(-5, 6):
        for y in range(-5, 6):
            assert validate_activity({**point(), 'x': x, 'y': y})['y'] == y
    for field in ['script', 'jsx', 'html', 'onDrag', 'state', 'step', 'quadrant', 'student_id']:
        with pytest.raises(ValueError): validate_activity({**point(), field: 'forbidden'})


def test_documented_schema_agrees_with_runtime_fields_and_bounds():
    schema = json.loads(Path('deploy/vercel/book_coordinate_point.schema.json').read_text())
    assert schema['additionalProperties'] is False
    assert set(schema['properties']) == {'id', 'kind', 'prompt', 'hints', 'x', 'y'}
    assert schema['required'] == ['id', 'kind', 'prompt', 'x', 'y']
    assert schema['properties']['x'] == schema['properties']['y'] == {
        'type': 'integer', 'minimum': -5, 'maximum': 5}
