import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models/subtitle_line.dart';
import '../player/media_player_controller.dart';
import '../services/ffmpeg_export_service.dart';
import '../services/lrc_codec.dart';
import '../services/project_store.dart';
import '../services/srt_codec.dart';
import '../state/marking_session.dart';
import 'marking_scaffold.dart';
import 'stmarker_about_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MediaPlayerController _player;
  late final VideoController _videoController;
  late final FfmpegExportService _ffmpeg;
  static const _mediaExtensions = [
    'mp4',
    'mkv',
    'mov',
    'avi',
    'webm',
    'flv',
    'wmv',
    'm4v',
    'mpeg',
    'mpg',
    'mp3',
    'wav',
    'ogg',
    'm4a',
    'aac',
    'flac',
    'opus',
    'wma',
  ];

  String? _projectPath;

  @override
  void initState() {
    super.initState();
    _player = MediaPlayerController();
    _videoController = VideoController(_player.player);
    _ffmpeg = FfmpegExportService();
  }

  @override
  void dispose() {
    _ffmpeg.cancel();
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final rawLines = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    session.importLines([
      for (var i = 0; i < rawLines.length; i++)
        SubtitleLine(index: i, text: rawLines[i].trim()),
    ]);
  }

  Future<void> _runAction(String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label failed: $error')));
    }
  }

  Future<void> _importSubtitleFile(MarkingSession session) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'lrc'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    final lines = path.toLowerCase().endsWith('.lrc')
        ? LrcCodec.decode(content)
        : SrtCodec.decode(content);
    session.importLines(lines);
  }

  Future<String?> _pickMedia({String? dialogTitle}) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: _mediaExtensions,
    );
    return result?.files.single.path;
  }

  Future<void> _loadMedia(MarkingSession session) async {
    final path = await _pickMedia();
    if (path == null) return;
    await _player.open(path);
    session.setMediaPath(path);
  }

  Future<void> _saveProject(
    MarkingSession session, {
    bool saveAs = false,
  }) async {
    var path = saveAs ? null : _projectPath;
    path ??= await FilePicker.saveFile(
      dialogTitle: saveAs ? 'Save project as' : 'Save project',
      fileName: 'project.stmproj',
    );
    if (path == null) return;
    await ProjectStore.save(session.project, path);
    _projectPath = path;
  }

  Future<String?> _resolveMediaPath(String storedPath) async {
    if (storedPath.isEmpty || await File(storedPath).exists()) {
      return storedPath;
    }
    if (!mounted) return null;

    final relocate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Media file not found'),
        content: Text(
          'The project media could not be found at:\n$storedPath\n\nLocate it now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Locate media'),
          ),
        ],
      ),
    );
    if (relocate != true) return null;
    return _pickMedia(dialogTitle: 'Locate project media');
  }

  Future<void> _openProject(MarkingSession session) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['stmproj'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    var project = await ProjectStore.load(path);
    final mediaPath = await _resolveMediaPath(project.mediaPath);
    if (mediaPath == null) return;
    if (mediaPath != project.mediaPath) {
      project = project.copyWith(mediaPath: mediaPath);
    }

    if (mediaPath.isNotEmpty) await _player.open(mediaPath);
    await _player.setRate(project.playbackRate);
    session.loadProject(project);
    _projectPath = path;
  }

  Future<bool> _confirmExportWarnings(MarkingSession session) async {
    final invalidCount = SrtCodec.invalidLines(session.lines).length;
    final incompleteCount = session.lines
        .where((line) => !line.isFullyMarked)
        .length;
    if (invalidCount > 0 || incompleteCount > 0) {
      final exportAnyway = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Export warnings'),
          content: Text(
            '${invalidCount == 0 ? '' : '$invalidCount line(s) have invalid ranges. '}'
            '${incompleteCount == 0 ? '' : '$incompleteCount incomplete line(s) will be skipped. '}'
            'Export anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Export anyway'),
            ),
          ],
        ),
      );
      return exportAnyway == true;
    }
    return true;
  }

  Future<void> _exportSrt(MarkingSession session) async {
    if (!await _confirmExportWarnings(session)) return;

    final path = await FilePicker.saveFile(
      dialogTitle: 'Export SRT',
      fileName: 'export.srt',
    );
    if (path == null) return;
    await File(path).writeAsString(SrtCodec.encode(session.lines));
  }

  Future<void> _exportVideo(MarkingSession session) async {
    if (session.project.mediaPath.isEmpty) {
      throw const FfmpegExportException('Load a video before exporting.');
    }
    if (!await File(session.project.mediaPath).exists()) {
      throw const FfmpegExportException('The source video could not be found.');
    }
    if (!await _ffmpeg.isAvailable()) {
      throw const FfmpegExportException(
        'FFmpeg is not installed or is not available on PATH.',
      );
    }
    if (!await _confirmExportWarnings(session) || !mounted) return;

    final mode = await showDialog<SubtitleVideoMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Export subtitled video'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, SubtitleVideoMode.embedded),
            child: const ListTile(
              leading: Icon(Icons.subtitles),
              title: Text('Selectable subtitle track'),
              subtitle: Text('Fast, preserves video quality'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, SubtitleVideoMode.burnedIn),
            child: const ListTile(
              leading: Icon(Icons.closed_caption),
              title: Text('Burn subtitles into video'),
              subtitle: Text('Always visible; re-encodes the video'),
            ),
          ),
        ],
      ),
    );
    if (mode == null) return;

    final sourceName = session.project.mediaPath
        .split(Platform.pathSeparator)
        .last;
    final sourceStem = sourceName.contains('.')
        ? sourceName.substring(0, sourceName.lastIndexOf('.'))
        : sourceName;
    final sourceExtension = sourceName.contains('.')
        ? sourceName.substring(sourceName.lastIndexOf('.') + 1).toLowerCase()
        : '';
    final embeddedExtension =
        {'mp4', 'm4v', 'mov', 'mkv'}.contains(sourceExtension)
        ? sourceExtension
        : 'mkv';
    final outputExtension = mode == SubtitleVideoMode.burnedIn
        ? 'mp4'
        : embeddedExtension;
    final outputPath = await FilePicker.saveFile(
      dialogTitle: 'Export subtitled video',
      fileName: '${sourceStem}_subtitled.$outputExtension',
      allowedExtensions: [outputExtension],
      type: FileType.custom,
    );
    if (outputPath == null || !mounted) return;

    final progress = ValueNotifier<double>(0);
    var dialogOpen = true;
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exporting video'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value == 0 ? null : value),
              const SizedBox(height: 12),
              Text(
                value == 0 ? 'Starting FFmpeg…' : '${(value * 100).round()}%',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _ffmpeg.cancel, child: const Text('Cancel')),
        ],
      ),
    ).whenComplete(() => dialogOpen = false);

    try {
      await _ffmpeg.export(
        inputPath: session.project.mediaPath,
        outputPath: outputPath,
        subtitleContent: SrtCodec.encode(session.lines),
        mode: mode,
        durationMs: _player.durationMs,
        onProgress: (value) => progress.value = value,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video exported to $outputPath')),
        );
      }
    } finally {
      if (dialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await dialogFuture;
      progress.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<MarkingSession>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subtitle Marker'),
        actions: [
          IconButton(
            tooltip: 'Paste lines',
            icon: const Icon(Icons.text_snippet),
            onPressed: () =>
                _runAction('Paste lines', () => _pasteLinesDialog(session)),
          ),
          IconButton(
            tooltip: 'Import SRT/LRC',
            icon: const Icon(Icons.subtitles),
            onPressed: () => _runAction(
              'Import subtitles',
              () => _importSubtitleFile(session),
            ),
          ),
          IconButton(
            tooltip: 'Load video/audio',
            icon: const Icon(Icons.folder_open),
            onPressed: () =>
                _runAction('Load media', () => _loadMedia(session)),
          ),
          IconButton(
            tooltip: 'Open project',
            icon: const Icon(Icons.file_open),
            onPressed: () =>
                _runAction('Open project', () => _openProject(session)),
          ),
          IconButton(
            tooltip: 'Save project',
            icon: const Icon(Icons.save),
            onPressed: () =>
                _runAction('Save project', () => _saveProject(session)),
          ),
          IconButton(
            tooltip: 'Save project as',
            icon: const Icon(Icons.save_as),
            onPressed: () => _runAction(
              'Save project as',
              () => _saveProject(session, saveAs: true),
            ),
          ),
          IconButton(
            tooltip: 'Export SRT',
            icon: const Icon(Icons.download),
            onPressed: () =>
                _runAction('Export SRT', () => _exportSrt(session)),
          ),
          IconButton(
            tooltip: 'Export subtitled video',
            icon: const Icon(Icons.movie_creation_outlined),
            onPressed: () =>
                _runAction('Export video', () => _exportVideo(session)),
          ),
          IconButton(
            tooltip: 'About Subtitle Marker',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showStmarkerAboutDialog(context),
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
