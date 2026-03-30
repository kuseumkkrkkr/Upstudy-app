import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/services/api_client.dart';

class _ReviewAction {
  const _ReviewAction({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

VoidCallback buildWeaknessReviewAction(BuildContext context) {
  return () {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future.microtask(() => showWeaknessReviewModal(context: navigator.context));
  };
}

Future<T?> showWeaknessReviewModal<T>({required BuildContext context}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            const Center(child: WeaknessReviewModal()),
          ],
        ),
      );
    },
  );
}

class WeaknessReviewModal extends StatefulWidget {
  const WeaknessReviewModal({super.key});

  @override
  State<WeaknessReviewModal> createState() => _WeaknessReviewModalState();
}

class _WeaknessReviewModalState extends State<WeaknessReviewModal> {
  static const _topActions = [
    _ReviewAction(icon: Icons.restart_alt_rounded, label: '문제 다시풀기'),
    _ReviewAction(icon: Icons.menu_book_outlined, label: '개념 다시보기'),
    _ReviewAction(icon: Icons.quiz_outlined, label: 'OX퀴즈 풀기'),
    _ReviewAction(icon: Icons.style_outlined, label: '플래시카드 보기'),
    _ReviewAction(icon: Icons.edit_note_outlined, label: '백지 복습하기'),
    _ReviewAction(icon: Icons.chat_bubble_outline, label: '요약형 복습'),
  ];

  bool _loading = true;
  String? _errorMessage;
  List<WeaknessTag> _weaknessTags = const [];

  static const _dayOptions = [3, 7, 14, 30];
  static const _hourOptions = [1, 6, 12, 24, 48, 72];
  static const _activityOptions = [
    '문제 풀이',
    '개념 학습',
    'OX퀴즈',
    '플래시카드',
    '백지 복습',
    '요약형',
  ];

  final Set<int> _selectedDays = {7};
  final Set<int> _selectedHours = {};
  final Set<String> _selectedTypes = {};

  @override
  void initState() {
    super.initState();
    _loadWeaknessTags();
  }

