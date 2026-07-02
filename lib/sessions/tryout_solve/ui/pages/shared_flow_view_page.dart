import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/flow_view_page.dart';

class SharedFlowViewPage extends StatefulWidget {
  const SharedFlowViewPage({super.key, required this.shareId, this.title});

  final String shareId;
  final String? title;

  @override
  State<SharedFlowViewPage> createState() => _SharedFlowViewPageState();
}

class _SharedFlowViewPageState extends State<SharedFlowViewPage> {
  SharedFlowItem? _flow;
  Map<String, dynamic>? _quest;
  List<Map<String, dynamic>>? _stepCorrectness;
  bool _loading = true;
  String? _error;
  String? _username;

  @override
  void initState() {
    super.initState();
    AuthStorage.instance.readUsername().then((v) {
      if (mounted) setState(() => _username = v);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final flow = await ApiClient.instance.getSharedFlow(widget.shareId);
      List<Map<String, dynamic>>? stepCorrectness;
      try {
        stepCorrectness = _decodeStepCorrectness(flow.statusJson);
      } catch (_) {}

      Map<String, dynamic>? quest;
      try {
        quest = await ApiClient.instance.replayProblemHabit(
          codebaseId: flow.codebaseId,
          seed: flow.seed.toString(),
          questId: flow.questId.isNotEmpty ? flow.questId : null,
        );
      } catch (_) {
        quest = null;
      }

      // flow의 allFormulas(학생 제출 공식)를 quest data에 병합
      // quest['data']['all_formulas']는 기본적으로 비어 있으므로
      // 공유 당시 학생이 제출한 공식으로 덮어씌움
      if (quest != null) {
        final data = Map<String, dynamic>.from(
          (quest['data'] as Map<String, dynamic>?) ?? {},
        );
        if (flow.allFormulas.isNotEmpty) {
          data['all_formulas'] = flow.allFormulas;
        }
        if (flow.answerRiddle.isNotEmpty) {
          data['answer_riddle'] = flow.answerRiddle;
        }
        quest = {...quest, 'data': data};
      }

      setState(() {
        _flow = flow;
        _quest = quest;
        _stepCorrectness = stepCorrectness;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '불러오기 실패: ';
      });
    }
  }

  List<Map<String, dynamic>>? _decodeStepCorrectness(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    final statusList = decoded is Map ? decoded['status'] : decoded;
    if (statusList is! List) return null;
    final List<Map<String, dynamic>> result = [];
    for (final entry in statusList) {
      if (entry is Map) {
        final status = entry['status']?.toString().toUpperCase();
        result.add({'correct': status == 'O'});
      }
    }
    return result.isEmpty ? null : result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _flow == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? '공유된 플로우')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? '플로우를 불러올 수 없습니다.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _load,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_quest == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? '공유된 플로우')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('문제 원본을 불러오지 못했습니다.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _load,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return FlowViewPage(
      quest: _quest!,
      title: widget.title ?? 'AIflow',
      sharedMode: true,
      stepCorrectness: _stepCorrectness,
      sharedMeta: SharedMeta(
        shareId: _flow!.shareId,
        userId: _flow!.userId,
        createdAt: _flow!.createdAt?.toIso8601String() ?? '',
        tags: _flow!.tags,
        difficulty: _flow!.difficulty,
        canDelete: _username != null && _username == _flow!.userId,
      ),
    );
  }
}
