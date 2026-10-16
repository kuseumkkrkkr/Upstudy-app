import copy
import pytest
from api.book_activity import validate_activity
from api.textbook_import import validate_book


def activity(statistics=None):
    return {'id':'estimation', 'kind':'statisticsEstimator', 'prompt':'Estimate from a sample',
            'hints':['Compare another sample'],
            'statistics': statistics or {'mode':'mean','sample_values':[2,4,6]}}


@pytest.mark.parametrize('statistics', [
    {'mode':'mean','sample_values':[2,4,6]},
    {'mode':'mean','sample_values':[-1000000,1000000]},
    {'mode':'proportion','successes':0,'trials':1},
    {'mode':'proportion','successes':100000,'trials':100000},
])
def test_definition_only_statistics_preserved(statistics):
    value=activity(statistics)
    original=copy.deepcopy(value)
    assert validate_activity(value)==original
    book={'schema_version':2,'title':'QA','chapters':[{'title':'Chapter','pages':[
        {'id':'p','title':'Estimate','template':'experiment','blocks':[{'type':'activity','activity':value}]}]}]}
    assert validate_book(book)==book


@pytest.mark.parametrize('statistics', [
    {'mode':'median','sample_values':[1]},
    {'mode':'mean','sample_values':[]},
    {'mode':'mean','sample_values':None},
    {'mode':'mean','sample_values':[True]},
    {'mode':'mean','sample_values':[float('nan')]},
    {'mode':'mean','sample_values':[1000001]},
    {'mode':'mean','sample_values':[1]*201},
    {'mode':'mean','sample_values':[1],'trials':2},
    {'mode':'proportion','successes':1,'trials':0},
    {'mode':'proportion','successes':2,'trials':1},
    {'mode':'proportion','successes':-1,'trials':1},
    {'mode':'proportion','successes':True,'trials':2},
    {'mode':'proportion','successes':1,'trials':2.0},
    {'mode':'proportion','successes':1,'trials':100001},
    {'mode':'proportion','successes':1,'trials':2,'confidence':.95},
    None,
])
def test_invalid_statistics_rejected(statistics):
    value=activity()
    value['statistics']=statistics
    with pytest.raises(ValueError): validate_activity(value)


def test_cannot_import_learner_or_executable_state():
    for key in ['estimate','input','script','html','student_id','confidence_interval']:
        with pytest.raises(ValueError): validate_activity({**activity(),key:'forbidden'})
