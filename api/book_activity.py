"""V2 registered native activities; never accept author HTML, JS, or executable math."""
import math


def validate_activity(value):
    def fields(obj, allowed):
        if not isinstance(obj, dict) or set(obj) - set(allowed.split()):
            raise ValueError('activity: unsupported fields or invalid object')

    def text(value, limit=2000):
        if not isinstance(value, str) or not value.strip() or len(value) > limit:
            raise ValueError('activity: bounded nonempty text required')

    def texts(value, low, high):
        if not isinstance(value, list) or not low <= len(value) <= high:
            raise ValueError('activity: invalid list size')
        for item in value:
            text(item)

    def number(value):
        if type(value) not in (int, float) or not math.isfinite(value) or abs(value) > 1e6:
            raise ValueError('activity: bounded finite number required')

    if not isinstance(value, dict):
        raise ValueError('activity: object required')
    kind = value.get('kind')
    common = 'id kind prompt hints'
    if kind == 'quiz':
        fields(value, common + ' options correct_index answer tolerance correct_feedback incorrect_feedback')
        for field in ('correct_feedback', 'incorrect_feedback'):
            text(value.get(field))
        if 'options' in value:
            texts(value['options'], 2, 6)
            index = value.get('correct_index')
            if type(index) is not int or not 0 <= index < len(value['options']):
                raise ValueError('activity: invalid correct_index')
            if 'answer' in value or 'tolerance' in value:
                raise ValueError('activity: mixed quiz modes')
        else:
            number(value.get('answer'))
            number(value.get('tolerance', 0))
            if value.get('tolerance', 0) < 0 or 'correct_index' in value:
                raise ValueError('activity: invalid numeric answer')
    elif kind == 'steps':
        fields(value, common + ' steps')
        texts(value.get('steps'), 1, 12)
    elif kind == 'parabolaDistance':
        fields(value, common + ' p x')
        for name, low, high in [('p', .5, 3), ('x', -4, 4)]:
            number(value.get(name))
            if not low <= value[name] <= high:
                raise ValueError('activity: parabola parameter out of range')
    else:
        raise ValueError('activity: unsupported registered kind')
    text(value.get('id'), 80)
    text(value.get('prompt'))
    texts(value.get('hints', []), 0, 8)
    return value
