import 'dart:async';

import 'dart:math';



import 'package:flutter/material.dart';



class FocusModePage extends StatefulWidget {

  const FocusModePage({super.key});



  @override

  State<FocusModePage> createState() => _FocusModePageState();

}



class _FocusModePageState extends State<FocusModePage>

    with SingleTickerProviderStateMixin {

  static const int _maxMinutes = 24 * 60;



  int _selectedMinutes = 60;

  bool _running = false;

  int _remainingSeconds = 0;



  Timer? _ticker;

  late final AnimationController _bgController;



  bool _unlocking = false;

  int _unlockIndex = 0;

  List<Offset> _unlockPositions = const [];



  @override

  void initState() {

    super.initState();

    _bgController = AnimationController(

      vsync: this,

      duration: const Duration(seconds: 8),

    )..repeat(reverse: true);

  }



  @override

  void dispose() {

    _ticker?.cancel();

    _bgController.dispose();

    super.dispose();

  }



  void _startFocus() {
    setState(() {
      _running = true;
      _remainingSeconds = _selectedMinutes * 60;
      _unlocking = false;
      _unlockIndex = 0;
      _unlockPositions = const [];
    });

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds -= 1);
      } else {
        _ticker?.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  void _stopFocus() {
    _ticker?.cancel();
    Navigator.of(context).pop();
  }

  void _startUnlock(Size size) {

    final rng = Random();

    final positions = <Offset>[];

    for (var i = 0; i < 3; i++) {

      final dx = rng.nextDouble() * (size.width - 120) + 60;

      final dy = rng.nextDouble() * (size.height - 200) + 80;

      positions.add(Offset(dx, dy));

    }

    setState(() {

      _unlocking = true;

      _unlockIndex = 0;

      _unlockPositions = positions;

    });

  }



  void _tapUnlock(int index) {

    if (index != _unlockIndex) return;

    if (_unlockIndex == 2) {

      _stopFocus();

      return;

    }

    setState(() => _unlockIndex += 1);

  }



  String _formatTime(int seconds) {

    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');

    final mins = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');

    final secs = (seconds % 60).toString().padLeft(2, '0');

    return '$hours:$mins:$secs';

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _running
          ? null
          : AppBar(
              title: const Text('집중모드'),
              backgroundColor: const Color(0xFF1B402B),
              foregroundColor: Colors.white,
            ),
      body: _running ? _buildFocusRunning() : _buildSetup(),
    );

  }



  Widget _buildSetup() {

    return Center(

      child: Container(

        padding: const EdgeInsets.all(20),

        margin: const EdgeInsets.all(24),

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius: BorderRadius.circular(16),

        ),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            const Text(

            '집중모드 시간 설정',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),

            ),

            const SizedBox(height: 16),

            Text(

            '${_selectedMinutes ~/ 60}시간 ${_selectedMinutes % 60}분',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),

            ),

            const SizedBox(height: 8),

            Slider(

              value: _selectedMinutes.toDouble(),

              min: 30,

              max: _maxMinutes.toDouble(),

              divisions: (_maxMinutes ~/ 30) - 1,

              label: '${_selectedMinutes ~/ 60}h ${_selectedMinutes % 60}m',

              onChanged: (value) {

                setState(() => _selectedMinutes = value.round());

              },

            ),

            const SizedBox(height: 10),

            ElevatedButton(

              onPressed: _startFocus,

              style: ElevatedButton.styleFrom(

                backgroundColor: const Color(0xFF1B402B),

                foregroundColor: Colors.white,

                minimumSize: const Size(180, 46),

              ),

              child: const Text('집중모드 시작'),
            ),

          ],

        ),

      ),

    );

  }



  Widget _buildFocusRunning() {

    return LayoutBuilder(

      builder: (context, constraints) {

        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(

          fit: StackFit.expand,

          children: [

            AnimatedBuilder(

              animation: _bgController,

              builder: (context, _) {

                return CustomPaint(

                  painter: _FocusBackgroundPainter(progress: _bgController.value),

                );

              },

            ),

            Center(

              child: Column(

                mainAxisSize: MainAxisSize.min,

                children: [

                  const Text(

                    '집중모드 실행중',
                    style: TextStyle(

                      fontSize: 26,

                      fontWeight: FontWeight.bold,

                      color: Colors.white,

                    ),

                  ),

                  const SizedBox(height: 12),

                  Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      Text(

                        _formatTime(_remainingSeconds),

                        style: const TextStyle(

                          fontSize: 34,

                          color: Colors.white,

                          fontWeight: FontWeight.w700,

                        ),

                      ),

                      const SizedBox(width: 12),

                      ElevatedButton(

                        onPressed: () => _startUnlock(size),

                        style: ElevatedButton.styleFrom(

                          backgroundColor: Colors.white,

                          foregroundColor: Colors.black87,

                        ),

                        child: const Text('집중모드 풀기'),

                      ),

                    ],

                  ),

                  if (_unlocking)

                    const Padding(

                      padding: EdgeInsets.only(top: 8),

                      child: Text(

                        '랜덤 버튼 3개를 순서대로 누르세요.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),

                      ),

                    ),

                ],

              ),

            ),

            if (_unlocking)

              for (var i = 0; i < _unlockPositions.length; i++)

                Positioned(

                  left: _unlockPositions[i].dx,

                  top: _unlockPositions[i].dy,

                  child: ElevatedButton(

                    onPressed: () => _tapUnlock(i),

                    style: ElevatedButton.styleFrom(

                      backgroundColor:

                          i == _unlockIndex ? Colors.orange : Colors.white70,

                      foregroundColor: Colors.black87,

                      shape: const CircleBorder(),

                      padding: const EdgeInsets.all(14),

                    ),

                    child: Text('${i + 1}'),

                  ),

                ),

          ],

        );

      },

    );

  }

}



class _FocusBackgroundPainter extends CustomPainter {

  _FocusBackgroundPainter({required this.progress});



  final double progress;



  @override

  void paint(Canvas canvas, Size size) {

    final base = Paint()..color = const Color(0xFF0F1C16);

    canvas.drawRect(Offset.zero & size, base);



    final glowPaint = Paint()

      ..shader = RadialGradient(

        colors: [

          const Color(0x3345BF63),

          const Color(0x002B6B4B),

        ],

      ).createShader(Rect.fromCircle(

        center: Offset(size.width * 0.3, size.height * (0.2 + 0.2 * progress)),

        radius: size.width * 0.6,

      ));

    canvas.drawCircle(

      Offset(size.width * 0.3, size.height * (0.2 + 0.2 * progress)),

      size.width * 0.6,

      glowPaint,

    );



    final glowPaint2 = Paint()

      ..shader = RadialGradient(

        colors: [

          const Color(0x2236A2FF),

          const Color(0x00183D2B),

        ],

      ).createShader(Rect.fromCircle(

        center: Offset(size.width * 0.7, size.height * (0.7 - 0.2 * progress)),

        radius: size.width * 0.7,

      ));

    canvas.drawCircle(

      Offset(size.width * 0.7, size.height * (0.7 - 0.2 * progress)),

      size.width * 0.7,

      glowPaint2,

    );

  }



  @override

  bool shouldRepaint(covariant _FocusBackgroundPainter oldDelegate) {

    return oldDelegate.progress != progress;

  }

}

