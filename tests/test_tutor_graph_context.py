import pytest
from pydantic import ValidationError
from api.index import ServerChatMessageRequest
from tests.test_tutor_history import chat


def observation():
    return {'graph_id': 'page-1-graph-0', 'parameters': [
        {'id': 'p', 'value': 2.5, 'min': .5, 'max': 3.0}]}


def test_observation_is_reference_data_and_never_a_system_message(chat):
    client, requests = chat
    payload = {'user_message': '어떻게 달라졌나요?', 'graph_context': [observation()]}
    assert client.post('/serverchat/message', json=payload).status_code == 200
    messages = requests[-1]['messages']
    assert len([m for m in messages if m['role'] == 'system']) == 1
    assert '학생 제공 참고값' in messages[1]['content']
    assert '2.5' in messages[1]['content']


@pytest.mark.parametrize('value', [True, '2', float('nan'), float('inf'), -1, 4])
def test_invalid_value_rejected(value):
    graph = observation()
    graph['parameters'][0]['value'] = value
    with pytest.raises(ValidationError):
        ServerChatMessageRequest(user_message='hello', graph_context=[graph])


@pytest.mark.parametrize('alter', [
    lambda g: g.update(script='alert(1)'),
    lambda g: g.update(graph_id='other-owner-book'),
    lambda g: g['parameters'][0].update(id='constructor'),
    lambda g: g['parameters'].append(dict(g['parameters'][0])),
    lambda g: g['parameters'][0].update(expression='eval(x)'),
])
def test_unregistered_fields_names_duplicates_rejected(alter):
    graph = observation()
    alter(graph)
    with pytest.raises(ValidationError):
        ServerChatMessageRequest(user_message='hello', graph_context=[graph])


def test_graph_count_bounded_and_old_clients_compatible():
    assert ServerChatMessageRequest(user_message='hello').graph_context == []
    with pytest.raises(ValidationError):
        ServerChatMessageRequest(user_message='hello', graph_context=[observation()]*5)
