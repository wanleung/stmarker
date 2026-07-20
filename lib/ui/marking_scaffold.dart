import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../keyboard/marking_key_handler.dart';
import '../player/playback_controls.dart';
import '../state/marking_session.dart';
import '../models/subtitle_line.dart';
import 'widgets/line_list_view.dart';
import 'widgets/player_controls_bar.dart';

/// The marking screen's layout and keyboard wiring, decoupled from any real
/// media backend so it can be exercised in tests with a fake
/// [PlaybackControls]. [HomeScreen] is the composition root that supplies a
/// real media_kit-backed controller.
class MarkingScaffold extends StatefulWidget {
  const MarkingScaffold({super.key, required this.controls, this.videoArea});

  final PlaybackControls controls;

  /// Optional widget (e.g. a media_kit `Video`) shown above the controls bar.
  final Widget? videoArea;

  @override
  State<MarkingScaffold> createState() => _MarkingScaffoldState();
}

class _MarkingScaffoldState extends State<MarkingScaffold> {
  final _focusNode = FocusNode();
  MarkingKeyHandler? _keyHandler;

  @override
  void initState() {
    super.initState();
    widget.controls.addListener(_syncPlaybackRate);
  }

  void _syncPlaybackRate() {
    final session = context.read<MarkingSession>();
    if (widget.controls.playbackRate != session.project.playbackRate) {
      session.setPlaybackRate(widget.controls.playbackRate);
    }
  }

  @override
  void dispose() {
    widget.controls.removeListener(_syncPlaybackRate);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _editRow(
    BuildContext context,
    MarkingSession session,
    int index,
  ) async {
    final line = session.lines[index];
    if (line.startMs != null) widget.controls.seek(line.startMs!);

    final result = await showDialog<(int?, int?)>(
      context: context,
      builder: (dialogContext) => _EditRowDialog(index: index, line: line),
    );

    if (result != null) {
      session.setLineTimestamps(index, startMs: result.$1, endMs: result.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<MarkingSession>();
    _keyHandler ??= MarkingKeyHandler(
      session: session,
      getPositionMs: () => widget.controls.positionMs,
      seekTo: (ms) => widget.controls.seek(ms),
    );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => (_keyHandler?.handleKeyEvent(event) ?? false)
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      child: Column(
        children: [
          if (widget.videoArea != null)
            SizedBox(height: 240, child: widget.videoArea),
          ExcludeFocus(child: PlayerControlsBar(controls: widget.controls)),
          Expanded(
            child: LineListView(
              onRowTap: (index) => _editRow(context, session, index),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for editing a single line's start/end timestamps directly from the
/// review/edit table. Owns its [TextEditingController]s itself and disposes
/// them exactly when this widget leaves the tree (after the dialog's own
/// exit animation completes) — disposing them eagerly right after
/// [showDialog] resolves would race with that animation, which still
/// renders the [TextField]s for a few more frames.
class _EditRowDialog extends StatefulWidget {
  const _EditRowDialog({required this.index, required this.line});

  final int index;
  final SubtitleLine line;

  @override
  State<_EditRowDialog> createState() => _EditRowDialogState();
}

class _EditRowDialogState extends State<_EditRowDialog> {
  late final _startController = TextEditingController(
    text: widget.line.startMs?.toString() ?? '',
  );
  late final _endController = TextEditingController(
    text: widget.line.endMs?.toString() ?? '',
  );

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit line ${widget.index + 1} timestamps (ms)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('edit-start-field'),
            controller: _startController,
            decoration: const InputDecoration(labelText: 'Start (ms)'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            key: const ValueKey('edit-end-field'),
            controller: _endController,
            decoration: const InputDecoration(labelText: 'End (ms)'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('edit-save-button'),
          onPressed: () => Navigator.pop(context, (
            int.tryParse(_startController.text),
            int.tryParse(_endController.text),
          )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
