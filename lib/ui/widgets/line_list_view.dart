// lib/ui/widgets/line_list_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/marking_session.dart';

class LineListView extends StatefulWidget {
  const LineListView({super.key, required this.onRowTap});

  /// Called with the tapped row's index so the caller can jump the player
  /// there and offer that row for manual editing.
  final void Function(int index) onRowTap;

  @override
  State<LineListView> createState() => _LineListViewState();
}

class _LineListViewState extends State<LineListView> {
  final _scrollController = ScrollController();
  static const _rowHeight = 48.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatMs(int? ms) {
    if (ms == null) return '—';
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$minutes:$seconds.$millis';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<MarkingSession>();
    final lines = session.lines;
    final currentIndex = session.currentIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentIndex != null && _scrollController.hasClients) {
        _scrollController.animateTo(
          currentIndex * _rowHeight,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollController,
      itemCount: lines.length,
      itemExtent: _rowHeight,
      itemBuilder: (context, index) {
        final line = lines[index];
        final isCurrent = index == currentIndex;
        return Material(
          color: isCurrent ? Theme.of(context).colorScheme.primaryContainer : null,
          child: ListTile(
            key: ValueKey('line-row-$index'),
            dense: true,
            onTap: () => widget.onRowTap(index),
            leading: SizedBox(width: 40, child: Text('${index + 1}', textAlign: TextAlign.right)),
            title: Text(line.text, overflow: TextOverflow.ellipsis),
            subtitle: Text('${_formatMs(line.startMs)} → ${_formatMs(line.endMs)}'),
          ),
        );
      },
    );
  }
}
