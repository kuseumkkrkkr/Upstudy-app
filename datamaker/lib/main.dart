import 'package:flutter/material.dart';
import 'drawing_page.dart';

void main() {
  runApp(const HandwritingCollectorApp());
}

class HandwritingCollectorApp extends StatelessWidget {
  const HandwritingCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handwriting Collector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const DrawingPage(),
    );
  }
}
