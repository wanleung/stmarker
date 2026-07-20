import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'models/project.dart';
import 'state/marking_session.dart';
import 'ui/home_screen.dart';

void main() {
  MediaKit.ensureInitialized();
  runApp(const StmarkerApp());
}

class StmarkerApp extends StatelessWidget {
  const StmarkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MarkingSession(const Project(mediaPath: '', lines: [])),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Subtitle Marker',
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        home: const HomeScreen(),
      ),
    );
  }
}
