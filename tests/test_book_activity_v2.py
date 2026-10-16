import copy
import pytest
from api.book_activity import validate_activity
from api.textbook_import import validate_book, migrate_v1_to_v2


def quiz():
    return dict(id='quiz-1', kind='quiz', prompt='Choose', options=['A', 'B'],
                correct_index=1, correct_feedback='Correct', incorrect_feedback='Try the hint', hints=['Compare distances'])


def book(activity):
    return dict(schema_version=2, title='Synthetic V2', chapters=[dict(title='Chapter', pages=[
        dict(id='p1', title='Practice', template='practice', blocks=[dict(type='activity', activity=activity)])])])


def test_registered_activities_and_lossless_migration():
    for value in [quiz(), dict(id='n', kind='quiz', prompt='Half?', answer=.5, tolerance=.001,
                              correct_feedback='Yes', incorrect_feedback='Retry'),
                  dict(id='s', kind='steps', prompt='Reason', steps=['First', 'Next', 'Last']),
                  dict(id='p', kind='parabolaDistance', prompt='Compare', p=2, x=4)]:
        assert validate_book(book(value)) == book(value)
    original = dict(title='V1', chapters=[dict(title='Keep', sections=[dict(title='Original', paragraphs=['Preserved'])])])
    frozen = copy.deepcopy(original)
    migrated = migrate_v1_to_v2(original)
    assert original == frozen and migrated == dict(original, schema_version=2)


@pytest.mark.parametrize('change', [dict(kind='html'), dict(script='alert(1)'), dict(correct_index=True),
                                  dict(correct_index=4), dict(answer=1), dict(options=['Only']),
                                  dict(hints=['x'] * 9), dict(prompt='')])
def test_invalid_quiz_is_rejected(change):
    with pytest.raises(ValueError):
        validate_activity(dict(quiz(), **change))


def test_versions_and_duplicate_activity_ids_rejected():
    value = book(quiz())
    for version in [1, 3, True, 2.0]:
        with pytest.raises(ValueError):
            validate_book(dict(value, schema_version=version))
    blocks = value['chapters'][0]['pages'][0]['blocks']
    blocks.append(copy.deepcopy(blocks[0]))
    with pytest.raises(ValueError, match='duplicate'):
        validate_book(value)


@pytest.mark.parametrize('p,x', [(0, 0), (4, 0), (2, 5), (float('inf'), 0)])
def test_geometry_is_bounded(p, x):
    with pytest.raises(ValueError):
        validate_activity(dict(id='p', kind='parabolaDistance', prompt='Compare', p=p, x=x))
