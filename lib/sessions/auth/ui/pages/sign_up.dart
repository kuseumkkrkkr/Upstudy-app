import 'package:s11/shared/services/api/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'sign_up_2.dart';
import 'package:s11/sessions/auth/session/signup_flow.dart';

class BuildpageWidget extends StatefulWidget {
  static const routeName = '/signup';
  const BuildpageWidget({super.key});

  @override
  State<BuildpageWidget> createState() => _BuildpageWidgetState();
}

class _BuildpageWidgetState extends State<BuildpageWidget> {
  static const _schoolSuggestions = <String>[
    '서울예빛중학교',
    '해솔중학교',
    '푸른숲중학교',
    '한강중학교',
    '별빛중학교',
    '도담고등학교',
    '새봄고등학교',
    '청솔고등학교',
    '동해고등학교',
    '미래고등학교',
  ];

  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  TextEditingController? _schoolController;

  String _nameHint = '';
  String _schoolHint =
      '입력은 선택이며 언제든 다시 입력하거나 삭제할 수 있어요 / 목록에 없는 학교는 서비스 대상이 아니에요';

  String? _selectedTrack;
  String? _selectedGrade;
  String? _selectedSubject;

  String _schoolValue = '';
  bool _nameConfirmed = false;
  bool _schoolValidated = false;

  bool _nameValidating = false;
  bool _schoolValidating = false;
  int _nameHintToken = 0;
  int _schoolHintToken = 0;

  bool get _isHighSchool => _selectedTrack == '고등';
  bool get _showTrackSection => _nameConfirmed;
  bool get _showGradeSection => _selectedTrack != null;
  bool get _showSubjectSection => _selectedGrade != null && _isHighSchool;
  bool get _showSchoolSection =>
      _selectedGrade != null && (!_isHighSchool || _selectedSubject != null);

  int get _totalSteps => 9;
  int get _completedSteps {
    var steps = 0;
    if (_nameConfirmed) steps++;
    if (_selectedTrack != null) steps++;
    if (_selectedGrade != null) steps++;
    if (!_isHighSchool && _selectedGrade != null) steps++;
    if (_isHighSchool && _selectedSubject != null) steps++;
    if (_schoolValidated) steps++;
    return steps;
  }

  double get _progressPercent {
    final total = _totalSteps;
    if (total <= 0) return 0;
    final value = _completedSteps / total;
    return value.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  bool _isNameValid(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 20) return false;
    final pattern = RegExp(r'^[가-힣A-Za-z0-9 ]+$');
    return pattern.hasMatch(trimmed);
  }

  bool _isSchoolLocallyValid(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return _schoolSuggestions.contains(trimmed);
  }

