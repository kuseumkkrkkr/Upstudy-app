"""Three bounded numeric explorer contracts, never executable expressions."""
import math

KINDS = {'radicalFunctionExplorer', 'rationalFunctionExplorer', 'logarithmPowerExplorer'}


def validate_explorer(kind, data):
    def fail():
        raise ValueError('activity: invalid bounded function explorer')

    def number(value, bound=10):
        if type(value) not in (int, float) or abs(value) > bound or not math.isfinite(value):
            fail()
        return value

    if kind not in KINDS or not isinstance(data, dict):
        fail()
    power = kind == 'logarithmPowerExplorer'
    names = ('exponent',) if power else (('b', 'c') if kind == 'radicalFunctionExplorer' else ('h', 'k'))
    fields = {'bases', 'initial_base'} if power else {'a_values', 'initial_a'}
    for name in names:
        fields.update({f'min_{name}', f'max_{name}', f'initial_{name}', 'step' if power else f'{name}_step'})
    if set(data) != fields:
        fail()
    values = data['bases' if power else 'a_values']
    if not isinstance(values, list) or not 2 <= len(values) <= (8 if power else 6):
        fail()
    for value in values:
        number(value, 100 if power else 5)
        if (power and (value <= 0 or abs(value - 1) < 1e-9)) or (not power and abs(value) < .1):
            fail()
    if len(set(values)) != len(values):
        fail()
    initial = number(data['initial_base' if power else 'initial_a'], 100 if power else 5)
    if initial not in values:
        fail()
    for name in names:
        low, high = number(data[f'min_{name}']), number(data[f'max_{name}'])
        step = number(data['step' if power else f'{name}_step'])
        start = number(data[f'initial_{name}'])
        if low >= high or not 0 < step <= 1 or not low <= start <= high:
            fail()
        divisions, offset = (high - low) / step, (start - low) / step
        if not 1 <= divisions <= 400 or abs(divisions - round(divisions)) > 1e-9 or abs(offset - round(offset)) > 1e-9:
            fail()
        if power:
            if low < -4 or high > 4:
                fail()
            for base in values:
                for exponent in (low, high):
                    try:
                        result = base ** exponent
                    except (OverflowError, ZeroDivisionError):
                        fail()
                    if not math.isfinite(result) or not 1e-6 <= result <= 1e6:
                        fail()
    return data
