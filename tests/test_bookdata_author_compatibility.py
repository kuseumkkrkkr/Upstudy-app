"""Compatibility never implies content review or publication approval."""
import copy
import json

import pytest

from api.textbook_import import validate_book
from tools.build_public_textbooks import prepare
from tools.audit_bookdata_roundtrip import audit


def draft():
    return {'title': 'Synthetic', 'tags': [f'tag-{i}' for i in range(48)],
            'chapters': [{'title': 'Chapter', 'pages': [{'template': 'concept',
                'blocks': [{'type': 'standard', 'title': 'Standard', 'text': 'Keep exactly'},
                    {'type': 'visual', 'visual': {'kind': 'area-model',
                        'title': 'Pieces', 'formula': '(x+a)^2',
                        'items': ['x²', 'ax', 'ax', 'a²']}}]}]}]}


def test_preserves_standard_area_pieces_and_all_tags():
    original = draft()
    entry = prepare(json.dumps(original))
    assert json.loads(entry['source']) == original
    assert validate_book(copy.deepcopy(original)) == original
    original['chapters'][0]['pages'][0]['blocks'][1]['visual']['items'].pop()
    with pytest.raises(ValueError, match='four labelled pieces'):
        validate_book(original)


def test_only_missing_version_can_upgrade_registered_activities():
    original = draft()
    original['chapters'][0]['pages'][0]['blocks'].append({'type': 'activity',
        'activity': {'id': 'quiz', 'kind': 'quiz', 'prompt': 'One?', 'answer': 1,
                     'correct_feedback': 'Yes', 'incorrect_feedback': 'Retry'}})
    before = copy.deepcopy(original)
    entry = prepare(json.dumps(original))
    assert original == before
    runtime = json.loads(entry['source'])
    assert runtime == {**original, 'schema_version': 2}
    assert entry['source_metadata']['annotations']['schema_migration'] == {'from': 'omitted', 'to': 2}
    with pytest.raises(ValueError, match='requires schema_version 2'):
        prepare(json.dumps({**original, 'schema_version': 1}))
    original['chapters'][0]['pages'][0]['blocks'][-1]['activity']['kind'] = 'execute-js'
    with pytest.raises(ValueError, match='unsupported registered kind'):
        prepare(json.dumps(original))


def test_tag_limit_remains_bounded_and_unknown_visuals_rejected():
    original = draft()
    original['tags'] = ['tag'] * 65
    with pytest.raises(ValueError, match='64 entries'):
        validate_book(original)
    original = draft()
    original['chapters'][0]['pages'][0]['blocks'][1]['visual']['kind'] = 'author-html'
    with pytest.raises(ValueError, match='unsupported kind'):
        validate_book(original)


def test_private_audit_reconstructs_annotations_without_claiming_approval(tmp_path):
    original = draft()
    original['teacher_review_status'] = 'pending'
    original['metadata'] = {'rights': 'not established'}
    original['chapters'][0]['unitTitle'] = 'Keep author annotation'
    source = json.dumps(original, ensure_ascii=False)
    path = tmp_path / 'synthetic_BookData.json'
    path.write_text(source, encoding='utf-8')
    report, fixture = audit(tmp_path)
    assert report['passed'] == 1 and report['blocked'] == 0
    assert 'not content or rights approval' in report['purpose']
    assert path.read_text(encoding='utf-8') == source
    assert fixture[0]['book']['chapters'][0]['pages'] == original['chapters'][0]['pages']
    assert 'teacher_review_status' not in fixture[0]['book']


def test_reserved_x_does_not_become_an_ignored_slider(tmp_path):
    original = draft()
    original['chapters'][0]['pages'][0]['blocks'].append({'type': 'graph', 'graph': {
        'items': [{'type': 'function', 'expression': 'x*x'}],
        'settings': {'parameters': [{'id': 'x', 'value': 1, 'min': -2, 'max': 2, 'step': .1}]}}})
    (tmp_path / 'blocked_BookData.json').write_text(json.dumps(original), encoding='utf-8')
    report, fixture = audit(tmp_path)
    assert report['blocked'] == 1 and fixture == []
    assert report['records'][0]['error'] == 'graph.parameter: invalid or duplicate identifier'
