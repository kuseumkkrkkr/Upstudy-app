import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/concept_tag.dart';
import 'concept_tag_dialog.dart';

class BuildboxWidget extends StatefulWidget {
  final String title;

  const BuildboxWidget({super.key, this.title = '모의고사 생성'});

  @override
  State<BuildboxWidget> createState() => _BuildboxWidgetState();
}

class _BuildboxWidgetState extends State<BuildboxWidget> {
  double _sliderValue = 0;
  final TextEditingController _textController = TextEditingController();
  List<Map<String, dynamic>> _rangeItems = [];

  @override
  void initState() {
    super.initState();
    // 초기 4개 항목 생성
    _rangeItems = List.generate(
      4,
      (index) => {'id': index, 'tags': <ConceptTag>[]},
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: const Color(0xFF777777),
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 2,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 난이도 설정 섹션
                _buildDifficultySection(),

                // 포함할 범위 설정 섹션
                _buildRangeSection(),

                // 문제 수 설정 섹션
                _buildQuestionCountSection(),

                // 다음 버튼
                _buildNextButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultySection() {
    return Column(
      children: [
        const SizedBox(height: 27),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            children: [
              const Text(
                '난이도 설정',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Color(0xFF6D6D6D)),
                iconSize: 30,
                onPressed: () {},
              ),
            ],
          ),
        ),

        Slider(
          value: _sliderValue,
          min: 0,
          max: 100,
          divisions: 4,
          activeColor: Colors.blue,
          inactiveColor: Colors.grey[300],
          onChanged: (value) {
            setState(() => _sliderValue = value);
          },
        ),

        // ⭐ 슬라이더 트랙 기준으로 라벨 배치
        LayoutBuilder(
          builder: (context, constraints) {
            const double sliderEdgePadding = 17; // Slider 내부 여백

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: sliderEdgePadding,
              ),
              child: SizedBox(
                width: constraints.maxWidth - sliderEdgePadding * 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      '하',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '중하',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '중',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '중상',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '상',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 6),

        const Text(
          '왼쪽으로 갈수록 쉬워집니다 난이도는 번호가 증가할수록 지속적으로 올라갑니다 '
          '스크롤은 난이도의 평균을 지정하는 것입니다',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFAEAEAE), fontSize: 20),
        ),
      ],
    );
  }

  Widget _buildRangeSection() {
    return Column(
      children: [
        const SizedBox(height: 27),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            children: [
              const Text(
                '포함할 범위 설정',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Color(0xFF6D6D6D)),
                iconSize: 30,
                onPressed: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        ..._rangeItems
            .map((item) => _buildRangeItem(item['id'], item['tags']))
            .toList(),
      ],
    );
  }

  Widget _buildRangeItem(int id, List<ConceptTag> selectedTags) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              label: 'Delete',
              backgroundColor: Colors.red,
              icon: Icons.delete_outline_rounded,
              onPressed: (_) {
                setState(() {
                  _rangeItems.removeWhere((item) => item['id'] == id);
                });
              },
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => ConceptTagDialog(
                onTagsSelected: (tags) {
                  setState(() {
                    final index = _rangeItems.indexWhere(
                      (item) => item['id'] == id,
                    );
                    if (index != -1) {
                      _rangeItems[index]['tags'] = tags;
                    }
                  });
                },
              ),
            );
          },
          child: Card(
            margin: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '범위 ${_rangeItems.indexOf(_rangeItems.firstWhere((item) => item['id'] == id)) + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 선택된 태그 표시
                  if (selectedTags.isEmpty)
                    const Text(
                      '클릭하여 태그 선택',
                      style: TextStyle(color: Color(0xFFAEAEAE), fontSize: 14),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: selectedTags
                          .map(
                            (tag) => Chip(
                              label: Text(
                                tag.displayName,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.blue[100],
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCountSection() {
    return Column(
      children: [
        const SizedBox(height: 27),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            children: [
              const Text(
                '문제 수 설정',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Color(0xFF6D6D6D)),
                iconSize: 30,
                onPressed: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: TextField(
            controller: _textController,
            decoration: InputDecoration(
              hintText: 'TextField',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF777777),
            minimumSize: const Size(200, 70),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text(
            '다음',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
