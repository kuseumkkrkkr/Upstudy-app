import hashlib
import json
from pathlib import Path
import pytest
from api.book_activity import validate_activity
from api.textbook_import import parse_import


def walk():
    return {'id': 'walk', 'kind': 'coordinateWalk', 'prompt': 'Walk coordinates',
            'x': -3, 'y': 2, 'duration_ms': 1500, 'hints': ['Horizontal then vertical']}


def test_distinct_kind_lossless_import_and_existing_point_unchanged():
    for activity in [walk(), {'id':'point','kind':'coordinatePoint','prompt':'Point','x':-2,'y':3}]:
        book = {'schema_version':2,'title':'Synthetic','chapters':[{'title':'C','pages':[
            {'id':'p','title':'Walk','template':'experiment','blocks':[{'type':'activity','activity':activity}]}]}]}
        source = json.dumps(book)
        parsed, digest = parse_import(source, hashlib.sha256(source.encode()).hexdigest())
        assert parsed == book
        assert digest == hashlib.sha256(source.encode()).hexdigest()
    with pytest.raises(ValueError):
        validate_activity({**walk(), 'kind':'coordinatePoint'})


@pytest.mark.parametrize('value', [None, True, 0, 1499, 1501, 1500.0, '1500', float('inf')])
def test_strict_fixed_duration(value):
    with pytest.raises(ValueError): validate_activity({**walk(),'duration_ms':value})


@pytest.mark.parametrize('field,value', [('x',6),('y',-6),('x',True),('y',2.0),('x',None)])
def test_walk_coordinate_bounds(field,value):
    with pytest.raises(ValueError): validate_activity({**walk(),field:value})


def test_no_imported_running_state_or_code_and_schema_contract():
    for key in ['progress','running','paused','timer','script','jsx','onfinish','easing']:
        with pytest.raises(ValueError): validate_activity({**walk(),key:'forbidden'})
    value=walk(); value.pop('duration_ms')
    with pytest.raises(ValueError): validate_activity(value)
    schema=json.loads(Path('deploy/vercel/book_coordinate_walk.schema.json').read_text())
    assert schema['additionalProperties'] is False
    assert schema['properties']['duration_ms']=={'type':'integer','const':1500}
    assert set(schema['properties'])==set(walk())
