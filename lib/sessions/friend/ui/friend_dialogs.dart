part of 'package:s11/sessions/friend/friend.dart';

class _GroupCreateDialogBody extends StatefulWidget {
  const _GroupCreateDialogBody({required this.onCreate});

  final void Function(_GroupInfo group) onCreate;

  @override
  State<_GroupCreateDialogBody> createState() => _GroupCreateDialogBodyState();
}

class _GroupCreateDialogBodyState extends State<_GroupCreateDialogBody> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _lockEnabled = false;
  int? _selectedLogo;
  bool _nameInvalid = false;
  bool _descriptionInvalid = false;
  bool _maxInvalid = false;
  bool _passwordInvalid = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidPassword(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 4 || trimmed.length > 10) return false;
    return RegExp(r'^\d+$').hasMatch(trimmed);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final maxMembers = int.tryParse(_maxController.text.trim()) ?? 0;
    final password = _passwordController.text.trim();

    final nameOk = name.isNotEmpty;
    final descriptionOk = description.isNotEmpty;
    final maxOk = maxMembers > 0;
    final passwordOk = !_lockEnabled || _isValidPassword(password);

    setState(() {
      _nameInvalid = !nameOk;
      _descriptionInvalid = !descriptionOk;
      _maxInvalid = !maxOk;
      _passwordInvalid = _lockEnabled && !passwordOk;
    });

    if (!nameOk || !descriptionOk || !maxOk || !passwordOk) return;

    final logoIndex =
        _selectedLogo ??
        Random().nextInt(_SoWidgetState._groupLogoIcons.length);

    setState(() {
      _isSubmitting = true;
    });

    try {
      final group = await ApiClient.instance.createStudyGroup(
        name: name,
        description: description,
        maxMembers: maxMembers,
        isPublic: !_lockEnabled,
        logoIndex: logoIndex,
        lockEnabled: _lockEnabled,
        password: _lockEnabled ? password : null,
      );
      if (!mounted) return;
      widget.onCreate(
        _GroupInfo(
          id: group.groupId,
          name: group.name,
          description: group.description ?? '',
          maxMembers: group.maxMembers,
          members: group.memberIds.length,
          isPublic: group.isPublic,
          logoIndex: group.logoIndex,
          lockEnabled: group.lockEnabled,
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('그룹스터디 생성에 실패했어요.')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPassword = _lockEnabled;
    final primaryColor = _SoWidgetState.primaryColor;
    final bgColor = _SoWidgetState.bgColor;
    final groupLogoIcons = _SoWidgetState._groupLogoIcons;
    final groupLogoColors = _SoWidgetState._groupLogoColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('새 그룹스터디를 만들어 친구를 초대하세요.', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: '그룹스터디 이름',
            errorText: _nameInvalid ? '이름을 입력해 주세요' : null,
            filled: true,
            fillColor: bgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: '그룹스터디 설명',
            errorText: _descriptionInvalid ? '설명을 입력해 주세요' : null,
            filled: true,
            fillColor: bgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _maxController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            hintText: '그룹스터디 최대 인원',
            helperText: '숫자만 입력',
            errorText: _maxInvalid ? '최대 인원을 입력해 주세요' : null,
            filled: true,
            fillColor: bgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '프로필 사진',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('업로드 기능 준비 중')));
              },
              icon: const Icon(Icons.upload),
              label: const Text('업로드'),
            ),
            const SizedBox(width: 12),
            const Text(
              '로고 선택 또는 미선택 시 랜덤',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(groupLogoIcons.length, (index) {
            final color = groupLogoColors[index];
            final icon = groupLogoIcons[index];
            final isSelected = _selectedLogo == index;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedLogo = index;
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              '비밀번호 설정',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Switch(
              value: _lockEnabled,
              activeThumbColor: primaryColor,
              onChanged: (value) {
                setState(() {
                  _lockEnabled = value;
                  _passwordInvalid = false;
                });
              },
            ),
          ],
        ),
        if (showPassword) ...[
          TextField(
            controller: _passwordController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              hintText: '숫자 4~10자리',
              helperText: '잠금 시 숫자만 입력할 수 있어요',
              errorText: _passwordInvalid ? '4~10자리 숫자를 입력해 주세요' : null,
              filled: true,
              fillColor: bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: const Text('만들기'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onOpenActions});

  final _FriendInfo friend;
  final VoidCallback onOpenActions;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTap: onOpenActions,
      onLongPress: onOpenActions,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: _listCardDeco(),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _SoWidgetState.primaryColor.withValues(
                alpha: 0.12,
              ),
              child: Text(
                friend.name.substring(0, 1),
                style: const TextStyle(color: _SoWidgetState.primaryColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(friend.status, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Text(
              'OVR ${_formatOvrLabel(friend.ovr)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onOpenActions,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.more_horiz, color: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupDetailDialog extends StatefulWidget {
  const _GroupDetailDialog({required this.group});

  final _GroupInfo group;

  @override
  State<_GroupDetailDialog> createState() => _GroupDetailDialogState();
}

class _GroupDetailDialogState extends State<_GroupDetailDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  final TextEditingController _chatCtrl = TextEditingController();
  final TextEditingController _flowTagFilterCtrl = TextEditingController();
  final TextEditingController _flowUserFilterCtrl = TextEditingController();
  DateTime? _flowDateFrom;
  DateTime? _flowDateTo;
  int? _flowDaysPreset;
  List<String> _flowUserOptions = [];
  List<String> _flowTagSelected = [];
  final ScrollController _chatScroll = ScrollController();

  List<GroupSharedExam> _exams = [];
  List<ExamPaperEntry> _myExamPapers = [];
  String? _selectedExamId;
  List<SharedFlowItem> _flows = [];
  List<StudyGroupMessage> _messages = [];
  List<SolveHistoryItem> _history = [];

  bool _showHistoryPicker = false;
  bool _sharingSelected = false;
  final Set<String> _historyPicks = {};

  bool _loadingExams = false;
  bool _loadingFlows = false;
  bool _loadingHistory = false;
  bool _sharingExam = false;

  bool _chatLoading = false;
  bool _chatSending = false;
  bool _chatHasMore = true;
  String? _chatBefore;
  String? _myUsername;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Widget _buildFlowFilterBar() {
    final activeCount =
        (_flowTagSelected.isNotEmpty ? 1 : 0) +
        (_flowUserFilterCtrl.text.isNotEmpty ? 1 : 0) +
        (_flowDateFrom != null ? 1 : 0);
    return OutlinedButton.icon(
      onPressed: _openFlowFilterSheet,
      style: OutlinedButton.styleFrom(
        foregroundColor: activeCount > 0 ? Colors.white : _green,
        backgroundColor: activeCount > 0 ? _green : null,
        side: BorderSide(color: _green.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      icon: Icon(activeCount > 0 ? Icons.filter_list : Icons.search, size: 16),
      label: Text(activeCount > 0 ? '필터 $activeCount' : '검색'),
    );
  }

  Widget _buildActiveFilterChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final tag in _flowTagSelected)
          _filterChip(
            '#$tag',
            onDelete: () {
              setState(() {
                _flowTagSelected.remove(tag);
                _flowTagFilterCtrl.text = _flowTagSelected
                    .map((e) => '#$e')
                    .join(' ');
              });
              _loadFlows();
            },
          ),
        if (_flowUserFilterCtrl.text.isNotEmpty)
          _filterChip(
            '공유자: ${_flowUserFilterCtrl.text}',
            onDelete: () {
              setState(() => _flowUserFilterCtrl.clear());
              _loadFlows();
            },
          ),
        if (_flowDateFrom != null)
          _filterChip(
            '${_flowDateFrom!.month}/${_flowDateFrom!.day}'
            ' ~ '
            '${(_flowDateTo ?? _flowDateFrom!).month}/${(_flowDateTo ?? _flowDateFrom!).day}',
            onDelete: () {
              setState(() {
                _flowDateFrom = null;
                _flowDateTo = null;
                _flowDaysPreset = null;
              });
              _loadFlows();
            },
          ),
      ],
    );
  }

  Widget _filterChip(String label, {required VoidCallback onDelete}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _green)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 14, color: _green),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCard(SharedFlowItem item) {
    final isMine = _myUsername != null && _myUsername == item.userId;
    final blocks = _parseQuestBlocks(item.questTitle);
    final dateLabel = item.createdAt?.toIso8601String().split('T').first ?? '';
    const titleStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.4,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 (ContentBlocksView로 LaTeX 렌더링)
          blocks.isNotEmpty
              ? ContentBlocksView(
                  blocks: blocks,
                  textStyle: titleStyle,
                  latexStyle: titleStyle,
                )
              : const Text(
                  '공유된 풀이',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
          const SizedBox(height: 6),
          // 태그 chips
          if (item.tags.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: item.tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t.startsWith('#') ? t : '#$t',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _green,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 8),
          // 하단: 공유자 + 날짜 + 버튼
          Row(
            children: [
              Text(
                '${item.userId} · $dateLabel',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _openSharedFlow(item.shareId),
                style: TextButton.styleFrom(
                  foregroundColor: _green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('열람', style: TextStyle(fontSize: 12)),
              ),
              if (isMine) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () async {
                    try {
                      await ApiClient.instance.deleteSharedFlow(item.shareId);
                      setState(
                        () => _flows.removeWhere(
                          (f) => f.shareId == item.shareId,
                        ),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('공유를 취소했습니다.')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('취소 실패: $e')));
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('취소', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatCtrl.dispose();
    _flowTagFilterCtrl.dispose();
    _flowUserFilterCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadExams(),
      _loadFlows(),
      _loadMessages(),
      _loadHistory(),
      ExamPaperStore.load().then((items) {
        if (mounted) setState(() => _myExamPapers = items);
      }),
      AuthStorage.instance.readUsername().then((value) => _myUsername = value),
      _loadMembers(),
    ]);
  }

  Future<void> _loadMembers() async {
    try {
      final members = await ApiClient.instance.listGroupMembers(
        widget.group.id,
      );
      if (!mounted) return;
      setState(
        () => _flowUserOptions = (members.data ?? const [])
            .map((m) => m.userId)
            .toList(),
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadExams() async {
    if (_loadingExams) return;
    setState(() => _loadingExams = true);
    try {
      final items = await ApiClient.instance.listGroupSharedExams(
        widget.group.id,
        limit: 5,
      );
      if (!mounted) return;
      setState(() => _exams = items);
    } catch (_) {
      // Silent failure; the UI will show empty state.
    } finally {
      if (mounted) setState(() => _loadingExams = false);
    }
  }

  Future<void> _loadFlows() async {
    if (_loadingFlows) return;
    setState(() => _loadingFlows = true);
    try {
      final tags = _flowTagSelected.isEmpty ? null : _flowTagSelected;
      final user = _flowUserFilterCtrl.text.trim();
      final from = _flowDateFrom?.toIso8601String();
      final to = _flowDateTo?.toIso8601String();
      final items = await ApiClient.instance.listSharedFlows(
        widget.group.id,
        limit: 30,
        tags: tags,
        userId: user.isEmpty ? null : user,
        from: from,
        to: to,
      );
      if (!mounted) return;
      final users = {
        for (final f in items) f.userId,
        if (_myUsername != null) _myUsername!,
      }.toList();
      setState(() {
        _flows = items;
        _flowUserOptions = users;
      });
    } catch (_) {
      // silent
    } finally {
      if (mounted) setState(() => _loadingFlows = false);
    }
  }

  Future<void> _shareExam() async {
    // 선택한 로컬 시험지 ID만 전송하며, 서버는 본인 소유 여부만 최종 검증한다.
    final examId = _selectedExamId;
    if (examId == null || examId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공유할 시험지를 선택하세요')));
      return;
    }
    setState(() => _sharingExam = true);
    try {
      final shared = await ApiClient.instance.shareGroupExam(
        groupId: widget.group.id,
        examId: examId,
      );
      if (!mounted) return;
      setState(() {
        _exams.insert(0, shared);
        if (_exams.length > 5) _exams.removeLast();
      });
      setState(() => _selectedExamId = null);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('시험지를 공유했어요')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('공유에 실패했어요: $e')));
    } finally {
      if (mounted) setState(() => _sharingExam = false);
    }
  }

  Future<void> _loadHistory() async {
    if (_loadingHistory) return;
    setState(() => _loadingHistory = true);
    try {
      final items = await ApiClient.instance.fetchSolveHistory(
        days: 60,
        limit: 30,
        kind: 'problem',
      );
      if (!mounted) return;
      setState(() => _history = items);
    } catch (_) {
      // silent
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _openHistoryPicker() async {
    setState(() {
      _showHistoryPicker = true;
      _historyPicks.clear();
    });
    if (_history.isEmpty && !_loadingHistory) {
      await _loadHistory();
    }
  }

  Future<void> _shareSelectedHabits() async {
    if (_historyPicks.isEmpty || _sharingSelected) return;
    setState(() => _sharingSelected = true);
    try {
      final statusJson = jsonEncode({
        'status': [],
        'in_panic': [],
        'ai_opinion': '',
        'o_reasons': [],
      });
      for (final item in _history.where(
        (e) => _historyPicks.contains(e.questId ?? '${e.codebaseId}_${e.seed}'),
      )) {
        await ApiClient.instance.shareFlowToGroup(
          groupId: widget.group.id,
          codebaseId: item.codebaseId ?? 0,
          seed: item.seed ?? 0,
          questId: item.questId ?? '',
          questTitle: item.questTitleRaw,
          statusJson: statusJson,
          allFormulas: '',
          answerRiddle: '',
          tags: item.hashTags,
          difficulty: null,
        );
      }
      await _loadFlows();
      if (mounted) {
        setState(() {
          _showHistoryPicker = false;
          _historyPicks.clear();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('풀이를 공유했어요.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('공유 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharingSelected = false);
    }
  }

  Future<void> _loadMessages({bool loadMore = false}) async {
    if (_chatLoading || (!loadMore && !_chatHasMore && _messages.isNotEmpty)) {
      return;
    }
    setState(() => _chatLoading = true);
    try {
      final fetched = await ApiClient.instance.fetchStudyGroupMessages(
        groupId: widget.group.id,
        limit: 30,
        before: loadMore ? _chatBefore : null,
      );
      if (!mounted) return;
      final next = loadMore ? [..._messages, ...fetched] : fetched;
      setState(() {
        _messages = next;
        _chatBefore = fetched.isNotEmpty ? fetched.last.messageId : _chatBefore;
        _chatHasMore = fetched.length >= 30;
      });
      if (!loadMore) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (_chatScroll.hasClients) {
          _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
        }
      }
    } catch (_) {
      // Keep previous messages; user can retry by loading more.
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _chatSending) return;
    setState(() => _chatSending = true);
    try {
      final sent = await ApiClient.instance.sendStudyGroupMessage(
        groupId: widget.group.id,
        text: text,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(sent);
        if (_messages.length > 500) {
          _messages = _messages.sublist(_messages.length - 500);
        }
      });
      _chatCtrl.clear();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (mounted && _chatScroll.hasClients) {
        _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메시지 전송 실패')));
    } finally {
      if (mounted) setState(() => _chatSending = false);
    }
  }

  Widget _problemPanel() {
    if (_showHistoryPicker) {
      return _buildHistoryPanel();
    }

    final hasFilter =
        _flowTagSelected.isNotEmpty ||
        _flowUserFilterCtrl.text.isNotEmpty ||
        _flowDateFrom != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _openHistoryPicker,
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: BorderSide(color: _green.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.upload, size: 16),
              label: const Text('공유'),
            ),
            const SizedBox(width: 8),
            _buildFlowFilterBar(),
            if (hasFilter) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _flowTagSelected.clear();
                    _flowTagFilterCtrl.clear();
                    _flowUserFilterCtrl.clear();
                    _flowDateFrom = null;
                    _flowDateTo = null;
                    _flowDaysPreset = null;
                  });
                  _loadFlows();
                },
                child: const Icon(
                  Icons.cancel_outlined,
                  size: 18,
                  color: Colors.black38,
                ),
              ),
            ],
          ],
        ),
        if (hasFilter) ...[
          const SizedBox(height: 6),
          _buildActiveFilterChips(),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: _loadingFlows
              ? const Center(child: CircularProgressIndicator(color: _green))
              : _flows.isEmpty
              ? _emptyLocal('공유된 풀이가 없어요')
              : ListView.separated(
                  itemCount: _flows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) => _buildFlowCard(_flows[idx]),
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              '내 풀이 내역',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Text(
              '(최대 5개 · ${_historyPicks.length}개 선택)',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Spacer(),
            if (_loadingHistory)
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _green),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loadingHistory
              ? const Center(child: CircularProgressIndicator(color: _green))
              : _history.isEmpty
              ? _emptyLocal('풀이 내역이 없어요')
              : ListView.separated(
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, idx) {
                    final item = _history[idx];
                    final key =
                        item.questId ?? '${item.codebaseId}_${item.seed}';
                    final checked = _historyPicks.contains(key);
                    final blocks = _parseQuestBlocks(item.questTitleRaw);
                    const titleStyle = TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: Colors.black87,
                    );
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (!checked && _historyPicks.length < 5) {
                          _historyPicks.add(key);
                        } else {
                          _historyPicks.remove(key);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: checked
                              ? _green.withValues(alpha: 0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: checked
                                ? _green.withValues(alpha: 0.35)
                                : const Color(0xFFEEEEEE),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: checked,
                                activeColor: _green,
                                checkColor: Colors.white,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (v) => setState(() {
                                  if (v == true && _historyPicks.length < 5) {
                                    _historyPicks.add(key);
                                  } else {
                                    _historyPicks.remove(key);
                                  }
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  blocks.isNotEmpty
                                      ? ContentBlocksView(
                                          blocks: blocks,
                                          textStyle: titleStyle,
                                          latexStyle: titleStyle,
                                        )
                                      : const Text('풀이 내역', style: titleStyle),
                                  if (item.hashTags.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 3,
                                      children: item.hashTags
                                          .take(4)
                                          .map(
                                            (t) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _green.withValues(
                                                  alpha: 0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                t.startsWith('#') ? t : '#$t',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: _green,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() {
                _showHistoryPicker = false;
                _historyPicks.clear();
              }),
              child: const Text('닫기'),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              onPressed: (_sharingSelected || _historyPicks.isEmpty)
                  ? null
                  : _shareSelectedHabits,
              child: _sharingSelected
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('공유 (${_historyPicks.length})'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _examPanel() {
    // 문서고에 저장된 내 시험지만 선택하게 하여 직접 ID 입력과 답안 공유를 차단한다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedExamId,
                decoration: const InputDecoration(labelText: '내 시험지'),
                hint: const Text('내가 푼 시험지 선택'),
                items: _myExamPapers
                    .map(
                      (paper) => DropdownMenuItem(
                        value: paper.examId,
                        child: Text(
                          paper.searchIndex.isNotEmpty
                              ? paper.searchIndex
                              : '${paper.paperType} 시험지',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _sharingExam
                    ? null
                    : (value) => setState(() => _selectedExamId = value),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _sharingExam ? null : _shareExam,
              child: _sharingExam
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('공유'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          '내 시험지는 채점 전에도 공유할 수 있으며, 학생의 답안은 공유되지 않습니다.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loadingExams
              ? const Center(child: CircularProgressIndicator(color: _green))
              : _exams.isEmpty
              ? _emptyLocal('공유된 시험지가 없어요')
              : ListView.separated(
                  itemCount: _exams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final exam = _exams[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _bgGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined, color: _green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exam.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${exam.senderName} · ${_formatSharedDate(exam.createdAt)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _chatPanel() {
    return Column(
      children: [
        Row(
          children: [
            Text(
              '최대 500개 메시지 · 최근 30개부터 표시',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Spacer(),
            TextButton(
              onPressed: _chatHasMore && !_chatLoading
                  ? () => _loadMessages(loadMore: true)
                  : null,
              child: const Text('이전 메시지 더보기'),
            ),
          ],
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _bgGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _messages.isEmpty && _chatLoading
                ? const Center(child: CircularProgressIndicator(color: _green))
                : ListView.builder(
                    controller: _chatScroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe =
                          _myUsername != null &&
                          _myUsername!.isNotEmpty &&
                          msg.userId == _myUsername;
                      return _buildChatBubble(
                        text: msg.text,
                        timeLabel: msg.createdAt,
                        isMe: isMe,
                        messageType: msg.messageType,
                        payload: msg.payload,
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatCtrl,
                minLines: 1,
                maxLines: 3,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: '메시지를 입력하세요',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _chatSending ? null : _sendMessage,
                child: _chatSending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('전송'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChatBubble({
    required String text,
    required String timeLabel,
    required bool isMe,
    required String messageType,
    required Map<String, dynamic>? payload,
  }) {
    if (messageType == 'shared_exam' && payload != null) {
      return _buildSharedExamChatCard(
        payload: payload,
        timeLabel: timeLabel,
        isMe: isMe,
      );
    }
    final bubbleColor = isMe ? _green : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;
    final shareId = _extractShareId(text);
    final displayText = shareId == null
        ? text
        : text
              .replaceFirst(RegExp(r'FLOW_SHARE:.*', caseSensitive: false), '')
              .trim();
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 4,
                  color: Color(0x14000000),
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayText,
                  style: TextStyle(color: textColor, fontSize: 14, height: 1.3),
                ),
                if (shareId != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isMe ? Colors.white : _green,
                      side: BorderSide(color: isMe ? Colors.white : _green),
                    ),
                    onPressed: () => _openSharedFlow(shareId),
                    child: const Text('함께보기'),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              timeLabel,
              style: const TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  String? _extractShareId(String text) {
    final idx = text.indexOf('FLOW_SHARE:');
    if (idx < 0) return null;
    final part = text.substring(idx + 'FLOW_SHARE:'.length).trim();
    if (part.isEmpty) return null;
    return part;
  }

  void _openSharedFlow(String shareId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SharedFlowViewPage(shareId: shareId)),
    );
  }

  Future<void> _pickTags() async {
    final leafTags = _collectLeafTags(
      conceptTagData,
    ).map((t) => t.startsWith('#') ? t.substring(1) : t).toList();
    final selected = Set<String>.from(_flowTagSelected);
    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '태그 선택',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 360,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: leafTags
                          .map(
                            (tag) => FilterChip(
                              label: Text('#$tag'),
                              selected: selected.contains(tag),
                              onSelected: (v) {
                                if (v) {
                                  selected.add(tag);
                                } else {
                                  selected.remove(tag);
                                }
                                // rebuild sheet
                                (ctx as Element).markNeedsBuild();
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('확인'),
                ),
              ],
            ),
          ),
        );
      },
    );
    setState(() {
      _flowTagSelected = selected.toList();
      _flowTagFilterCtrl.text = _flowTagSelected.map((e) => '#$e').join(' ');
    });
  }

  List<String> _collectLeafTags(List<ConceptTag> tags) {
    final results = <String>[];
    for (final tag in tags) {
      if (tag.children.isEmpty) {
        results.add(tag.displayName);
      } else {
        results.addAll(_collectLeafTags(tag.children));
      }
    }
    return results;
  }

  void _openFlowFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
            left: 12,
            right: 12,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '공유 검색/필터',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _flowTagFilterCtrl,
                readOnly: true,
                onTap: _pickTags,
                decoration: InputDecoration(
                  labelText: '태그 선택',
                  hintText: '#태그 선택',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.local_offer_outlined),
                    onPressed: _pickTags,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    _flowUserOptions.contains(_flowUserFilterCtrl.text)
                    ? _flowUserFilterCtrl.text
                    : null,
                items: _flowUserOptions
                    .map(
                      (u) => DropdownMenuItem(
                        value: u,
                        child: Text(u.isEmpty ? '(알 수 없음)' : u),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _flowUserFilterCtrl.text = v ?? ''),
                decoration: const InputDecoration(labelText: '공유자'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final days in const [1, 3, 7, 14, 30])
                    ChoiceChip(
                      label: Text('$days일'),
                      selected: _flowDaysPreset == days,
                      onSelected: (v) {
                        setState(() {
                          _flowDaysPreset = v ? days : null;
                          if (v) {
                            final now = DateTime.now();
                            _flowDateTo = now;
                            _flowDateFrom = now.subtract(Duration(days: days));
                          } else {
                            _flowDateFrom = null;
                            _flowDateTo = null;
                          }
                        });
                      },
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: const Text('기간 선택'),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: ctx,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime.now(),
                        initialDateRange:
                            _flowDateFrom != null && _flowDateTo != null
                            ? DateTimeRange(
                                start: _flowDateFrom!,
                                end: _flowDateTo!,
                              )
                            : null,
                      );
                      if (picked != null) {
                        setState(() {
                          _flowDaysPreset = null;
                          _flowDateFrom = picked.start;
                          _flowDateTo = picked.end;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_flowTagSelected.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: _flowTagSelected
                      .map(
                        (t) => Chip(
                          label: Text('#$t'),
                          onDeleted: () {
                            setState(() {
                              _flowTagSelected.remove(t);
                              _flowTagFilterCtrl.text = _flowTagSelected
                                  .map((e) => '#$e')
                                  .join(' ');
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _loadFlows();
                },
                child: const Text('필터 적용'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Local empty-state helper for group detail tabs.
  Widget _emptyLocal(String message) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final width = (MediaQuery.of(context).size.width * 0.9)
        .clamp(320.0, 820.0)
        .toDouble();
    final height = (MediaQuery.of(context).size.height * 0.82)
        .clamp(520.0, 780.0)
        .toDouble();

    return Container(
      width: width,
      height: height,
      decoration: _cardDeco(radius: 18),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _green.withValues(alpha: 0.12),
                child: Text(
                  group.name.isNotEmpty ? group.name.substring(0, 1) : '?',
                  style: const TextStyle(color: _green),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.description,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.members}/${group.maxMembers}명 · ${group.isPublic ? '공개' : '비공개'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: _green,
            unselectedLabelColor: Colors.black54,
            tabs: const [
              Tab(text: '그룹 문제풀기'),
              Tab(text: '그룹 시험지'),
              Tab(text: '그룹 채팅'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_problemPanel(), _examPanel(), _chatPanel()],
            ),
          ),
        ],
      ),
    );
  }

  /// 공유 시험지는 일반 대화와 구분해 제목·공유자·날짜만 담은 전용 카드로 표시한다.
  Widget _buildSharedExamChatCard({
    required Map<String, dynamic> payload,
    required String timeLabel,
    required bool isMe,
  }) {
    final title = payload['title']?.toString() ?? '시험지';
    final sender = payload['sender_name']?.toString() ?? '알 수 없음';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 270,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F8F3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.assignment_outlined, color: _green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '공유된 시험지',
                    style: TextStyle(fontSize: 11, color: _green),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$sender · ${_formatSharedDate(timeLabel)}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 서버 UTC 문자열을 그룹 화면에서 읽기 쉬운 날짜·시각으로 변환한다.
  String _formatSharedDate(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return raw;
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.createdAt,
  });

  final String id;
  final String text;
  final bool isMe;
  final DateTime createdAt;

  String get timeLabel => _formatTimeLabel(createdAt);
}

class _MessengerDialog extends StatefulWidget {
  const _MessengerDialog({
    required this.info,
    this.onMessageSent,
    this.onDeleteThread,
  });

  final _MessageInfo info;
  final ValueChanged<_ChatMessage>? onMessageSent;
  final VoidCallback? onDeleteThread;

  @override
  State<_MessengerDialog> createState() => _MessengerDialogState();
}

class _MessengerDialogState extends State<_MessengerDialog> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<_ChatMessage> _chatMessages = [];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _loadError;
  String? _beforeMessageId;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    SocialMessageHub.addListener(_handleHubMessage);
    _loadLatest();
  }

  @override
  void dispose() {
    SocialMessageHub.removeListener(_handleHubMessage);
    _scrollController.removeListener(_handleScroll);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _handleScroll() {
    if (_scrollController.positions.isEmpty) return;
    if (_scrollController.position.pixels <= 40 && _hasMore && !_loadingMore) {
      _loadOlder();
    }
  }

  void _handleHubMessage(DirectMessage message) {
    final peer = widget.info.name;
    if (message.from != peer && message.to != peer) return;
    final chat = _fromDirectMessage(message);
    setState(() {
      _chatMessages = [..._chatMessages, chat];
      _capMessages();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  _ChatMessage _fromDirectMessage(DirectMessage message) {
    return _ChatMessage(
      id: message.id,
      text: message.text,
      isMe: message.isMine,
      createdAt: message.createdAt,
    );
  }

  void _capMessages() {
    const cap = 2000;
    if (_chatMessages.length > cap) {
      _chatMessages = _chatMessages.sublist(_chatMessages.length - cap);
      _beforeMessageId = _chatMessages.first.id;
    }
  }

  Future<void> _loadLatest() async {
    setState(() {
      _initialLoading = true;
      _loadError = null;
    });
    try {
      final fetched = await ApiClient.instance.fetchDirectMessages(
        peerUsername: widget.info.name,
        limit: 30,
      );
      fetched.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final mapped = fetched.map(_fromDirectMessage).toList();
      setState(() {
        _chatMessages = mapped;
        _beforeMessageId = mapped.isNotEmpty ? mapped.first.id : null;
        _hasMore = fetched.length >= 30;
        _capMessages();
      });
      if (mapped.isNotEmpty) {
        widget.onMessageSent?.call(mapped.last);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loadError = '채팅을 불러오지 못했어요. (${err.toString()})';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('채팅을 불러오지 못했어요: $err')));
    } finally {
      if (mounted) {
        setState(() => _initialLoading = false);
      }
    }
  }

  Future<void> _loadOlder() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    final beforeId = _beforeMessageId;
    if (beforeId == null || beforeId.isEmpty) {
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
      return;
    }
    final oldMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldPixels = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    try {
      final fetched = await ApiClient.instance.fetchDirectMessages(
        peerUsername: widget.info.name,
        limit: 30,
        beforeMessageId: beforeId,
      );
      if (fetched.isEmpty) {
        setState(() {
          _hasMore = false;
        });
        return;
      }
      fetched.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final mapped = fetched.map(_fromDirectMessage).toList();
      setState(() {
        _chatMessages = [...mapped, ..._chatMessages];
        _beforeMessageId = _chatMessages.first.id;
        _hasMore = fetched.length >= 30;
        _capMessages();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final newMax = _scrollController.position.maxScrollExtent;
        final delta = newMax - oldMax;
        _scrollController.jumpTo(oldPixels + delta);
      });
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('이전 메시지를 불러오지 못했어요: $err')));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      final sent = await ApiClient.instance.sendDirectMessage(
        peerUsername: widget.info.name,
        text: text,
      );
      final message = _fromDirectMessage(sent);
      setState(() {
        _chatMessages = [..._chatMessages, message];
        _capMessages();
      });
      widget.onMessageSent?.call(message);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('쪽지 전송에 실패했습니다.')));
    }
  }

  Future<void> _deleteThread() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      await ApiClient.instance.deleteConversation(widget.info.name);
      if (widget.onDeleteThread != null) {
        widget.onDeleteThread!.call();
      }
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('쪽지함 삭제 실패: $err')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _buildBubble(_ChatMessage message) {
    final isMe = message.isMe;
    final bubbleColor = isMe ? _green : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;
    final shareId = _extractShareId(message.text);
    final displayText = shareId == null
        ? message.text
        : message.text
              .replaceFirst(RegExp(r'FLOW_SHARE:.*', caseSensitive: false), '')
              .trim();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 4,
                  color: Color(0x14000000),
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayText,
                  style: TextStyle(color: textColor, fontSize: 14, height: 1.3),
                ),
                if (shareId != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isMe ? Colors.white : _green,
                      side: BorderSide(color: isMe ? Colors.white : _green),
                    ),
                    onPressed: () => _openSharedFlow(shareId),
                    child: const Text('함께보기'),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              message.timeLabel,
              style: const TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  String? _extractShareId(String text) {
    final idx = text.indexOf('FLOW_SHARE:');
    if (idx < 0) return null;
    final part = text.substring(idx + 'FLOW_SHARE:'.length).trim();
    if (part.isEmpty) return null;
    return part;
  }

  void _openSharedFlow(String shareId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SharedFlowViewPage(shareId: shareId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final targetWidth = (size.width * 0.9) + 500;
    final targetHeight = (size.height * 0.8) + 500;
    final width = targetWidth.clamp(320.0, size.width - 40);
    final height = targetHeight.clamp(420.0, size.height - 40);

    return Container(
      width: width,
      height: height,
      decoration: _cardDeco(radius: 18),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _green.withValues(alpha: 0.12),
                child: Text(
                  widget.info.name.substring(0, 1),
                  style: const TextStyle(color: _green),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.info.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '로컬 저장 없이 서버에 최근 2,000개의 메시지만 보관합니다.',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _deleting ? null : _deleteThread,
                child: Text(
                  '나가기',
                  style: TextStyle(
                    color: _deleting ? Colors.grey : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                color: _green,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _bgGrey,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _initialLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _green),
                    )
                  : _loadError != null
                  ? Center(child: Text(_loadError!))
                  : _chatMessages.isEmpty
                  ? const Center(child: Text('쪽지가 없습니다.'))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _chatMessages.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_loadingMore && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final msg =
                            _chatMessages[index - (_loadingMore ? 1 : 0)];
                        return _buildBubble(msg);
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: '쪽지를 입력하세요',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0x22000000)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _sendMessage,
                  child: const Text('전송'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
