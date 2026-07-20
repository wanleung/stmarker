import 'dart:async';

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
  const MarkingScaffold({
    super.key,
    required this.controls,
    this.videoArea,
    this.reviewMode = false,
    this.onReviewFinished,
  });

  final PlaybackControls controls;

  /// Optional widget (e.g. a media_kit `Video`) shown above the controls bar.
  final Widget? videoArea;
  final bool reviewMode;
  final VoidCallback? onReviewFinished;

  @override
  State<MarkingScaffold> createState() => _MarkingScaffoldState();
}

class _MarkingScaffoldState extends State<MarkingScaffold> {
  final _focusNode = FocusNode();
  MarkingKeyHandler? _keyHandler;
  int _reviewIndex = 0;
  final Set<int> _reviewFlagged = {};
  int? _reviewStopAtMs;

  @override
  void initState() {
    super.initState();
    widget.controls.addListener(_handleControlsChanged);
  }

  void _handleControlsChanged() {
    if (!mounted) return;
    final session = context.read<MarkingSession>();
    if (widget.controls.playbackRate != session.project.playbackRate) {
      session.setPlaybackRate(widget.controls.playbackRate);
    }
    final stopAt = _reviewStopAtMs;
    if (widget.reviewMode &&
        stopAt != null &&
        widget.controls.positionMs >= stopAt) {
      _reviewStopAtMs = null;
      unawaited(widget.controls.pause());
    }
  }

  @override
  void didUpdateWidget(covariant MarkingScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controls != widget.controls) {
      oldWidget.controls.removeListener(_handleControlsChanged);
      widget.controls.addListener(_handleControlsChanged);
      _keyHandler = null;
    }
    if (!oldWidget.reviewMode && widget.reviewMode) {
      _reviewIndex = 0;
      _reviewFlagged.clear();
      _reviewStopAtMs = null;
    } else if (oldWidget.reviewMode && !widget.reviewMode) {
      _reviewStopAtMs = null;
      _reviewFlagged.clear();
    }
  }

  @override
  void dispose() {
    widget.controls.removeListener(_handleControlsChanged);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _selectReviewLine(
    MarkingSession session,
    int index, {
    bool play = false,
  }) async {
    if (index < 0 || index >= session.lines.length) return;
    final line = session.lines[index];
    if (!line.isFullyMarked) return;
    setState(() {
      _reviewIndex = index;
      _reviewStopAtMs = null;
    });
    await widget.controls.pause();
    await widget.controls.seek(line.startMs!);
    if (play) {
      _reviewStopAtMs = line.endMs;
      await widget.controls.play();
    }
  }

  int? _safeReviewIndex(MarkingSession session) {
    if (session.lines.isEmpty) return null;
    return _reviewIndex.clamp(0, session.lines.length - 1);
  }

  Set<int> _validReviewFlags(MarkingSession session) => _reviewFlagged
      .where((index) => index >= 0 && index < session.lines.length)
      .toSet();

  void _toggleReviewFlag(MarkingSession session) {
    final reviewIndex = _safeReviewIndex(session);
    if (reviewIndex == null) return;
    setState(() {
      _reviewIndex = reviewIndex;
      if (!_reviewFlagged.add(reviewIndex)) {
        _reviewFlagged.remove(reviewIndex);
      }
    });
  }

  void _finishReview(MarkingSession session) {
    _reviewStopAtMs = null;
    unawaited(widget.controls.pause());
    final reviewIndex = _safeReviewIndex(session);
    session.clearLineTimestamps(
      reviewIndex == null ? const <int>{} : _validReviewFlags(session),
    );
    widget.onReviewFinished?.call();
  }

  Widget _buildReviewBar(MarkingSession session) {
    final count = session.lines.length;
    final reviewIndex = _safeReviewIndex(session);
    final validFlags = _validReviewFlags(session);
    final flagged = reviewIndex != null && validFlags.contains(reviewIndex);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            IconButton(
              key: const ValueKey('review-previous'),
              tooltip: 'Previous line',
              onPressed: reviewIndex != null && reviewIndex > 0
                  ? () => _selectReviewLine(session, reviewIndex - 1)
                  : null,
              icon: const Icon(Icons.skip_previous),
            ),
            Text('Line ${reviewIndex == null ? 0 : reviewIndex + 1} of $count'),
            IconButton(
              key: const ValueKey('review-play'),
              tooltip: 'Play this line',
              onPressed: reviewIndex == null
                  ? null
                  : () => _selectReviewLine(session, reviewIndex, play: true),
              icon: const Icon(Icons.play_arrow),
            ),
            IconButton(
              key: const ValueKey('review-next'),
              tooltip: 'Next line',
              onPressed: reviewIndex != null && reviewIndex + 1 < count
                  ? () => _selectReviewLine(session, reviewIndex + 1)
                  : null,
              icon: const Icon(Icons.skip_next),
            ),
            FilterChip(
              key: const ValueKey('review-flag'),
              selected: flagged,
              onSelected: reviewIndex == null
                  ? null
                  : (_) => _toggleReviewFlag(session),
              avatar: const Icon(Icons.replay, size: 18),
              label: const Text('Needs redo'),
            ),
            FilledButton(
              key: const ValueKey('review-finish'),
              onPressed: () => _finishReview(session),
              child: Text(
                validFlags.isEmpty
                    ? 'Finish review'
                    : 'Redo ${validFlags.length} flagged',
              ),
            ),
          ],
        ),
      ),
    );
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
    final reviewIndex = _safeReviewIndex(session);
    _keyHandler ??= MarkingKeyHandler(
      session: session,
      getPositionMs: () => widget.controls.positionMs,
      seekTo: (ms) => widget.controls.seek(ms),
    );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) =>
          (!widget.reviewMode && (_keyHandler?.handleKeyEvent(event) ?? false))
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      child: Column(
        children: [
          if (widget.videoArea != null)
            SizedBox(height: 240, child: widget.videoArea),
          if (widget.reviewMode && reviewIndex != null)
            _ReviewSubtitlePanel(text: session.lines[reviewIndex].text),
          ExcludeFocus(child: PlayerControlsBar(controls: widget.controls)),
          if (widget.reviewMode) _buildReviewBar(session),
          Expanded(
            child: LineListView(
              selectedIndex: widget.reviewMode ? reviewIndex : null,
              flaggedIndices: widget.reviewMode ? _reviewFlagged : const {},
              onRowTap: widget.reviewMode
                  ? (index) => _selectReviewLine(session, index)
                  : (index) => _editRow(context, session, index),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSubtitlePanel extends StatelessWidget {
  const _ReviewSubtitlePanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('review-subtitle-panel'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: Theme.of(context).colorScheme.inverseSurface,
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onInverseSurface,
        ),
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
