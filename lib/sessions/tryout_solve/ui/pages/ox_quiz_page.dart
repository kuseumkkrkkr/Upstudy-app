import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/theme/app_colors.dart';

class OxQuizPage extends StatefulWidget {
  const OxQuizPage({super.key, required this.questions});

  final List<OxQuizQuestion> questions;

  @override
  State<OxQuizPage> createState() => _OxQuizPageState();
}

class _OxQuizPageState extends State<OxQuizPage> {
  late final List<OxQuizQuestion> _questions;
  int _index = 0;
  int _score = 0;
  String? _feedback;
  Color _feedbackColor = Colors.green;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _questions = List<OxQuizQuestion>.from(widget.questions);
  }

  void _handleAnswer(bool choice) {
    if (_locked || _index >= _questions.length) return;
    final current = _questions[_index];
    final correct = current.answer == choice;
    setState(() {
      _feedback = correct ? '占쏙옙占쏙옙占쌉니댐옙!' : '占쏙옙占쏙옙! 占쌕쏙옙 占쏙옙占쏙옙占쌔븝옙占쏙옙占쏙옙.';
      _feedbackColor = correct ? AppColors.primary : Colors.redAccent;
      _locked = correct; // only lock when moving to next
    });
    if (!correct) return;
    _score++;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_index >= _questions.length - 1) {
        Navigator.of(context).pop(_score);
        return;
      }
      setState(() {
        _index++;
        _feedback = null;
        _locked = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _questions.length;
    final current = _questions[_index];
    final progress = (_index + 1) / total;
    return Scaffold(
      appBar: AppBar(
        title: const Text('O占쏙옙X 占쏙옙占쏙옙'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('占쏙옙占쏙옙  / ',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(width: 12),
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade300,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 4,
                    color: Color(0x12000000),
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          current.tag,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ContentBlocksView(
                    blocks: parseContentBlocks(current.question),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    latexStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    inline: false,
                    spacing: 10,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleAnswer(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            textStyle: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('O'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleAnswer(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: BorderSide(color: Colors.grey.shade400, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            textStyle: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('X'),
                        ),
                      ),
                    ],
                  ),
                  if (_feedback != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _feedback!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _feedbackColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            Text(
              '占쏙옙占쏙옙 占쏙옙占쏙옙:  / ',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF5F6F8),
    );
  }
}