  // ✅ FIX 1: 누락된 닫는 중괄호 추가 — 메서드가 제대로 닫히지 않아 build()가 메서드 내부로 파싱되던 문제 수정
  Future<void> _loadWeaknessTags() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final tags = await ApiClient.instance.fetchWeaknessTags();
      if (!mounted) return;
      setState(() {
        _weaknessTags = tags;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  } // ← 누락된 닫는 중괄호

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 1200.0;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 820.0;
        const baseWidth = 1200.0;
        const baseHeight = 820.0;
        final width = math.min(baseWidth, maxW * 0.95);
        final height = math.min(baseHeight, maxH * 0.95);
        final scale = (width / baseWidth).clamp(0.6, 1.0);
        final horizontalPadding = 24 * scale;
        final gap = 12 * scale;
        final contentWidth = width - (horizontalPadding * 2);
        final topTileWidth =
            (contentWidth - (gap * (_topActions.length - 1))) /
            _topActions.length;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              top: true,
              child: Center(
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16 * scale),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(20 * scale),
                            child: IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.black,
                                size: 30 * scale,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 2 * scale),
                            child: Text(
                              '약점 복습',
                              style: GoogleFonts.inter(
                                fontSize: 26 * scale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: Row(
                          children: List.generate(_topActions.length, (index) {
                            final action = _topActions[index];
                            final tile = _ReviewActionTile(
                              action: action,
                              scale: scale,
                              width: topTileWidth,
                              height: 96 * scale,
                            );
                            if (index == _topActions.length - 1) {
                              return tile;
                            }
                            return Padding(
                              padding: EdgeInsets.only(right: gap),
                              child: tile,
                            );
                          }),
                        ),
                      ),
                      SizedBox(height: 18 * scale),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: Text(
                          '복습 범위 지정',
                          style: GoogleFonts.inter(
                            fontSize: 18 * scale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 10 * scale),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildRecordPanel(scale),
                              ),
                              SizedBox(width: gap),
                              Expanded(
                                flex: 2,
                                child: _buildFilterPanel(scale),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12 * scale),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ FIX 2: _buildRecordPanel을 클래스 내부 메서드로 올바르게 위치
  Widget _buildRecordPanel(double scale) {
    final tags = _weaknessTags;
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: const Color(0xFFE1E3E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '약점 태그',
            style: GoogleFonts.inter(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8 * scale),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 13 * scale,
                        color: Colors.redAccent,
                      ),
                    ),
                  )
                : tags.isEmpty
                ? Center(
                    child: Text(
                      '약점 태그가 없습니다.',
                      style: TextStyle(
                        fontSize: 13 * scale,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: tags.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8 * scale),
                    itemBuilder: (context, index) {
                      final item = tags[index];
                      return Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 10 * scale,
                          horizontal: 12 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10 * scale),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34 * scale,
                              height: 34 * scale,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1B402B,
                                ).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                item.count.toString(),
                                style: TextStyle(
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1B402B),
                                ),
                              ),
                            ),
                            SizedBox(width: 12 * scale),
                            Expanded(
                              child: Text(
                                item.tag,
                                style: TextStyle(
                                  fontSize: 13 * scale,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ✅ FIX 3: _buildFilterPanel을 클래스 내부로 이동하고, 선언만 된 필터 상태(_selectedDays 등)를 실제 UI에 연결
  Widget _buildFilterPanel(double scale) {
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: const Color(0xFFE1E3E6)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '필터',
              style: GoogleFonts.inter(
                fontSize: 16 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12 * scale),

            // 날짜 필터
            Text(
              '기간 (일)',
              style: TextStyle(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 6 * scale),
            Wrap(
              spacing: 6 * scale,
              runSpacing: 6 * scale,
              children: _dayOptions.map((day) {
                final selected = _selectedDays.contains(day);
                return GestureDetector(
                  onTap: () => setState(() {
                    selected
                        ? _selectedDays.remove(day)
                        : _selectedDays.add(day);
                  }),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * scale,
                      vertical: 6 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1B402B)
                          : const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.circular(8 * scale),
                    ),
                    child: Text(
                      '$day일',
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 12 * scale),

            // 시간 필터
            Text(
              '시간 (시)',
              style: TextStyle(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 6 * scale),
            Wrap(
              spacing: 6 * scale,
              runSpacing: 6 * scale,
              children: _hourOptions.map((hour) {
                final selected = _selectedHours.contains(hour);
                return GestureDetector(
                  onTap: () => setState(() {
                    selected
                        ? _selectedHours.remove(hour)
                        : _selectedHours.add(hour);
                  }),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * scale,
                      vertical: 6 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1B402B)
                          : const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.circular(8 * scale),
                    ),
                    child: Text(
                      '${hour}h',
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 12 * scale),

            // 활동 유형 필터
            Text(
              '활동 유형',
              style: TextStyle(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 6 * scale),
            Wrap(
              spacing: 6 * scale,
              runSpacing: 6 * scale,
              children: _activityOptions.map((type) {
                final selected = _selectedTypes.contains(type);
                return GestureDetector(
                  onTap: () => setState(() {
                    selected
                        ? _selectedTypes.remove(type)
                        : _selectedTypes.add(type);
                  }),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * scale,
                      vertical: 6 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1B402B)
                          : const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.circular(8 * scale),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
} // ← _WeaknessReviewModalState 닫는 중괄호

class _ReviewActionTile extends StatelessWidget {
  const _ReviewActionTile({
    required this.action,
    required this.scale,
    required this.width,
    required this.height,
    this.iconSize,
    this.onTap,
  });

  final _ReviewAction action;
  final double scale;
  final double width;
  final double height;
  final double? iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14 * scale),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(14 * scale),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4,
              color: Color(0x22000000),
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 12 * scale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              action.icon,
              size: iconSize ?? 34 * scale,
              color: const Color(0xFF1B402B),
            ),
            SizedBox(height: 8 * scale),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
