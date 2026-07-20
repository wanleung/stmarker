import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models/subtitle_line.dart';
import '../player/media_player_controller.dart';
import '../services/lrc_codec.dart';
import '../services/project_store.dart';
import '../services/srt_codec.dart';
import '../state/marking_session.dart';
import 'marking_scaffold.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MediaPlayerController _player;
  late final VideoController _videoController;

  @override
  void initState() {
    super.initState();
    _player = MediaPlayerController();
    _videoController = VideoController(_player.player);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _pasteLinesDialog(MarkingSession session) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste lines (one per line)'),
        content: TextField(controller: controller, maxLines: 12),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Import')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final rawLines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    session.importLines([
      for (var i = 0; i < rawLines.length; i++) SubtitleLine(index: i, text: rawLines[i].trim()),
    ]);
  }

  Future<void> _importSubtitleFile(MarkingSession session) async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'lrc']);
    final path = result?.files.single.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    final lines = path.toLowerCase().endsWith('.lrc') ? LrcCodec.decode(content) : SrtCodec.decode(content);
    session.importLines(lines);
  }

  Future<void> _loadMedia(MarkingSession session) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4', 'mkv', 'mov', 'avi', 'webm', 'flv', 'wmv', 'm4v', 'mpeg', 'mpg',
        'mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'opus', 'wma',
      ],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    session.setMediaPath(path);
    await _player.open(path);
  }

  Future<void> _saveProject(MarkingSession session) async {
    final path = await FilePicker.saveFile(dialogTitle: 'Save project', fileName: 'project.stmproj');
    if (path == null) return;
    await ProjectStore.save(session.project, path);
  }

  Future<void> _openProject(MarkingSession session) async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['stmproj']);
    final path = result?.files.single.path;
    if (path == null) return;
    final project = await ProjectStore.load(path);
    session.loadProject(project);
    await _player.open(project.mediaPath);
  }

  Future<void> _exportSrt(MarkingSession session) async {
    final path = await FilePicker.saveFile(dialogTitle: 'Export SRT', fileName: 'export.srt');
    if (path == null) return;
    await File(path).writeAsString(SrtCodec.encode(session.lines));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<MarkingSession>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('stmarker'),
        actions: [
          IconButton(
            tooltip: 'Paste lines',
            icon: const Icon(Icons.text_snippet),
            onPressed: () => _pasteLinesDialog(session),
          ),
          IconButton(
            tooltip: 'Import SRT/LRC',
            icon: const Icon(Icons.subtitles),
            onPressed: () => _importSubtitleFile(session),
          ),
          IconButton(
            tooltip: 'Load video/audio',
            icon: const Icon(Icons.folder_open),
            onPressed: () => _loadMedia(session),
          ),
          IconButton(
            tooltip: 'Open project',
            icon: const Icon(Icons.file_open),
            onPressed: () => _openProject(session),
          ),
          IconButton(
            tooltip: 'Save project',
            icon: const Icon(Icons.save),
            onPressed: () => _saveProject(session),
          ),
          IconButton(
            tooltip: 'Export SRT',
            icon: const Icon(Icons.download),
            onPressed: () => _exportSrt(session),
          ),
        ],
      ),
      body: MarkingScaffold(
        controls: _player,
        videoArea: Video(controller: _videoController),
      ),
    );
  }
}