  Future<void> _showTemporaryNameHint(String message) async {
    final token = ++_nameHintToken;
    setState(() => _nameHint = message);
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || token != _nameHintToken) return;
    setState(() => _nameHint = '');
  }

  Future<void> _showTemporarySchoolHint(String message) async {
    final token = ++_schoolHintToken;
    setState(() => _schoolHint = message);
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || token != _schoolHintToken) return;
    setState(
      () => _schoolHint =
          '입력은 선택이며 언제든 다시 입력하거나 삭제할 수 있어요 / 목록에 없는 학교는 서비스 대상이 아니에요',
    );
  }

  Future<void> _confirmName() async {
    if (_nameValidating) return;
    final name = _nameController.text.trim();
    if (!_isNameValid(name)) {
      await _showTemporaryNameHint('형식이 다릅니다');
      return;
    }
    setState(() => _nameValidating = true);
    try {
      final result = await AuthService().validateField(
        field: 'name',
        value: name,
      );
      if (!result.valid) {
        await _showTemporaryNameHint(result.reason ?? '형식이 다릅니다');
        return;
      }
      setState(() {
        _nameConfirmed = true;
        _nameHint = '';
      });
      if (!mounted) return;
      FocusScope.of(context).unfocus();
    } catch (_) {
      await _showTemporaryNameHint('확인에 실패했습니다');
      return;
    } finally {
      if (mounted) {
        setState(() => _nameValidating = false);
      }
    }
  }

  void _selectTrack(String track) {
    if (_selectedTrack == track) return;
    setState(() {
      _selectedTrack = track;
      _selectedGrade = null;
      _selectedSubject = null;
      _schoolValidated = false;
      _schoolValue = '';
      _schoolController?.text = '';
    });
  }

  void _selectGrade(String grade) {
    if (_selectedGrade == grade) return;
    setState(() {
      _selectedGrade = grade;
      _selectedSubject = null;
      _schoolValidated = false;
      _schoolValue = '';
      _schoolController?.text = '';
    });
  }

  void _selectSubject(String subject) {
    if (_selectedSubject == subject) return;
    setState(() {
      _selectedSubject = subject;
      _schoolValidated = false;
      _schoolValue = '';
      _schoolController?.text = '';
    });
  }

  Future<void> _completeSchoolStep() async {
    if (_schoolValidating) return;
    final schoolName = _schoolValue.trim();
    if (!_isSchoolLocallyValid(schoolName)) {
      await _showTemporarySchoolHint('서비스 대상 학교가 아닙니다');
      return;
    }
    setState(() => _schoolValidating = true);
    try {
      final result = await AuthService().validateField(
        field: 'school',
        value: schoolName,
      );
      if (!result.valid) {
        await _showTemporarySchoolHint(result.reason ?? '서비스 대상 학교가 아닙니다');
        return;
      }
      setState(() => _schoolValidated = true);
      if (!mounted) return;
      final draft = SignupDraft(
        displayName: _nameController.text.trim(),
        track: _selectedTrack ?? '',
        gradeLabel: _selectedGrade ?? '',
        subject: _selectedSubject,
        schoolName: schoolName,
      );
      final completedSteps = _completedSteps;
      final totalSteps = _totalSteps;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BuildpageCopyWidget(
            draft: draft,
            completedSteps: completedSteps,
            totalSteps: totalSteps,
          ),
        ),
      );
    } catch (_) {
      await _showTemporarySchoolHint('확인에 실패했습니다');
      return;
    } finally {
      if (mounted) {
        setState(() => _schoolValidating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Progress Indicator
                LinearPercentIndicator(
                  percent: _progressPercent,
                  lineHeight: 8,
                  animation: true,
                  animateFromLastPercent: true,
                  progressColor: const Color(0xFF1B402B),
                  backgroundColor: const Color(0xFFE6E6E6),
                  padding: EdgeInsets.zero,
                ),

                const SizedBox(height: 20),

                // Name Input Section
                _buildSectionTitle('제가 당신을 이렇게 부를꺼에요'),
                const SizedBox(height: 20),
                _buildTextField(
                  _nameController,
                  _nameFocusNode,
                  enabled: !_nameConfirmed,
                  onChanged: (value) {
                    if (_nameConfirmed) return;
                    if (_nameHint.isNotEmpty) {
                      setState(() => _nameHint = '');
                    }
                  },
                ),
                if (_nameHint.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _buildHintText(_nameHint),
                ],
                const SizedBox(height: 20),
                _buildSlidingSection(
                  visible: !_nameConfirmed,
                  sectionKey: 'name-action',
                  child: _buildActionButton(
                    '▼ 계속하기',
                    onPressed: _nameValidating ? null : _confirmName,
                  ),
                ),

                _buildSlidingSection(
                  visible: _showTrackSection,
                  sectionKey: 'track',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('과정을 선택해주세요'),
                      const SizedBox(height: 10),
                      _buildSchoolLevelButtons(),
                      const SizedBox(height: 5),
                      _buildHintText(
                        '잘 선택해 주세요  커리큘럼 추천의 바탕이 되요 언제든 다시 입력할 수 있어요',
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                _buildSlidingSection(
                  visible: _showGradeSection,
                  sectionKey: 'grade',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('학년을 선택해주세요'),
                      const SizedBox(height: 10),
                      _buildGradeButtons(),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                _buildSlidingSection(
                  visible: _showSubjectSection,
                  sectionKey: 'subject',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('과목을 선택해주세요'),
                      const SizedBox(height: 10),
                      _buildSubjectButtons(),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                _buildSlidingSection(
                  visible: _showSchoolSection,
                  sectionKey: 'school',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('학교명을 입력해주세요'),
                      const SizedBox(height: 20),
                      _buildSchoolAutocomplete(),
                      const SizedBox(height: 5),
                      _buildHintText(_schoolHint),
                      const SizedBox(height: 20),
                      Center(
                        child: _buildActionButton(
                          _isSchoolLocallyValid(_schoolValue)
                              ? '완료하기'
                              : '▼ 계속하기',
                          onPressed: _schoolValidating
                              ? null
                              : _completeSchoolStep,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 70,
      color: Colors.white,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Color(0xFF3B3B3B),
                size: 50,
              ),
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            ),
          ),
          const Text(
            'AIFlow',
            style: TextStyle(
              color: Color(0xFF1B402B),
              fontSize: 50,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 48),
        child: Text(
          title,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    FocusNode focusNode, {
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        style: const TextStyle(fontSize: 30),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'TextField',
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSchoolLevelButtons() {
    final hasSelection = _selectedTrack != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: [
          Expanded(
            child: _buildRoundedButton(
              '중학',
              dimmed: hasSelection && _selectedTrack != '중학',
              onTap: () => _selectTrack('중학'),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _buildRoundedButton(
              '고등',
              dimmed: hasSelection && _selectedTrack != '고등',
              onTap: () => _selectTrack('고등'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeButtons() {
    final hasSelection = _selectedGrade != null;
    const grades = ['1학년', '2학년', '3학년'];
    final options = _isHighSchool ? [...grades, 'N수이상'] : grades;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            Expanded(
              child: _buildRoundedButton(
                options[i],
                dimmed: hasSelection && _selectedGrade != options[i],
                onTap: () => _selectGrade(options[i]),
              ),
            ),
            if (i < options.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectButtons() {
    final hasSelection = _selectedSubject != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: [
          Expanded(
            child: _buildRoundedButton(
              '확률과 통계',
              dimmed: hasSelection && _selectedSubject != '확률과 통계',
              onTap: () => _selectSubject('확률과 통계'),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _buildRoundedButton(
              '기하와 벡터',
              dimmed: hasSelection && _selectedSubject != '기하와 벡터',
              onTap: () => _selectSubject('기하와 벡터'),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _buildRoundedButton(
              '미분과 적분',
              dimmed: hasSelection && _selectedSubject != '미분과 적분',
              onTap: () => _selectSubject('미분과 적분'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundedButton(
    String text, {
    required bool dimmed,
    VoidCallback? onTap,
  }) {
    final color = dimmed ? const Color(0xFF949494) : const Color(0xFF1B402B);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHintText(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 48),
        child: Text(
          text,
          style: const TextStyle(color: Color(0xFF45BF63), fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, {VoidCallback? onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1B402B),
        foregroundColor: Colors.white,
        minimumSize: const Size(150, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildSlidingSection({
    required bool visible,
    required String sectionKey,
    required Widget child,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation);
        return ClipRect(
          child: SlideTransition(
            position: offset,
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: visible
          ? KeyedSubtree(key: ValueKey(sectionKey), child: child)
          : const SizedBox.shrink(),
    );
  }

  Widget _buildSchoolAutocomplete() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          final query = textEditingValue.text.trim();
          if (query.isEmpty) {
            return const Iterable<String>.empty();
          }
          return _schoolSuggestions.where((option) => option.contains(query));
        },
        onSelected: (selection) {
          setState(() {
            _schoolValue = selection;
            _schoolValidated = false;
          });
        },
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
              _schoolController = textEditingController;
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                style: const TextStyle(fontSize: 30),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'TextField',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _schoolValue = value;
                    _schoolValidated = false;
                    if (_schoolHint !=
                        '입력은 선택이며 언제든 다시 입력하거나 삭제할 수 있어요 / 목록에 없는 학교는 서비스 대상이 아니에요') {
                      _schoolHint =
                          '입력은 선택이며 언제든 다시 입력하거나 삭제할 수 있어요 / 목록에 없는 학교는 서비스 대상이 아니에요';
                    }
                  });
                },
              );
            },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.white,
              elevation: 2,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 220,
                  maxWidth: 520,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      title: Text(option),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
