import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';
import '../shared/theme/app_colors.dart';
import '../shared/ui/ios26/teacher_full_face_panel.dart';
import '../shared/ui/ios26/teacher_studio_shell.dart';
import '../widgets/design_tokens.dart';
import '../widgets/teacher_app_drawer.dart';
import 'exam_paper_editor_page.dart';

class ExamPaperBuilderPage extends StatefulWidget {
  const ExamPaperBuilderPage({super.key});

  @override
  State<ExamPaperBuilderPage> createState() => _ExamPaperBuilderPageState();
}

class _ExamPaperBuilderPageState extends State<ExamPaperBuilderPage> {
  String _paperType = 'aiflow';
  int _difficultyTier = 3;
  int _questionCount = 20;
  final List<String> _tags = [];
  List<_ExamTagGroup> _tagGroups = [];

  bool _generating = false;
  bool _loadingTags = false;
  String? _examId;
  String? _status;
  String? _tagLoadError;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadTagGroups();
  }

  Future<void> _loadTagGroups() async {
    setState(() {
      _loadingTags = true;
      _tagLoadError = null;
    });
    try {
      final groupsRaw = await ApiClient.instance.getQuestGenerationTagGroups();
      final groups = groupsRaw
          .map(_ExamTagGroup.fromJson)
          .where((group) => group.tags.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _tagGroups = groups;
        _tags.removeWhere((tag) => !_allAvailableTags.contains(tag));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _tagLoadError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingTags = false);
    }
  }

  Set<String> get _allAvailableTags =>
      _tagGroups.expand((group) => group.tags).toSet();

  Future<void> _openTagPicker() async {
    if (_tagGroups.isEmpty && !_loadingTags) {
      await _loadTagGroups();
    }
    if (!mounted || _tagGroups.isEmpty) return;
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        fullscreenDialog: true,
        builder: (_) =>
            _ExamTagPickerDialog(groups: _tagGroups, initialTags: _tags),
      ),
    );
    if (picked == null) return;
    setState(() {
      _tags
        ..clear()
        ..addAll(_uniqueTags(picked));
    });
  }

  List<ExamRangeRequest> _buildExamRanges() {
    if (_paperType != 'csat') {
      return [ExamRangeRequest(key: 'range-0', tags: _tags)];
    }

    final selected = _tags.toSet();
    final commonTags = _tagGroups
        .where(
          (group) =>
              group.classification == _ExamTagGroupClassification.csatCommon,
        )
        .expand((group) => group.tags)
        .where(selected.contains)
        .toList();
    final optionalTags = _tagGroups
        .where(
          (group) =>
              group.classification == _ExamTagGroupClassification.csatOptional,
        )
        .expand((group) => group.tags)
        .where(selected.contains)
        .toList();
    final commonFallback = _tagGroups
        .where(
          (group) =>
              group.classification == _ExamTagGroupClassification.csatCommon,
        )
        .expand((group) => group.tags)
        .toList();

    return [
      ExamRangeRequest(
        key: 'common',
        tags: commonTags.isNotEmpty ? commonTags : commonFallback,
      ),
      ExamRangeRequest(key: 'optional', tags: optionalTags),
    ];
  }

  Future<void> _generate() async {
    if (_tags.isEmpty) {
      _showMessage('태그를 1개 이상 선택해 주세요.');
      return;
    }
    if (_paperType == 'csat' &&
        !_tags.any(
          (tag) => _tagGroups
              .where(
                (group) =>
                    group.classification ==
                    _ExamTagGroupClassification.csatOptional,
              )
              .expand((group) => group.tags)
              .contains(tag),
        )) {
      _showMessage('CSAT은 선택 과목 태그를 1개 이상 선택해 주세요.');
      return;
    }
    setState(() {
      _generating = true;
      _examId = null;
      _status = null;
    });
    try {
      final ranges = _buildExamRanges();
      final resp = await ApiClient.instance.createExam(
        ranges: ranges,
        difficultyTier: _difficultyTier,
        questionCount: _questionCount,
        paperType: _paperType,
        saveToDocumentBox: true,
      );
      _examId = resp;
      if (_examId != null) {
        _startPolling();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    } finally {
      setState(() => _generating = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_examId == null) {
        timer.cancel();
        return;
      }
      try {
        final status = await ApiClient.instance.getExamStatus(_examId!);
        setState(() => _status = status.status);
        if (status.status == 'completed' || status.status == 'failed') {
          timer.cancel();
        }
      } catch (_) {
        timer.cancel();
      }
    });
  }

  Future<void> _downloadPdf() async {
    if (_examId == null) return;
    final urlStr = await ApiClient.instance.examPdfUrl(_examId!);
    final uri = Uri.parse(urlStr);
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: try to open in external browser / download manager
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Cannot open URL: $urlStr')));
        }
      }
    } else {
      // Desktop / Web: show URL for manual download
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF URL: $urlStr'),
            action: SnackBarAction(
              label: '열기',
              onPressed: () async {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    return TeacherStudioShell(
      currentRoute: '/exam-builder',
      eyebrow: 'QUICK GENERATOR',
      title: '빠른 시험지',
      description: '유형과 난이도, 태그만 선택해 즉시 시험지를 생성합니다.',
      endDrawer: const TeacherAppDrawer(currentRoute: '/exam-builder'),
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).pop()
          : null,
      actions: [
        TeacherStudioAction(
          label: _generating ? '생성 중' : '시험지 생성',
          icon: Icons.auto_awesome_rounded,
          onTap: _generating ? null : _generate,
          primary: true,
        ),
        TeacherStudioAction(
          label: '태그 선택',
          icon: Icons.sell_outlined,
          onTap: _loadingTags ? null : _openTagPicker,
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;
          final contentWidth = constraints.maxWidth > 1180
              ? 1180.0
              : constraints.maxWidth;
          final horizontalPadding = isWide ? 24.0 : 14.0;

          final settingsPanel = _buildSettingsPanel(scale);
          final tagPanel = _buildTagPanel(scale);

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding * scale,
              18 * scale,
              horizontalPadding * scale,
              24 * scale,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryPanel(scale),
                    SizedBox(height: 12 * scale),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: settingsPanel),
                          SizedBox(width: 12 * scale),
                          Expanded(flex: 5, child: tagPanel),
                        ],
                      )
                    else ...[
                      settingsPanel,
                      SizedBox(height: 12 * scale),
                      tagPanel,
                    ],
                    if (_examId != null) ...[
                      SizedBox(height: 12 * scale),
                      _buildStatusPanel(scale),
                    ],
                    SizedBox(height: 16 * scale),
                    _buildActionArea(scale, isWide: isWide),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryPanel(double scale) {
    return _buildPanel(
      scale,
      title: '현재 설정',
      icon: Icons.fact_check_rounded,
      child: Wrap(
        spacing: 8 * scale,
        runSpacing: 8 * scale,
        children: [
          _buildInfoChip(
            icon: Icons.description_rounded,
            label: _paperType == 'aiflow' ? 'AIFlow' : 'CSAT',
          ),
          _buildInfoChip(
            icon: Icons.bar_chart_rounded,
            label: '난이도 $_difficultyTier',
          ),
          _buildInfoChip(
            icon: Icons.format_list_numbered_rounded,
            label: '$_questionCount문제',
          ),
          _buildInfoChip(
            icon: Icons.sell_rounded,
            label: '태그 ${_tags.length}개',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel(double scale) {
    return _buildPanel(
      scale,
      title: '시험지 설정',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTypeSelector(scale),
          SizedBox(height: 18 * scale),
          _buildSliderControl(
            scale: scale,
            title: '난이도 티어',
            icon: Icons.bar_chart_rounded,
            value: _difficultyTier,
            valueLabel: '$_difficultyTier단계',
            min: 1,
            max: 5,
            divisions: 4,
            startLabel: '1',
            endLabel: '5',
            onChanged: (v) => setState(() => _difficultyTier = v.round()),
          ),
          SizedBox(height: 18 * scale),
          _buildSliderControl(
            scale: scale,
            title: '문제 수',
            icon: Icons.format_list_numbered_rounded,
            value: _questionCount,
            valueLabel: '$_questionCount문제',
            min: 5,
            max: 50,
            divisions: 45,
            startLabel: '5',
            endLabel: '50',
            onChanged: (v) => setState(() => _questionCount = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldHeader(
          icon: Icons.description_rounded,
          title: '시험지 유형',
          value: _paperType == 'aiflow' ? 'AIFlow' : 'CSAT',
        ),
        SizedBox(height: 10 * scale),
        _ExamTypeCapsule(
          value: _paperType,
          onChanged: (value) => setState(() => _paperType = value),
        ),
      ],
    );
  }

  Widget _buildSliderControl({
    required double scale,
    required String title,
    required IconData icon,
    required int value,
    required String valueLabel,
    required double min,
    required double max,
    required int divisions,
    required String startLabel,
    required String endLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldHeader(icon: icon, title: title, value: valueLabel),
        SizedBox(height: 8 * scale),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: kCourseLightGreen,
            inactiveTrackColor: AppColors.surfaceBorder,
            thumbColor: kCourseLightGreen,
            overlayColor: kCourseLightGreen.withValues(alpha: 0.12),
            valueIndicatorColor: kCourseGreen,
            trackHeight: 4,
          ),
          child: Slider(
            value: value.toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: '$value',
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(startLabel, style: _captionStyle),
              Text(endLabel, style: _captionStyle),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagPanel(double scale) {
    return _buildPanel(
      scale,
      title: '태그',
      icon: Icons.sell_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadingTags) ...[
            const LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: AppColors.surfaceMuted,
              color: kCourseLightGreen,
            ),
            SizedBox(height: 12 * scale),
          ],
          if (_tagLoadError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  SizedBox(width: 8 * scale),
                  const Expanded(child: Text('태그 목록을 불러오지 못했습니다.')),
                  TextButton(
                    onPressed: _loadingTags ? null : _loadTagGroups,
                    child: const Text('재시도'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12 * scale),
          ],
          if (_tags.isNotEmpty) ...[
            Wrap(
              spacing: 8 * scale,
              runSpacing: 8 * scale,
              children: [
                for (final tag in _tags)
                  Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                    backgroundColor: AppColors.surfaceMuted,
                    side: const BorderSide(color: AppColors.surfaceBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            SizedBox(height: 12 * scale),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Text(
                '선택된 태그가 없습니다.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            SizedBox(height: 12 * scale),
          ],
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _loadingTags || _tagGroups.isEmpty
                  ? null
                  : _openTagPicker,
              icon: const Icon(Icons.account_tree_rounded),
              label: const Text('해시태그 선택'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kCourseGreen,
                side: const BorderSide(color: AppColors.surfaceBorder),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel(double scale) {
    final status = _status ?? 'pending';
    final completed = status == 'completed';
    final failed = status == 'failed';
    final statusColor = completed
        ? AppColors.success
        : failed
        ? AppColors.error
        : kCourseGreen;

    return _buildPanel(
      scale,
      title: '생성 상태',
      icon: Icons.sync_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8 * scale,
            runSpacing: 8 * scale,
            children: [
              _buildInfoChip(
                icon: Icons.key_rounded,
                label: 'Exam ID: $_examId',
              ),
              _buildInfoChip(
                icon: completed
                    ? Icons.check_circle_rounded
                    : failed
                    ? Icons.error_rounded
                    : Icons.hourglass_top_rounded,
                label: 'Status: $status',
                color: statusColor,
              ),
            ],
          ),
          if (!completed && !failed) ...[
            SizedBox(height: 12 * scale),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: AppColors.surfaceMuted,
                color: kCourseLightGreen,
              ),
            ),
          ],
          if (completed) ...[
            SizedBox(height: 12 * scale),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.download_rounded),
                label: const Text('PDF 다운로드'),
                style: _primaryButtonStyle(scale, compact: true),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionArea(double scale, {required bool isWide}) {
    final primaryButton = SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _generating ? null : _generate,
        icon: _generating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(_generating ? '생성 중...' : '시험지 생성'),
        style: _primaryButtonStyle(scale),
      ),
    );

    final editorButton = SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ExamPaperEditorPage()),
          );
        },
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('시험지 넣기 (상세 편집)'),
        style: _secondaryButtonStyle(scale),
      ),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(flex: 7, child: primaryButton),
          SizedBox(width: 12 * scale),
          Expanded(flex: 5, child: editorButton),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primaryButton,
        SizedBox(height: 10 * scale),
        editorButton,
      ],
    );
  }

  Widget _buildPanel(
    double scale, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: const [kCourseShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: kCourseGreen),
              SizedBox(width: 8 * scale),
              Text(title, style: _sectionTitleStyle),
            ],
          ),
          SizedBox(height: 14 * scale),
          child,
        ],
      ),
    );
  }

  Widget _buildFieldHeader({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kCourseGreen),
        const SizedBox(width: 6),
        Text(title, style: _fieldTitleStyle),
        const Spacer(),
        _buildValueBadge(value),
      ],
    );
  }

  Widget _buildValueBadge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kCourseGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kCourseGreen.withValues(alpha: 0.16)),
      ),
      child: Text(value, style: _valueBadgeStyle),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color color = kCourseGreen,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _primaryButtonStyle(double scale, {bool compact = false}) {
    return ElevatedButton.styleFrom(
      backgroundColor: kCourseGreen,
      foregroundColor: Colors.white,
      disabledBackgroundColor: kCourseGreen.withValues(alpha: 0.48),
      disabledForegroundColor: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: 18 * scale,
        vertical: compact ? 10 : 14,
      ),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      shape: const StadiumBorder(),
      elevation: 0,
    );
  }

  ButtonStyle _secondaryButtonStyle(double scale) {
    return OutlinedButton.styleFrom(
      foregroundColor: kCourseGreen,
      side: const BorderSide(color: AppColors.surfaceBorder),
      padding: EdgeInsets.symmetric(horizontal: 18 * scale, vertical: 14),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      shape: const StadiumBorder(),
    );
  }

  TextStyle get _sectionTitleStyle => const TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: kCourseGreen,
  );

  TextStyle get _fieldTitleStyle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: kCourseGreen,
  );

  TextStyle get _captionStyle => const TextStyle(
    fontSize: 12,
    color: Colors.black45,
    fontWeight: FontWeight.w600,
  );

  TextStyle get _valueBadgeStyle => const TextStyle(
    fontSize: 12,
    color: kCourseGreen,
    fontWeight: FontWeight.w800,
  );
}

