import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../keyboard/marking_key_handler.dart';
import '../karaoke/karaoke_models.dart';
import '../karaoke/karaoke_timing.dart';
import '../subtitle_fonts/subtitle_font_catalog.dart';
import '../player/playback_controls.dart';
import '../state/marking_session.dart';
import '../models/subtitle_line.dart';
import 'review_active_line.dart';
import 'karaoke_preview.dart';
import 'karaoke_settings_dialog.dart';
import 'subtitle_appearance_dialog.dart';
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
  int? _reviewFollowIndex;
  bool _reviewFollowingPlayback = false;
  final Set<int> _reviewFlagged = {};
  int? _reviewStopAtMs;
  int _reviewOperationGeneration = 0;
  int _karaokeOperationGeneration = 0;
  final Map<PlaybackControls, int> _karaokePlaybackOwners = {};
  bool _hadAdvancedPass = false;
  final Map<PlaybackControls, int> _reviewPlaybackOwners = {};
  MarkingSession? _session;
  List<SubtitleLine>? _reviewLines;

  @override
  void initState() {
    super.initState();
    widget.controls.addListener(_handleControlsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.read<MarkingSession>();
    if (identical(session, _session)) return;
    final oldSession = _session;
    oldSession?.removeListener(_handleSessionChanged);
    _invalidateKaraokeOperations();
    _invalidateReviewOperations();
    _hadAdvancedPass = false;
    oldSession?.cancelAdvancedMarking();
    _session = session;
    _keyHandler = null;
    _reviewLines = session.lines;
    session.addListener(_handleSessionChanged);
    if (oldSession != null) unawaited(widget.controls.pause());
  }

  void _handleSessionChanged() {
    final session = _session;
    if (session == null) return;
    if (session.advancedMarking == null && _hadAdvancedPass) {
      _hadAdvancedPass = false;
      _invalidateKaraokeOperations();
      unawaited(widget.controls.pause());
    }
    if (identical(_reviewLines, session.lines)) return;
    _reviewLines = session.lines;
    _invalidateReviewOperations();
    _resetExactReviewPlayback();
    _reviewFollowingPlayback = false;
    _reviewFollowIndex = null;
    _reviewFlagged.clear();
    if (mounted && widget.reviewMode) setState(() {});
  }

  void _invalidateReviewOperations() {
    _reviewOperationGeneration++;
  }

  void _invalidateKaraokeOperations() => _karaokeOperationGeneration++;

  void _resetExactReviewPlayback({
    PlaybackControls? controls,
    bool preservePendingOwner = true,
  }) {
    _reviewStopAtMs = null;
    final target = controls ?? widget.controls;
    if (!preservePendingOwner || target.isPlaying) {
      _reviewPlaybackOwners.remove(target);
    }
  }

  void _handleControlsChanged() {
    if (!mounted) return;
    final session = _session;
    if (session == null) return;
    if (widget.controls.playbackRate != session.project.playbackRate) {
      session.setPlaybackRate(widget.controls.playbackRate);
    }
    final stopAt = _reviewStopAtMs;
    if (widget.reviewMode &&
        stopAt != null &&
        widget.controls.positionMs >= stopAt) {
      _resetExactReviewPlayback(preservePendingOwner: false);
      unawaited(widget.controls.pause());
    }
    final followingContinuousPlayback =
        widget.reviewMode &&
        widget.controls.isPlaying &&
        stopAt == null &&
        !_reviewPlaybackOwners.containsKey(widget.controls);
    if (followingContinuousPlayback) {
      final activeIndex = findActiveReviewLine(
        session.lines,
        widget.controls.positionMs,
      );
      if (!_reviewFollowingPlayback || activeIndex != _reviewFollowIndex) {
        setState(() {
          _reviewFollowingPlayback = true;
          _reviewFollowIndex = activeIndex;
          if (activeIndex != null) _reviewIndex = activeIndex;
        });
      }
    } else if (_reviewFollowingPlayback) {
      setState(() {
        _reviewFollowingPlayback = false;
        _reviewFollowIndex = null;
      });
    }
  }

  @override
  void didUpdateWidget(covariant MarkingScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controls != widget.controls) {
      _invalidateKaraokeOperations();
      _session?.cancelAdvancedMarking();
      _invalidateReviewOperations();
      _resetExactReviewPlayback(controls: oldWidget.controls);
      unawaited(oldWidget.controls.pause());
      oldWidget.controls.removeListener(_handleControlsChanged);
      widget.controls.addListener(_handleControlsChanged);
      _keyHandler = null;
      _reviewFollowingPlayback = false;
      _reviewFollowIndex = null;
    }
    if (!oldWidget.reviewMode && widget.reviewMode) {
      _invalidateReviewOperations();
      _reviewIndex = 0;
      _reviewFlagged.clear();
      _resetExactReviewPlayback();
      _reviewFollowingPlayback = false;
      _reviewFollowIndex = null;
      _reviewLines = _session?.lines;
    } else if (oldWidget.reviewMode && !widget.reviewMode) {
      _cancelAdvancedPass();
      _invalidateReviewOperations();
      _resetExactReviewPlayback();
      _reviewFollowingPlayback = false;
      _reviewFollowIndex = null;
      _reviewFlagged.clear();
      unawaited(widget.controls.pause());
    }
  }

  @override
  void dispose() {
    final session = _session;
    session?.removeListener(_handleSessionChanged);
    widget.controls.removeListener(_handleControlsChanged);
    _invalidateKaraokeOperations();
    _hadAdvancedPass = false;
    session?.cancelAdvancedMarking();
    _invalidateReviewOperations();
    _resetExactReviewPlayback();
    _reviewFollowingPlayback = false;
    _reviewFollowIndex = null;
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _selectReviewLine(
    MarkingSession session,
    int index, {
    bool play = false,
  }) async {
    final advanced = session.advancedMarking;
    if (advanced != null && advanced.lineIndex != index) {
      _cancelAdvancedPass();
    }
    final operation = ++_reviewOperationGeneration;
    final controls = widget.controls;
    _resetExactReviewPlayback(controls: controls);
    final lines = session.lines;
    if (index < 0 || index >= session.lines.length) return;
    final line = session.lines[index];
    if (!line.isFullyMarked) return;
    setState(() {
      _reviewIndex = index;
    });
    await controls.pause();
    if (!_isCurrentReviewOperation(operation, controls, session, lines)) return;
    await controls.seek(line.startMs!);
    if (!_isCurrentReviewOperation(operation, controls, session, lines)) return;
    if (play) {
      _reviewStopAtMs = line.endMs;
      _reviewPlaybackOwners[controls] = operation;
      await controls.play();
      if (_isCurrentReviewOperation(operation, controls, session, lines)) {
        if (_reviewPlaybackOwners[controls] == operation) {
          _reviewPlaybackOwners.remove(controls);
        }
      } else if (_reviewPlaybackOwners[controls] == operation) {
        _reviewPlaybackOwners.remove(controls);
        await controls.pause();
      }
    }
  }

  bool _isCurrentReviewOperation(
    int operation,
    PlaybackControls controls,
    MarkingSession session,
    List<SubtitleLine> lines,
  ) =>
      mounted &&
      widget.reviewMode &&
      operation == _reviewOperationGeneration &&
      identical(widget.controls, controls) &&
      identical(_session, session) &&
      identical(session.lines, lines);

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
    _invalidateReviewOperations();
    _resetExactReviewPlayback();
    _reviewFollowingPlayback = false;
    _reviewFollowIndex = null;
    unawaited(widget.controls.pause());
    final reviewIndex = _safeReviewIndex(session);
    session.clearLineTimestamps(
      reviewIndex == null ? const <int>{} : _validReviewFlags(session),
    );
    _reviewFlagged.clear();
    widget.onReviewFinished?.call();
  }

  Future<void> _editSubtitleAppearance(MarkingSession session) async {
    final reviewIndex = _safeReviewIndex(session);
    final result = await showSubtitleAppearanceDialog(
      context,
      initial: SubtitleAppearance(
        fontFamily: session.project.subtitleFontFamily,
        fontSize: session.project.subtitleFontSize,
      ),
      previewText: reviewIndex == null
          ? 'Subtitle preview 字幕 미리보기'
          : session.lines[reviewIndex].text,
    );
    if (result == null || !mounted) return;
    session.setSubtitleAppearance(
      fontFamily: result.fontFamily,
      fontSize: result.fontSize,
    );
  }

  Future<void> _editKaraokeSettings(MarkingSession session) async {
    final result = await showKaraokeSettingsDialog(
      context,
      initial: KaraokeSettings(
        mode: session.project.karaokeMode,
        preDisplay: session.project.karaokePreDisplay,
      ),
    );
    if (result == null || !mounted) return;
    _invalidateKaraokeOperations();
    session.setKaraokeSettings(
      mode: result.mode,
      preDisplay: result.preDisplay,
    );
  }

  bool _isCurrentKaraokeOperation(
    int operation,
    PlaybackControls controls,
    MarkingSession session,
  ) =>
      mounted &&
      widget.reviewMode &&
      operation == _karaokeOperationGeneration &&
      identical(widget.controls, controls) &&
      identical(_session, session) &&
      session.advancedMarking != null;

  Future<void> _startAdvancedPass(MarkingSession session, int lineIndex) async {
    _invalidateReviewOperations();
    final target = session.beginAdvancedMarking(lineIndex);
    if (target == null) return;
    _hadAdvancedPass = true;
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && session.advancedMarking != null) _focusNode.requestFocus();
    });
    await _playAdvancedPassFrom(session, target);
    if (mounted && session.advancedMarking != null) _focusNode.requestFocus();
  }

  Future<void> _playAdvancedPassFrom(MarkingSession session, int target) async {
    final operation = ++_karaokeOperationGeneration;
    final controls = widget.controls;
    await controls.pause();
    if (!_isCurrentKaraokeOperation(operation, controls, session)) return;
    await controls.seek(target);
    if (!_isCurrentKaraokeOperation(operation, controls, session)) return;
    _karaokePlaybackOwners[controls] = operation;
    await controls.play();
    if (_isCurrentKaraokeOperation(operation, controls, session)) {
      if (_karaokePlaybackOwners[controls] == operation) {
        _karaokePlaybackOwners.remove(controls);
      }
    } else if (_karaokePlaybackOwners[controls] == operation) {
      _karaokePlaybackOwners.remove(controls);
      await controls.pause();
    }
  }

  void _restartAdvancedPass(MarkingSession session) {
    _invalidateKaraokeOperations();
    final target = session.restartAdvancedMarking();
    _focusNode.requestFocus();
    if (target != null) unawaited(_playAdvancedPassFrom(session, target));
  }

  void _cancelAdvancedPass() {
    _invalidateKaraokeOperations();
    _hadAdvancedPass = false;
    _session?.cancelAdvancedMarking();
    unawaited(widget.controls.pause());
  }

  bool _handleMarkingKey(KeyEvent event) {
    final wasComplete = _session?.advancedMarking?.isComplete ?? false;
    final handled = _keyHandler?.handleKeyEvent(event) ?? false;
    final isComplete = _session?.advancedMarking?.isComplete ?? false;
    if (handled && !wasComplete && isComplete) {
      _invalidateKaraokeOperations();
      unawaited(widget.controls.pause());
    }
    return handled;
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
            IconButton(
              key: const ValueKey('review-appearance'),
              tooltip: 'Subtitle appearance',
              onPressed: () => _editSubtitleAppearance(session),
              icon: const Icon(Icons.format_size),
            ),
            IconButton(
              key: const ValueKey('review-karaoke-settings'),
              tooltip: 'Karaoke settings',
              onPressed: () => _editKaraokeSettings(session),
              icon: const Icon(Icons.lyrics),
            ),
            if (reviewIndex != null &&
                session.project.karaokeMode == KaraokeMode.karaokeAdvanced &&
                session.lines[reviewIndex].isFullyMarked &&
                session.lines[reviewIndex].endMs! >
                    session.lines[reviewIndex].startMs!)
              FilledButton.tonal(
                key: const ValueKey('mark-words'),
                onPressed: session.advancedMarking == null
                    ? () => _startAdvancedPass(session, reviewIndex)
                    : null,
                child: const Text('Mark words'),
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
    final manualReviewIndex = _safeReviewIndex(session);
    final displayReviewIndex = _reviewFollowingPlayback
        ? _reviewFollowIndex
        : manualReviewIndex;
    final reviewText = displayReviewIndex == null
        ? ''
        : session.lines[displayReviewIndex].text;
    final karaokePreview = widget.reviewMode
        ? _karaokePreviewFor(session, widget.controls.positionMs)
        : null;
    _keyHandler ??= MarkingKeyHandler(
      session: session,
      getPositionMs: () => widget.controls.positionMs,
      seekTo: (ms) => widget.controls.seek(ms),
    );
    final advanced = session.advancedMarking;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) =>
          ((!widget.reviewMode || session.advancedMarking != null) &&
              _handleMarkingKey(event))
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      child: Column(
        children: [
          if (widget.videoArea != null)
            SizedBox(height: 240, child: widget.videoArea),
          if (karaokePreview != null)
            karaokePreview
          else if (widget.reviewMode &&
              manualReviewIndex != null &&
              session.project.karaokeMode == KaraokeMode.standard)
            _ReviewSubtitlePanel(
              text: reviewText,
              fontFamily: SubtitleFontCatalog.byId(
                session.project.subtitleFontFamily,
              ).familyName,
              fontSize: session.project.subtitleFontSize,
            ),
          ExcludeFocus(child: PlayerControlsBar(controls: widget.controls)),
          if (widget.reviewMode) ExcludeFocus(child: _buildReviewBar(session)),
          if (advanced != null)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      advanced.isComplete
                          ? 'Words marked'
                          : 'Press Space: ${advanced.tokens[advanced.nextUnitIndex].text.trimLeft()}',
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => _restartAdvancedPass(session),
                      child: const Text('Restart'),
                    ),
                    TextButton(
                      onPressed: _cancelAdvancedPass,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: LineListView(
              selectedIndex: widget.reviewMode ? displayReviewIndex : null,
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

  Widget? _karaokePreviewFor(MarkingSession session, int positionMs) {
    final project = session.project;
    final mode = project.karaokeMode;
    if (mode == KaraokeMode.standard) return null;

    final resolved = <(int, List<KaraokeSegment>)>[];
    for (var index = 0; index < session.lines.length; index++) {
      final segments = resolveKaraokeSegments(session.lines[index], mode);
      if (segments.isNotEmpty) resolved.add((index, segments));
    }
    if (resolved.isEmpty) return null;

    final leadMs = project.karaokePreDisplay.leadMs;
    var selected = -1;
    for (var index = 0; index < resolved.length; index++) {
      final segments = resolved[index].$2;
      final displayStart = leadMs == null
          ? segments.first.startMs
          : karaokeDisplayStartMs(
              firstSegmentStartMs: segments.first.startMs,
              leadMs: leadMs,
            );
      if (positionMs >= displayStart && positionMs <= segments.last.endMs) {
        selected = index;
        break;
      }
    }
    if (selected < 0) return null;

    final current = resolved[selected];
    final showNext =
        project.karaokePreDisplay == KaraokePreDisplay.oneLineAhead;
    final next = showNext && selected + 1 < resolved.length
        ? resolved[selected + 1].$2
        : null;
    return KaraokePreview(
      current: current.$2,
      next: next,
      currentLineIndex: current.$1,
      positionMs: positionMs,
      fontFamily: SubtitleFontCatalog.byId(
        project.subtitleFontFamily,
      ).familyName,
      fontSize: project.subtitleFontSize,
    );
  }
}

class _ReviewSubtitlePanel extends StatelessWidget {
  const _ReviewSubtitlePanel({
    required this.text,
    required this.fontFamily,
    required this.fontSize,
  });

  final String text;
  final String fontFamily;
  final double fontSize;

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
          fontFamily: fontFamily,
          fontSize: fontSize,
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
