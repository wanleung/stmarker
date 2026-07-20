import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../keyboard/marking_key_handler.dart';
import '../player/playback_controls.dart';
import '../state/marking_session.dart';
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
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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
      onKeyEvent: (node, event) =>
          (_keyHandler?.handleKeyEvent(event) ?? false) ? KeyEventResult.handled : KeyEventResult.ignored,
      child: Column(
        children: [
          if (widget.videoArea != null) SizedBox(height: 240, child: widget.videoArea),
          PlayerControlsBar(controls: widget.controls),
          Expanded(
            child: LineListView(
              onRowTap: (index) {
                final line = session.lines[index];
                if (line.startMs != null) widget.controls.seek(line.startMs!);
              },
            ),
          ),
        ],
      ),
    );
  }
}
