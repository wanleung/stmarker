import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  MediaKit.ensureInitialized();
  runApp(const StmarkerApp());
}

class StmarkerApp extends StatelessWidget {
  const StmarkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'stmarker',
      home: Scaffold(
        appBar: AppBar(title: const Text('stmarker')),
        body: const Center(child: Text('stmarker')),
      ),
    );
  }
}
