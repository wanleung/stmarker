// lib/ui/widgets/line_list_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/marking_session.dart';
import '../format_timestamp.dart';

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
  int? _lastScrolledIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<MarkingSession>();
    final lines = session.lines;
    final currentIndex = session.currentIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentIndex != null &&
          currentIndex != _lastScrolledIndex &&
          _scrollController.hasClients) {
        _scrollController.animateTo(
          currentIndex * _rowHeight,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
        _lastScrolledIndex = currentIndex;
      }
    });

    return ListView.builder(
      controller: _scrollController,
      itemCount: lines.length,
      itemExtent: _rowHeight,
      itemBuilder: (context, index) {
        final line = lines[index];
        final isCurrent = index == currentIndex;
        final overlapsPrevious =
            index > 0 &&
            line.startMs != null &&
            lines[index - 1].endMs != null &&
            line.startMs! < lines[index - 1].endMs!;
        final hasTimingIssue = line.hasInvalidRange || overlapsPrevious;
        return Material(
          color: isCurrent
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            key: ValueKey('line-row-$index'),
            dense: true,
            onTap: () => widget.onRowTap(index),
            leading: SizedBox(
              width: 40,
              child: Text('${index + 1}', textAlign: TextAlign.right),
            ),
            title: Text(line.text, overflow: TextOverflow.ellipsis),
            shape: hasTimingIssue
                ? RoundedRectangleBorder(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : null,
            trailing: hasTimingIssue
                ? Tooltip(
                    message: overlapsPrevious
                        ? 'Starts before the previous line ends'
                        : 'Invalid timestamp range',
                    child: Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : null,
            subtitle: Text(
              '${formatDisplayTimestamp(line.startMs)} → ${formatDisplayTimestamp(line.endMs)}',
            ),
          ),
        );
      },
    );
  }
}
