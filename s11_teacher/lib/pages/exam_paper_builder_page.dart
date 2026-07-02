import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';
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
  final _tagCtrl = TextEditingController();

  bool _generating = false;
  String? _examId;
  String? _status;
  Timer? _pollTimer;

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _examId = null;
      _status = null;
    });
    try {
      final ranges = [
        ExamRangeRequest(
          key: 'mixed',
          tags: _tags.isEmpty ? ['common-math-1'] : _tags,
        ),
      ];
      final resp = await ApiClient.instance.createExam(
        ranges: ranges,
        difficultyTier: _difficultyTier,
        questionCount: _questionCount,
        paperType: _paperType,
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
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    return Scaffold(
      endDrawer: const TeacherAppDrawer(currentRoute: '/exam-builder'),
      backgroundColor: kCourseBgGrey,
      appBar: AppBar(
        backgroundColor: kCourseGreen,
        foregroundColor: Colors.white,
        title: const Text('시험지 생성'),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: '메뉴',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard(
              scale,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '시험지 유형',
                    style: TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.bold,
                      color: kCourseGreen,
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'aiflow', label: Text('AIFlow')),
                      ButtonSegment(value: 'csat', label: Text('CSAT')),
                    ],
                    selected: {_paperType},
                    onSelectionChanged: (set) =>
                        setState(() => _paperType = set.first),
                  ),
                ],
              ),
            ),
            _buildCard(
              scale,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '난이도 티어',
                    style: TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.bold,
                      color: kCourseGreen,
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  Slider(
                    value: _difficultyTier.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$_difficultyTier',
                    onChanged: (v) =>
                        setState(() => _difficultyTier = v.round()),
                    activeColor: kCourseLightGreen,
                  ),
                ],
              ),
            ),
            _buildCard(
              scale,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '문제 수',
                    style: TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.bold,
                      color: kCourseGreen,
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  Slider(
                    value: _questionCount.toDouble(),
                    min: 5,
                    max: 50,
                    divisions: 45,
                    label: '$_questionCount',
                    onChanged: (v) =>
                        setState(() => _questionCount = v.round()),
                    activeColor: kCourseLightGreen,
                  ),
                  Text(
                    '$_questionCount문제',
                    style: TextStyle(
                      fontSize: 14 * scale,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            _buildCard(
              scale,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '태그',
                    style: TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.bold,
                      color: kCourseGreen,
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  Wrap(
                    spacing: 8,
                    children: [
                      ..._tags.map(
                        (tag) => Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                          backgroundColor: kCourseLightGreen.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8 * scale),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagCtrl,
                          decoration: InputDecoration(
                            hintText: '태그 입력',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12 * scale),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12 * scale,
                            ),
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              setState(() => _tags.add(value.trim()));
                              _tagCtrl.clear();
                            }
                          },
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (_tagCtrl.text.trim().isNotEmpty) {
                            setState(() => _tags.add(_tagCtrl.text.trim()));
                            _tagCtrl.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_examId != null) ...[
              SizedBox(height: 16 * scale),
              _buildCard(
                scale,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '생성 상태',
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.bold,
                        color: kCourseGreen,
                      ),
                    ),
                    SizedBox(height: 8 * scale),
                    Text(
                      'Exam ID: $_examId',
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      'Status: ${_status ?? "pending"}',
                      style: TextStyle(fontSize: 14 * scale),
                    ),
                    if (_status == 'completed') ...[
                      SizedBox(height: 12 * scale),
                      ElevatedButton.icon(
                        onPressed: _downloadPdf,
                        icon: const Icon(Icons.download),
                        label: const Text('PDF 다운로드'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kCourseLightGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            SizedBox(height: 24 * scale),
            SizedBox(
              width: double.infinity,
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
                    : const Icon(Icons.auto_awesome),
                label: Text(_generating ? '생성 중...' : '시험지 생성'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCourseLightGreen,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14 * scale),
                  textStyle: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12 * scale),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExamPaperEditorPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_note),
                label: const Text('시험지 넣기 (상세 편집)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCourseGreen,
                  side: BorderSide(color: kCourseGreen),
                  padding: EdgeInsets.symmetric(vertical: 14 * scale),
                  textStyle: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(double scale, Widget child) {
    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * scale),
        boxShadow: const [kCourseShadow],
      ),
      child: child,
    );
  }
}
