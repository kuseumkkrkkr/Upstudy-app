import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    _ReviewAction(icon: Icons.edit_note_outlined, label: '백지복습하기'),
    _ReviewAction(icon: Icons.chat_bubble_outline, label: '대화형 복습'),
  ];

  static final List<_UsageRecord> _records = [
    _UsageRecord(
      title: '수열 - 등차수열 개념 다시보기',
      subtitle: '개념 학습 · 2시간 전',
      activityType: '개념 학습',
      ageHours: 2,
    ),
    _UsageRecord(
      title: '미적분 - 문제 다시풀기 5문항',
      subtitle: '문제 풀이 · 6시간 전',
      activityType: '문제 풀이',
      ageHours: 6,
    ),
    _UsageRecord(
      title: '확률과 통계 - OX퀴즈 10문항',
      subtitle: '퀴즈 · 1일 전',
      activityType: '퀴즈',
      ageHours: 24,
    ),
    _UsageRecord(
      title: '기하 - 플래시카드 복습',
      subtitle: '플래시카드 · 3일 전',
      activityType: '플래시카드',
      ageHours: 72,
    ),
    _UsageRecord(
      title: '로그함수 - 백지복습',
      subtitle: '백지복습 · 5일 전',
      activityType: '백지복습',
      ageHours: 120,
    ),
    _UsageRecord(
      title: '벡터 - 대화형 복습',
      subtitle: '대화형 · 7일 전',
      activityType: '대화형',
      ageHours: 168,
    ),
  ];

  static const _dayOptions = [3, 7, 14, 30];
  static const _hourOptions = [1, 6, 12, 24, 48, 72];
  static const _activityOptions = [
    '문제 풀이',
    '개념 학습',
    '퀴즈',
    '플래시카드',
    '백지복습',
    '대화형',
  ];

  final Set<int> _selectedDays = {7};
  final Set<int> _selectedHours = {};
  final Set<String> _selectedTypes = {};
  final Set<int> _selectedRecords = {};

  List<_UsageRecord> _filteredRecords() {
    return _records.where((record) {
      var timeMatch = true;
      if (_selectedDays.isNotEmpty || _selectedHours.isNotEmpty) {
        timeMatch = false;
        for (final day in _selectedDays) {
          if (record.ageHours <= day * 24) {
            timeMatch = true;
            break;
          }
        }
        if (!timeMatch) {
          for (final hour in _selectedHours) {
            if (record.ageHours <= hour) {
              timeMatch = true;
              break;
            }
          }
        }
      }

      final typeMatch =
          _selectedTypes.isEmpty || _selectedTypes.contains(record.activityType);
      return timeMatch && typeMatch;
    }).toList();
  }

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
                              '약점과 복습',
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

  Widget _buildRecordPanel(double scale) {
    final records = _filteredRecords();
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
            '사용 기록',
            style: GoogleFonts.inter(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8 * scale),
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Text(
                      '조건에 맞는 기록이 없습니다.',
                      style: TextStyle(
                        fontSize: 13 * scale,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8 * scale),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final recordIndex = _records.indexOf(record);
                      final selected = _selectedRecords.contains(recordIndex);
                      return InkWell(
                        borderRadius: BorderRadius.circular(10 * scale),
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedRecords.remove(recordIndex);
                            } else {
                              _selectedRecords.add(recordIndex);
                            }
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 10 * scale,
                            horizontal: 12 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10 * scale),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF1B402B)
                                  : const Color(0xFFE0E0E0),
                              width: selected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged: (_) {
                                  setState(() {
                                    if (selected) {
                                      _selectedRecords.remove(recordIndex);
                                    } else {
                                      _selectedRecords.add(recordIndex);
                                    }
                                  });
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.title,
                                      style: TextStyle(
                                        fontSize: 13 * scale,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4 * scale),
                                    Text(
                                      record.subtitle,
                                      style: TextStyle(
                                        fontSize: 11 * scale,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
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
        ],
      ),
    );
  }

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
              '복습할 범위 선택',
              style: GoogleFonts.inter(
                fontSize: 16 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 10 * scale),
            _buildFilterGroup(
              title: '기간(일)',
              options: _dayOptions
                  .map((day) => _FilterOption<int>(
                        value: day,
                        label: '$day일',
                      ))
                  .toList(),
              isSelected: (value) => _selectedDays.contains(value),
              onToggle: (value) {
                setState(() {
                  if (_selectedDays.contains(value)) {
                    _selectedDays.remove(value);
                  } else {
                    _selectedDays.add(value);
                  }
                });
              },
              scale: scale,
            ),
            SizedBox(height: 12 * scale),
            _buildFilterGroup(
              title: '기간(시간)',
              options: _hourOptions
                  .map((hour) => _FilterOption<int>(
                        value: hour,
                        label: '$hour시간',
                      ))
                  .toList(),
              isSelected: (value) => _selectedHours.contains(value),
              onToggle: (value) {
                setState(() {
                  if (_selectedHours.contains(value)) {
                    _selectedHours.remove(value);
                  } else {
                    _selectedHours.add(value);
                  }
                });
              },
              scale: scale,
            ),
            SizedBox(height: 12 * scale),
            _buildFilterGroup(
              title: '활동 종류',
              options: _activityOptions
                  .map((type) => _FilterOption<String>(
                        value: type,
                        label: type,
                      ))
                  .toList(),
              isSelected: (value) => _selectedTypes.contains(value),
              onToggle: (value) {
                setState(() {
                  if (_selectedTypes.contains(value)) {
                    _selectedTypes.remove(value);
                  } else {
                    _selectedTypes.add(value);
                  }
                });
              },
              scale: scale,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterGroup<T>({
    required String title,
    required List<_FilterOption<T>> options,
    required bool Function(T) isSelected,
    required ValueChanged<T> onToggle,
    required double scale,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6 * scale),
        Column(
          children: options
              .map(
                (option) => Padding(
                  padding: EdgeInsets.only(bottom: 4 * scale),
                  child: CheckboxListTile(
                    value: isSelected(option.value),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      option.label,
                      style: TextStyle(fontSize: 12 * scale),
                    ),
                    onChanged: (_) => onToggle(option.value),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ReviewAction {
  const _ReviewAction({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

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

class _UsageRecord {
  const _UsageRecord({
    required this.title,
    required this.subtitle,
    required this.activityType,
    required this.ageHours,
  });

  final String title;
  final String subtitle;
  final String activityType;
  final int ageHours;
}

class _FilterOption<T> {
  const _FilterOption({required this.value, required this.label});

  final T value;
  final String label;
}
