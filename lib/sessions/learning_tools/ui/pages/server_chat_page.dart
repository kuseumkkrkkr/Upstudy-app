import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

const int _maxInputChars = 250;

class ServerChatPage extends StatefulWidget {
  const ServerChatPage({
    super.key,
    this.initialContext,
    this.initialMode,
    this.ephemeral = false,
    this.standalone = false,
  });

  final Map<String, dynamic>? initialContext;
  final String? initialMode;
  final bool ephemeral;

  /// `/tools`에서는 전체 페이지, 문제 풀이에서는 기존 오버레이 모달로 표시한다.
  final bool standalone;

  /// 필요한 변수는 초기 문제 맥락과 페이지 표시 방식이다.
  /// 작동 원리: 동일한 채팅 상태를 전용 페이지와 문제 풀이 모달에서 공유한다.
  @override
  State<ServerChatPage> createState() => _ServerChatPageState();
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

class _ServerChatPageState extends State<ServerChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];

  bool _sending = false;
  DateTime? _blockedUntil;
  Timer? _blockTimer;

  String? get _questTitle => widget.initialContext?['quest_title']?.toString();

  String? get _flow {
    final answer = widget.initialContext?['answer_riddle']?.toString() ?? '';
    final formulas = widget.initialContext?['all_formulas']?.toString() ?? '';
    return [
      answer,
      formulas,
    ].where((value) => value.trim().isNotEmpty).join('\n');
  }

  /// 필요한 변수는 선택적으로 전달된 문제 제목·풀이 맥락이다.
  /// 작동 원리: 전용 화면은 짧은 첫 인사를, 문제 풀이 모달은 맥락 연결 안내를 첫 메시지로 표시한다.
  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        text: widget.initialContext == null
            ? '안녕하세요. 오늘 공부할 내용이나 막힌 문제를 알려주세요.'
            : '문제 맥락이 연결되었습니다. 막힌 부분을 편하게 물어보세요.',
        isUser: false,
      ),
    );
  }

  /// 필요한 변수는 입력·스크롤 컨트롤러와 차단 해제 타이머다.
  /// 작동 원리: 화면 종료 시 장기 참조를 모두 해제해 메모리 누수를 막는다.
  @override
  void dispose() {
    _blockTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _inputBlocked {
    final until = _blockedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  bool get _canSend => !_sending && !_inputBlocked;

  /// 필요한 변수는 메시지 목록과 스크롤 컨트롤러다.
  /// 작동 원리: 프레임 배치가 끝난 뒤 최신 메시지까지 부드럽게 이동한다.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// 필요한 변수는 사용자 입력·선택적 추천 질문·문제 맥락과 인증 세션이다.
  /// 작동 원리: 입력을 즉시 대화에 추가한 뒤 서버 AI 채팅 API를 한 번 호출하고 응답을 같은 대화에 반영한다.
  Future<void> _send({
    String? overrideText,
    bool includeUserData = false,
  }) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || !_canSend) return;
    if (text.length > _maxInputChars) {
      _showError('입력은 $_maxInputChars자까지만 가능합니다.');
      return;
    }

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(text: text, isUser: true));
      if (overrideText == null) _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await ApiClient.instance.sendServerChatMessage(
        message: text,
        mode: widget.initialMode == 'problem' ? 'problem' : 'chat',
        ephemeral: widget.ephemeral,
        includeUserData: includeUserData,
        questTitle: _questTitle,
        flow: _flow,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(text: response.assistantMessage, isUser: false),
        );
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      _applyRateBlock(error);
      _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// 필요한 변수는 빈 화면 또는 추천 칩이 전달한 질문이다.
  /// 작동 원리: 추천 질문도 일반 입력과 같은 서버 요청 경로로 보낸다.
  void _askFaq(String text) => _send(overrideText: text);

  /// 필요한 변수는 인증된 학생의 학습 기록 접근 동의다.
  /// 작동 원리: 현재 요청에만 `include_user_data`를 켜 맞춤형 학습 상담을 요청한다.
  void _askWithMyData() {
    _send(
      overrideText: '내 학습 현황을 바탕으로 지금 무엇을 먼저 공부하면 좋을지 짧게 상담해줘.',
      includeUserData: true,
    );
  }

  /// 필요한 변수는 서버의 429 응답과 재시도 가능 시간이다.
  /// 작동 원리: 최대 60초의 짧은 제한만 클라이언트 입력 잠금으로 반영하고 자동 해제한다.
  void _applyRateBlock(Object error) {
    if (error is! ApiException || error.statusCode != 429) return;
    final retryAfter =
        error.retryAfterSeconds ??
        (error.message.contains('너무 짧습니다') ? 30 : null);
    if (retryAfter == null || retryAfter <= 0 || retryAfter > 60) return;
    _blockTimer?.cancel();
    setState(() {
      _blockedUntil = DateTime.now().add(Duration(seconds: retryAfter));
    });
    _blockTimer = Timer(Duration(seconds: retryAfter), () {
      if (!mounted) return;
      setState(() => _blockedUntil = null);
    });
  }

  /// 필요한 변수는 API 또는 네트워크 오류다.
  /// 작동 원리: 서버 내부 표현을 숨기고 학생이 바로 대응할 수 있는 짧은 한국어 안내로 바꾼다.
  String _friendlyError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 429) {
        return error.message.isNotEmpty ? error.message : '잠시 후 다시 시도해 주세요.';
      }
      if (error.statusCode == 400) return '입력값을 확인해 주세요.';
      return error.message.isNotEmpty ? error.message : '응답을 가져오지 못했습니다.';
    }
    return '응답을 가져오지 못했습니다. 네트워크 연결을 확인해 주세요.';
  }

  /// 필요한 변수는 사용자에게 표시할 오류 문구다.
  /// 작동 원리: 현재 페이지의 Scaffold에 일시적인 하단 안내를 표시한다.
  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 필요한 변수는 모달을 연 Navigator다.
  /// 작동 원리: 문제 풀이 화면 위에 열린 챗봇 오버레이만 닫는다.
  void _close() => Navigator.of(context).maybePop();

  /// 필요한 변수는 전체 페이지 여부와 현재 화면 크기다.
  /// 작동 원리: `/tools`는 공용 학생 내비게이션을 가진 전체 화면으로, 풀이 중 채팅은 기존 오버레이로 렌더한다.
  @override
  Widget build(BuildContext context) {
    return widget.standalone
        ? _buildStandalone(context)
        : _buildOverlay(context);
  }

  /// 필요한 변수는 공용 학생 내비게이션·페이지 헤더·대화 패널이다.
  /// 작동 원리: 레퍼런스의 제목, 검은 주 행동, 흰 대화 카드 순서를 유지하고 데스크톱만 보조 열을 펼친다.
  Widget _buildStandalone(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final mobile = isStudentDensityMobile(context);
    final showBottomPrompts = screenWidth < 1100;
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (topBarContext) => Ios26TopBar(
                brandColor: Colors.black,
                showLevelIndicator: false,
                onMenu: () => toggleAppDrawer(topBarContext),
                items: studentTopNavItems(
                  topBarContext,
                  active: StudentTopDestination.learning,
                ),
              ),
            ),
            Expanded(
              child: StudentDensityPage(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StudentDensityPageHeader(
                      eyebrow: 'AI LEARNING',
                      title: 'AI 학습 튜터',
                      description: '학습 질문과 풀이 상담을 한 대화에서 이어갑니다.',
                      action: SizedBox(
                        width: mobile ? double.infinity : 170,
                        child: StudentDensityButton(
                          label: '맞춤 학습 상담',
                          primary: true,
                          onPressed: _canSend ? _askWithMyData : null,
                        ),
                      ),
                    ),
                    SizedBox(height: mobile ? 14 : 22),
                    Expanded(
                      child: _buildChatSurface(
                        compact: mobile,
                        showClose: false,
                        allowSidebars: true,
                      ),
                    ),
                    if (showBottomPrompts) ...[
                      const SizedBox(height: 10),
                      _PromptChipStrip(enabled: _canSend, onPrompt: _askFaq),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 모달이 열린 화면 크기와 닫기 콜백이다.
  /// 작동 원리: 기존 문제 풀이 화면을 가린 채 최대 920×820 크기의 반응형 챗봇 패널을 중앙에 띄운다.
  Widget _buildOverlay(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width <= StudentDensityTokens.mobileBreakpoint;
    return Material(
      color: Colors.black.withValues(alpha: 0.36),
      child: SafeArea(
        child: Center(
          child: SizedBox(
            width: math.min(size.width - (compact ? 0 : 32), 920),
            height: math.min(size.height - (compact ? 0 : 32), 820),
            child: _buildChatSurface(
              compact: compact,
              showClose: true,
              allowSidebars: false,
            ),
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 반응형 상태·메시지·추천 질문·학습 상담 콜백이다.
  /// 작동 원리: 넓은 화면은 레퍼런스의 3열 구조, 좁은 화면과 모달은 단일 대화 패널로 조립한다.
  Widget _buildChatSurface({
    required bool compact,
    required bool showClose,
    required bool allowSidebars,
  }) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFFE1E1E3)),
      ),
      elevation: showClose && !compact ? 18 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = allowSidebars && constraints.maxWidth >= 1040;
          final conversation = _ConversationPanel(
            compact: compact,
            messages: _messages,
            sending: _sending,
            blocked: _inputBlocked,
            controller: _controller,
            scrollController: _scrollController,
            onClose: showClose ? _close : null,
            onSend: () => _send(),
          );
          if (!wide) return conversation;
          return Row(
            children: [
              SizedBox(
                width: 248,
                child: _PromptSidebar(enabled: _canSend, onPrompt: _askFaq),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: conversation),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 232,
                child: _StudySupportSidebar(
                  enabled: _canSend,
                  onMyData: _askWithMyData,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.compact,
    required this.messages,
    required this.sending,
    required this.blocked,
    required this.controller,
    required this.scrollController,
    required this.onSend,
    this.onClose,
  });

  final bool compact;
  final List<_ChatMessage> messages;
  final bool sending;
  final bool blocked;
  final TextEditingController controller;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final VoidCallback? onClose;

  /// 필요한 변수는 대화 목록·입력 상태·스크롤과 닫기 콜백이다.
  /// 작동 원리: 레퍼런스의 상대 헤더, 흰 메시지 영역, 고정 입력창을 한 열로 조립한다.
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChatHeader(onClose: onClose),
        const Divider(height: 1, color: Color(0xFFE1E1E3)),
        Expanded(
          child: Stack(
            children: [
              const Positioned.fill(child: _ChatBackground()),
              if (messages.isEmpty)
                const _EmptyChat(enabled: false, onPrompt: _noopPrompt)
              else
                ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 24,
                    24,
                    compact ? 18 : 24,
                    18,
                  ),
                  itemCount: messages.length + (sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (sending && index == messages.length) {
                      return const _ThinkingBubble();
                    }
                    return _MessageBubble(message: messages[index]);
                  },
                ),
            ],
          ),
        ),
        _ChatComposer(
          controller: controller,
          sending: sending,
          blocked: blocked,
          onSend: onSend,
        ),
      ],
    );
  }
}

