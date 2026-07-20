import 'package:flutter/material.dart';

import '../karaoke/karaoke_timing.dart';

const karaokeCompletedColor = Color(0xFFFFD700);

int karaokeDisplayStartMs({
  required int firstSegmentStartMs,
  required int leadMs,
}) => (firstSegmentStartMs - leadMs).clamp(0, firstSegmentStartMs);

class KaraokePreview extends StatelessWidget {
  const KaraokePreview({
    super.key,
    required this.current,
    this.next,
    required this.currentLineIndex,
    required this.positionMs,
    required this.fontFamily,
    required this.fontSize,
  });

  final List<KaraokeSegment> current;
  final List<KaraokeSegment>? next;
  final int currentLineIndex;
  final int positionMs;
  final String fontFamily;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final currentRow = currentLineIndex.isEven ? 0 : 1;
    final nextRow = 1 - currentRow;
    final rows = <int, Widget>{
      currentRow: _line(
        key: ValueKey('karaoke-row-$currentRow'),
        segments: current,
        positionMs: positionMs,
        semanticsPrefix: 'Current karaoke line',
      ),
    };
    final nextSegments = next;
    if (nextSegments != null) {
      rows[nextRow] = _line(
        key: ValueKey('karaoke-row-$nextRow'),
        segments: nextSegments,
        positionMs: null,
        semanticsPrefix: 'Next karaoke line',
      );
    }

    return Container(
      key: const ValueKey('karaoke-preview'),
      width: double.infinity,
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: Theme.of(context).colorScheme.inverseSurface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var row = 0; row < 2; row++)
            SizedBox(
              height: 46,
              width: double.infinity,
              child: rows[row] ?? const SizedBox.expand(),
            ),
        ],
      ),
    );
  }

  Widget _line({
    required Key key,
    required List<KaraokeSegment> segments,
    required int? positionMs,
    required String semanticsPrefix,
  }) {
    final text = segments.map((segment) => segment.text).join();
    return Semantics(
      label: '$semanticsPrefix: $text',
      child: ExcludeSemantics(
        child: RichText(
          key: key,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(fontFamily: fontFamily, fontSize: fontSize),
            children: positionMs == null
                ? [
                    TextSpan(
                      text: text,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ]
                : _timedSpans(segments, positionMs),
          ),
        ),
      ),
    );
  }
}

List<TextSpan> _timedSpans(List<KaraokeSegment> segments, int positionMs) {
  final spans = <TextSpan>[];
  for (final segment in segments) {
    if (positionMs >= segment.endMs) {
      spans.add(
        TextSpan(
          text: segment.text,
          style: const TextStyle(color: karaokeCompletedColor),
        ),
      );
      continue;
    }
    if (positionMs <= segment.startMs) {
      spans.add(
        TextSpan(
          text: segment.text,
          style: const TextStyle(color: Colors.white),
        ),
      );
      continue;
    }

    final graphemes = segment.text.characters.toList(growable: false);
    final fraction =
        (positionMs - segment.startMs) / (segment.endMs - segment.startMs);
    final completedCount = (graphemes.length * fraction).floor();
    if (completedCount > 0) {
      spans.add(
        TextSpan(
          text: graphemes.take(completedCount).join(),
          style: const TextStyle(color: karaokeCompletedColor),
        ),
      );
    }
    if (completedCount < graphemes.length) {
      spans.add(
        TextSpan(
          text: graphemes.skip(completedCount).join(),
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
  }
  return spans;
}