List<String> _uniqueTags(Iterable<String> tags) {
  final seen = <String>{};
  final results = <String>[];
  for (final tag in tags) {
    final value = tag.trim();
    if (value.isEmpty || seen.contains(value)) continue;
    seen.add(value);
    results.add(value);
  }
  return results;
}

/// 필요 변수: 현재 시험지 유형과 변경 콜백.
/// 작동 원리: Material SegmentedButton 대신 두 개의 넓은 캡슐 면으로 유형을 전환한다.
class _ExamTypeCapsule extends StatelessWidget {
  const _ExamTypeCapsule({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8D8DC)),
      ),
      child: Row(children: [_item('aiflow', 'AIFlow'), _item('csat', 'CSAT')]),
    );
  }

  Widget _item(String itemValue, String label) {
    final selected = value == itemValue;
    return Expanded(
      child: Material(
        color: selected ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(itemValue),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black54,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ExamTagGroupClassification { csatCommon, csatOptional, foundation }

class _ExamTagGroup {
  const _ExamTagGroup({
    required this.name,
    required this.label,
    required this.tags,
  });

  factory _ExamTagGroup.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString().trim() ?? '';
    final label = json['label']?.toString().trim();
    final tags = (json['tags'] as List<dynamic>? ?? const [])
        .map((item) => item.toString().trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    return _ExamTagGroup(
      name: name,
      label: label == null || label.isEmpty ? name : label,
      tags: _uniqueTags(tags),
    );
  }

  final String name;
  final String label;
  final List<String> tags;

  _ExamTagGroupClassification get classification {
    return switch (name) {
      'common-math-1' ||
      'common-math-2' => _ExamTagGroupClassification.csatCommon,
      'foundation' => _ExamTagGroupClassification.foundation,
      _ => _ExamTagGroupClassification.csatOptional,
    };
  }
}

enum _ExamTagSelectionState { selected, unselected, partial }

class _ExamTagPickerDialog extends StatefulWidget {
  const _ExamTagPickerDialog({required this.groups, required this.initialTags});

  final List<_ExamTagGroup> groups;
  final List<String> initialTags;

  @override
  State<_ExamTagPickerDialog> createState() => _ExamTagPickerDialogState();
}

class _ExamTagPickerDialogState extends State<_ExamTagPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.initialTags.map((tag) => tag.trim()).toSet();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _normalizedQuery => _query.trim().toLowerCase();

  bool _matches(String value) {
    if (_normalizedQuery.isEmpty) return true;
    return value.toLowerCase().contains(_normalizedQuery);
  }

  List<String> _visibleTags(_ExamTagGroup group) {
    if (_matches(group.label) || _matches(group.name)) {
      return group.tags;
    }
    return group.tags.where(_matches).toList();
  }

  _ExamTagSelectionState _selectionState(List<String> tags) {
    if (tags.isEmpty) return _ExamTagSelectionState.unselected;
    final selectedCount = tags.where(_selected.contains).length;
    if (selectedCount == 0) return _ExamTagSelectionState.unselected;
    if (selectedCount == tags.length) return _ExamTagSelectionState.selected;
    return _ExamTagSelectionState.partial;
  }

  bool? _checkboxValue(_ExamTagSelectionState state) {
    return switch (state) {
      _ExamTagSelectionState.selected => true,
      _ExamTagSelectionState.unselected => false,
      _ExamTagSelectionState.partial => null,
    };
  }

  void _toggleGroup(List<String> tags) {
    final state = _selectionState(tags);
    setState(() {
      if (state == _ExamTagSelectionState.selected) {
        _selected.removeAll(tags);
      } else {
        _selected.addAll(tags);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFullFacePanel(
      eyebrow: 'EXAM STUDIO',
      title: '해시태그 선택',
      description: '검색하거나 그룹을 펼쳐 시험 범위에 사용할 태그를 선택하세요.',
      maxContentWidth: 960,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_uniqueTags(_selected.toList())),
          child: Text('${_selected.length}개 선택 완료'),
        ),
      ],
      content: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: '해시태그 검색',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kCourseLightGreen),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_selected.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in _uniqueTags(_selected))
                    Chip(
                      label: Text(tag),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: () => setState(() => _selected.remove(tag)),
                    ),
                ],
              ),
            ),
          if (_selected.isNotEmpty) const SizedBox(height: 12),
          Expanded(
            child: Scrollbar(
              child: ListView(
                children: [
                  for (final group in widget.groups) _buildGroupNode(group),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupNode(_ExamTagGroup group) {
    final tags = _visibleTags(group);
    if (tags.isEmpty) return const SizedBox.shrink();
    final state = _selectionState(tags);

    return ExpansionTile(
      initiallyExpanded: _normalizedQuery.isNotEmpty,
      leading: Checkbox(
        tristate: true,
        value: _checkboxValue(state),
        onChanged: (_) => _toggleGroup(tags),
      ),
      title: Text(
        group.label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${tags.where(_selected.contains).length}/${tags.length}개 선택',
      ),
      children: [
        for (final tag in tags)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: CheckboxListTile(
              dense: true,
              value: _selected.contains(tag),
              title: Text(tag),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(tag);
                  } else {
                    _selected.remove(tag);
                  }
                });
              },
            ),
          ),
      ],
    );
  }
}