/// 필요한 변수는 빈 대화 자리표시자의 추천 질문이다.
/// 작동 원리: 비활성 빈 화면에서 호출되지 않는 안전한 콜백을 제공한다.
void _noopPrompt(String _) {}

class _PromptSidebar extends StatelessWidget {
  const _PromptSidebar({required this.enabled, required this.onPrompt});

  final bool enabled;
  final ValueChanged<String> onPrompt;

  /// 필요한 변수는 추천 질문 목록과 전송 가능 상태다.
  /// 작동 원리: 데스크톱 레퍼런스의 왼쪽 대화 목록을 실제로 전송되는 질문 예시 목록으로 치환한다.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '질문 예시',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: _ChatPrompts.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final prompt = _ChatPrompts.items[index];
                return _PromptCard(
                  prompt: prompt,
                  enabled: enabled,
                  primary: index == 0,
                  onTap: () => onPrompt(prompt.question),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StudySupportSidebar extends StatelessWidget {
  const _StudySupportSidebar({required this.enabled, required this.onMyData});

  final bool enabled;
  final VoidCallback onMyData;

  /// 필요한 변수는 맞춤 상담 가능 상태와 실행 콜백이다.
  /// 작동 원리: 데스크톱 레퍼런스의 오른쪽 공유 자료 열을 실제 학습 지원 기능과 안내로 구성한다.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '학습 지원',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          _SupportCard(
            marker: '01',
            title: '맞춤 학습 상담',
            subtitle: '최근 학습 기록으로 상담',
            enabled: enabled,
            onTap: onMyData,
          ),
          const SizedBox(height: 9),
          const _SupportCard(
            marker: '02',
            title: '답변 활용 안내',
            subtitle: '중요한 내용은 다시 확인',
          ),
          const Spacer(),
          const Text(
            '질문은 250자까지 입력할 수 있습니다.',
            style: TextStyle(
              fontSize: 10,
              height: 1.45,
              color: StudentDensityTokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.marker,
    required this.title,
    required this.subtitle,
    this.enabled = false,
    this.onTap,
  });

  final String marker;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  /// 필요한 변수는 지원 기능 문구·아이콘·선택 가능 상태다.
  /// 작동 원리: 레퍼런스의 공유 자료 행처럼 정사각형 아이콘과 두 줄 정보를 한 카드에 배치한다.
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE1E1E3)),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE1E1E3)),
                ),
                child: Text(
                  marker,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: StudentDensityTokens.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: StudentDensityTokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                const Text(
                  '›',
                  style: TextStyle(
                    fontSize: 18,
                    color: StudentDensityTokens.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptChipStrip extends StatelessWidget {
  const _PromptChipStrip({required this.enabled, required this.onPrompt});

  final bool enabled;
  final ValueChanged<String> onPrompt;

  /// 필요한 변수는 추천 질문 목록과 전송 가능 상태다.
  /// 작동 원리: 모바일 레퍼런스의 카드 아래 기능 태그를 가로 스크롤 가능한 실제 질문 버튼으로 제공한다.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _ChatPrompts.items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final prompt = _ChatPrompts.items[index];
          return ActionChip(
            label: Text(prompt.title),
            onPressed: enabled ? () => onPrompt(prompt.question) : null,
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: Color(0xFFE1E1E3)),
            backgroundColor: Colors.white,
            labelStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: StudentDensityTokens.muted,
            ),
          );
        },
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  /// 필요한 변수는 현재 대화 연결 상태다.
  /// 작동 원리: 레퍼런스의 옅은 회색 캡슐로 온라인 상태를 간결하게 표시한다.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E2E5)),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: StudentDensityTokens.muted,
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({this.onClose});

  final VoidCallback? onClose;

  /// 필요한 변수는 선택적 모달 닫기 콜백이다.
  /// 작동 원리: 레퍼런스와 같은 두 줄 대화 상대 정보와 흑백 LIVE 배지를 표시한다.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AIFlow 튜터',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: StudentDensityTokens.ink,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  '온라인 · 학습 질문과 풀이 상담',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: StudentDensityTokens.muted,
                  ),
                ),
              ],
            ),
          ),
          const _LiveBadge(),
          if (onClose != null) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: '닫기',
              onPressed: onClose,
              icon: const Text(
                '×',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.enabled, required this.onPrompt});

  final bool enabled;
  final ValueChanged<String> onPrompt;

  /// 필요한 변수는 추천 질문 목록·전송 가능 상태·현재 대화 영역 크기다.
  /// 작동 원리: 대화가 비어 있을 때만 작은 안내와 추천 질문을 흑백 카드로 표시한다.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 560 ? 18.0 : 42.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 32, horizontal, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 60),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _TutorAvatar(size: 48),
                    const SizedBox(height: 14),
                    const Text(
                      '무엇이 궁금한가요?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.1,
                        color: StudentDensityTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      '추천 질문을 선택하거나 직접 메시지를 입력해 주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: StudentDensityTokens.muted,
                      ),
                    ),
                    const SizedBox(height: 26),
                    LayoutBuilder(
                      builder: (context, promptConstraints) {
                        const gap = 10.0;
                        final twoColumns = promptConstraints.maxWidth >= 520;
                        final itemWidth = twoColumns
                            ? (promptConstraints.maxWidth - gap) / 2
                            : promptConstraints.maxWidth;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final prompt in _ChatPrompts.items)
                              SizedBox(
                                width: itemWidth,
                                child: _PromptCard(
                                  prompt: prompt,
                                  enabled: enabled,
                                  onTap: () => onPrompt(prompt.question),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatBackground extends StatelessWidget {
  const _ChatBackground();

  /// 필요한 변수는 대화 영역의 기본 표면색이다.
  /// 작동 원리: 레퍼런스처럼 장식 없는 흰 바탕을 사용해 말풍선 대비에 집중한다.
  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.white);
  }
}

class _TutorAvatar extends StatelessWidget {
  const _TutorAvatar({required this.size});

  final double size;

  /// 필요한 변수는 표시할 로고 크기다.
  /// 작동 원리: 학생 앱 상단 브랜드와 같은 검은 정사각형 표식으로 빈 대화 안내를 연결한다.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: StudentDensityTokens.dark,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        'A',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ChatPrompt {
  const _ChatPrompt({
    required this.marker,
    required this.title,
    required this.question,
  });

  final String marker;
  final String title;
  final String question;
}

abstract final class _ChatPrompts {
  static const List<_ChatPrompt> items = <_ChatPrompt>[
    _ChatPrompt(marker: '01', title: '오늘의 공부 계획', question: '오늘 뭐부터 공부하면 좋을까?'),
    _ChatPrompt(
      marker: '02',
      title: '개념 쉽게 이해하기',
      question: '어려운 개념을 예시와 함께 쉽게 설명해줘.',
    ),
    _ChatPrompt(
      marker: '03',
      title: '오답 줄이는 방법',
      question: '같은 유형의 오답을 줄이는 방법을 알려줘.',
    ),
    _ChatPrompt(
      marker: '04',
      title: '풀이 힌트 받기',
      question: '정답 말고 풀이를 시작할 수 있는 힌트만 알려줘.',
    ),
  ];
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.prompt,
    required this.enabled,
    required this.onTap,
    this.primary = false,
  });

  final _ChatPrompt prompt;
  final bool enabled;
  final VoidCallback onTap;
  final bool primary;

  /// 필요한 변수는 추천 질문의 아이콘·제목·원문과 활성 상태다.
  /// 작동 원리: 레퍼런스의 흑백 목록 행을 질문 버튼으로 만들고 전송 중에는 중복 요청을 막는다.
  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? StudentDensityTokens.dark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: primary ? StudentDensityTokens.dark : const Color(0xFFE1E1E3),
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary ? Colors.white : const Color(0xFFF6F6F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primary ? Colors.white : const Color(0xFFE1E1E3),
                  ),
                ),
                child: Text(
                  prompt.marker,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: StudentDensityTokens.ink,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompt.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primary
                            ? Colors.white
                            : StudentDensityTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      prompt.question,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: primary
                            ? const Color(0xFFBDBDC4)
                            : StudentDensityTokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '›',
                style: TextStyle(
                  fontSize: 18,
                  color: primary ? Colors.white : StudentDensityTokens.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  /// 필요한 변수는 메시지 본문과 말풍선 글자색이다.
  /// 작동 원리: `$$...$$` 구간만 LaTeX 위젯으로 치환하고 나머지는 원문 줄바꿈을 보존한다.
  List<InlineSpan> _spans(BuildContext context, Color textColor) {
    final spans = <InlineSpan>[];
    var rest = message.text;
    while (rest.contains(r'$$')) {
      final start = rest.indexOf(r'$$');
      if (start > 0) spans.add(TextSpan(text: rest.substring(0, start)));
      final afterStart = rest.substring(start + 2);
      final end = afterStart.indexOf(r'$$');
      if (end < 0) {
        spans.add(TextSpan(text: rest.substring(start)));
        rest = '';
        break;
      }
      final latex = afterStart.substring(0, end).trim();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Math.tex(
              latex,
              textStyle: TextStyle(color: textColor, fontSize: 14),
            ),
          ),
        ),
      );
      rest = afterStart.substring(end + 2);
    }
    if (rest.isNotEmpty) spans.add(TextSpan(text: rest));
    return spans;
  }

  /// 필요한 변수는 발신자와 메시지 본문이다.
  /// 작동 원리: 레퍼런스처럼 학생은 검은 오른쪽, 튜터는 연회색 왼쪽 말풍선으로만 구분한다.
  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? StudentDensityTokens.darkSecondary
        : const Color(0xFFF3F3F5);
    final textColor = isUser ? Colors.white : StudentDensityTokens.ink;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 18),
          ),
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
            children: _spans(context, textColor),
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  /// 필요한 변수는 현재 전송 중 상태다.
  /// 작동 원리: 응답을 기다리는 동안 왼쪽 연회색 말풍선에 세 점 진행 표시를 보여준다.
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: const BoxDecoration(
          color: Color(0xFFF3F3F5),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: const Text(
          '•••',
          style: TextStyle(
            color: StudentDensityTokens.muted,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.sending,
    required this.blocked,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool blocked;
  final VoidCallback onSend;

  /// 필요한 변수는 입력 컨트롤러·전송 상태·입력 차단과 전송 콜백이다.
  /// 작동 원리: 레퍼런스의 테두리 입력창과 검은 전송 버튼을 대화 카드 하단에 고정한다.
  @override
  Widget build(BuildContext context) {
    final inputEnabled = !sending && !blocked;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE1E1E3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: inputEnabled,
              minLines: 1,
              maxLines: 3,
              maxLength: _maxInputChars,
              textInputAction: TextInputAction.send,
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(_maxInputChars),
              ],
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: blocked ? '잠시 후 다시 입력해 주세요' : '메시지 입력',
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: StudentDensityTokens.lineStrong,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: StudentDensityTokens.lineStrong,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: StudentDensityTokens.ink),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            height: 54,
            child: FilledButton(
              onPressed: inputEnabled ? onSend : null,
              style: FilledButton.styleFrom(
                elevation: 0,
                backgroundColor: StudentDensityTokens.darkSecondary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD7D7DC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: EdgeInsets.zero,
              ),
              child: sending
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '전송',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
