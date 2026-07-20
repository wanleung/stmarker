import 'dart:convert';
import 'dart:io';

import '../models/project.dart';

class ProjectStore {
  const ProjectStore._();

  static Future<void> save(Project project, String filePath) async {
    final file = File(filePath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(project.toJson()),
    );
  }

  static Future<Project> load(String filePath) async {
    final content = await File(filePath).readAsString();
    return Project.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }
}
