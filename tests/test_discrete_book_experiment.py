import copy
import pytest
from api.book_activity import validate_activity
from api.textbook_import import validate_book


def experiment():
    return {'id':'dice', 'kind':'discreteExperiment', 'prompt':'Test event frequency',
            'experiment':{'outcomes':[{'label':'never','weight':0,'success':False},
                                       {'label':'always','weight':1,'success':True}],
                          'max_trials':15,'batch_sizes':[1,10]}}


def test_registered_experiment_keeps_definition_not_learner_state():
    activity = experiment()
    assert validate_activity(activity) == activity
    book = {'schema_version':2,'title':'Synthetic experiment','chapters':[{'title':'Chapter',
        'pages':[{'id':'p','title':'Experiment','template':'experiment',
                  'blocks':[{'type':'activity','activity':activity}]}]}]}
    assert validate_book(book) == book


@pytest.mark.parametrize('change', [
    {'max_trials':True}, {'max_trials':None}, {'max_trials':100001}, {'batch_sizes':[True]},
    {'batch_sizes':None},
    {'batch_sizes':[10,10]}, {'batch_sizes':[16]}, {'batch_sizes':[1001]},
    {'outcomes':[]}, {'initial_trials':100}, {'html':'<script>bad()</script>'},
])
def test_invalid_experiment_configuration_rejected(change):
    value = experiment()
    value['experiment'].update(change)
    with pytest.raises(ValueError): validate_activity(value)


def test_common_optional_null_is_not_a_default():
    with pytest.raises(ValueError): validate_activity({**experiment(), 'hints':None})


@pytest.mark.parametrize('change', [{'weight':-1}, {'weight':None}, {'weight':float('inf')}, {'weight':True},
                                  {'label':'always'}, {'success':1}, {'script':'bad'}])
def test_invalid_outcome_rejected(change):
    value = experiment()
    value['experiment']['outcomes'][0].update(change)
    with pytest.raises(ValueError): validate_activity(value)


def test_zero_mass_rejected_and_no_in_place_rewrite():
    value = experiment()
    frozen = copy.deepcopy(value)
    validate_activity(value)
    assert value == frozen
    value['experiment']['outcomes'][1]['weight'] = 0
    with pytest.raises(ValueError): validate_activity(value)
