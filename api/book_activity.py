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
    elif kind == 'discreteExperiment':
        fields(value, common + ' experiment')
        experiment = value.get('experiment')
        fields(experiment, 'outcomes max_trials batch_sizes')
        outcomes = experiment.get('outcomes')
        if not isinstance(outcomes, list) or not 2 <= len(outcomes) <= 32:
            raise ValueError('activity: experiment requires 2..32 outcomes')
        labels, total_weight = set(), 0
        for outcome in outcomes:
            fields(outcome, 'label weight success')
            label = outcome.get('label')
            text(label, 120)
            weight = outcome.get('weight', 1)
            number(weight)
            if weight < 0 or type(outcome.get('success')) is not bool or label in labels:
                raise ValueError('activity: invalid or duplicate outcome')
            labels.add(label)
            total_weight += weight
        if total_weight <= 0:
            raise ValueError('activity: positive total weight required')
        maximum = experiment.get('max_trials', 10000)
        if type(maximum) is not int or not 1 <= maximum <= 100000:
            raise ValueError('activity: invalid trial limit')
        batches = experiment.get('batch_sizes', [1])
        if not isinstance(batches, list) or not 1 <= len(batches) <= 4:
            raise ValueError('activity: invalid batch sizes')
        if any(type(n) is not int or not 1 <= n <= min(1000, maximum) for n in batches) or len(set(batches)) != len(batches):
            raise ValueError('activity: invalid or duplicate batch sizes')
    elif kind == 'statisticsEstimator':
        fields(value, common + ' statistics')
        statistics = value.get('statistics')
        if not isinstance(statistics, dict):
            raise ValueError('activity: statistics object required')
        if statistics.get('mode') == 'mean':
            fields(statistics, 'mode sample_values')
            samples = statistics.get('sample_values')
            if not isinstance(samples, list) or not 1 <= len(samples) <= 200:
                raise ValueError('activity: sample requires 1..200 values')
            for sample in samples:
                number(sample)
        elif statistics.get('mode') == 'proportion':
            fields(statistics, 'mode successes trials')
            successes, trials = statistics.get('successes'), statistics.get('trials')
            if type(trials) is not int or not 1 <= trials <= 100000 or type(successes) is not int or not 0 <= successes <= trials:
                raise ValueError('activity: invalid sample counts')
        else:
            raise ValueError('activity: unsupported estimation mode')
    elif kind in ('coordinatePoint', 'coordinateWalk'):
        fields(value, common + ' x y' + (' duration_ms' if kind == 'coordinateWalk' else ''))
        if kind == 'coordinateWalk' and (type(value.get('duration_ms')) is not int or value['duration_ms'] != 1500):
            raise ValueError('activity: coordinate walk duration must be integer 1500ms')
        for name in ('x', 'y'):
            if type(value.get(name)) is not int or not -5 <= value[name] <= 5:
                raise ValueError('activity: coordinates require integers -5..5')
    elif kind == 'vectorOperation':
        fields(value, common + ' operation ux uy vx vy alpha')
        if value.get('operation') not in ('add', 'subtract', 'scalar'):
            raise ValueError('activity: unsupported plane vector operation')
        for name in ('ux', 'uy', 'vx', 'vy'):
            if type(value.get(name)) is not int or not -4 <= value[name] <= 4:
                raise ValueError('activity: vector components require integers -4..4')
        alpha = value.get('alpha')
        number(alpha)
        if not -2 <= alpha <= 2 or not math.isclose(alpha * 2, round(alpha * 2), rel_tol=0, abs_tol=1e-9):
            raise ValueError('activity: scalar coefficient requires half steps in -2..2')
    elif kind == 'rightTriangle':
        fields(value, common + ' a b')
        for name in ('a', 'b'):
            number(value.get(name))
            if type(value[name]) is not int or not 1 <= value[name] <= 12:
                raise ValueError('activity: triangle legs require integers 1..12')
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
